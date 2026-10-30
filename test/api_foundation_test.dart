import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

class Store implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async {
    value = data;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  test('catalog passes backend category and page and uses detail GUID',
      () async {
    final requests = <Uri>[];
    final session = AuthSession(
      baseUrl: 'https://example.test/api/v1',
      store: Store(),
      client: MockClient((request) async {
        requests.add(request.url);
        final item = {'guid': 'dest-1', 'name': 'Wisata'};
        return http.Response(
            jsonEncode({
              'data': request.url.path.endsWith('/dest-1') ? item : [item],
              'meta': {'current_page': 2, 'last_page': 3},
              'links': {
                'next': 'https://example.test/api/v1/destinations?page=3'
              }
            }),
            200);
      }),
    );
    final repo = BusinessRepository(ApiClient(session));
    final page =
        await repo.destinations(query: {'category': 'cat-1', 'page': '2'});
    expect(requests.single.queryParameters, {'category': 'cat-1', 'page': '2'});
    expect(page.items.single.guid, 'dest-1');
    expect(page.meta!['last_page'], 3);
    expect((await repo.destination(page.items.single.guid)).guid, 'dest-1');
    expect(requests.last.path, '/api/v1/destinations/dest-1');
  });

  for (final status in [401, 404, 429, 500]) {
    test('detail propagates HTTP $status without fallback', () async {
      final session = AuthSession(
        baseUrl: 'https://example.test/api/v1',
        store: Store(),
        client: MockClient(
            (_) async => http.Response('{"message":"failed"}', status)),
      );
      await expectLater(
        BusinessRepository(ApiClient(session)).destination('missing'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', status)),
      );
    });
  }

  test('public collection pagination and object mapping', () async {
    final session = AuthSession(
        baseUrl: 'https://example.test/api/v1',
        store: Store(),
        client: MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), false);
          final destination = {
            'guid': 'd1',
            'name': 'Pantai',
            'category': {'guid': 'c1', 'name': 'Pantai'}
          };
          return http.Response(
              jsonEncode(request.url.path.endsWith('/d1')
                  ? {'data': destination}
                  : {
                      'data': [destination],
                      'meta': {'current_page': 1},
                      'links': {'next': null}
                    }),
              200);
        }));
    final repo = BusinessRepository(ApiClient(session));
    final page = await repo.destinations(query: {'page': '1'});
    expect(page.items.single.category!.guid, 'c1');
    expect(page.meta!['current_page'], 1);
    expect((await repo.destination('d1')).name, 'Pantai');
  });
  test('booking uses session bearer and preserves idempotency key', () async {
    final session = AuthSession(
        baseUrl: 'https://example.test/api/v1',
        store: Store(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            return http.Response(
                jsonEncode({
                  'data': {
                    'access_token': 'access',
                    'refresh_token': 'refresh',
                    'user': {
                      'guid': 'u',
                      'name': 'U',
                      'email': 'u@example.test'
                    }
                  }
                }),
                200);
          }
          if (request.url.path.endsWith('/auth/me')) {
            return http.Response(
                jsonEncode({
                  'data': {
                    'guid': 'u',
                    'name': 'U',
                    'email': 'u@example.test',
                    'phone': null,
                    'role': 0,
                    'status': 'active'
                  }
                }),
                200);
          }
          expect(request.headers['Authorization'], 'Bearer access');
          expect(request.headers['Idempotency-Key'], 'same-key');
          return http.Response(
              jsonEncode({
                'data': {
                  'guid': 'b',
                  'visitor_name': 'U',
                  'destination_name': 'D',
                  'status': 'pending'
                }
              }),
              200);
        }));
    await session.login('u@example.test', 'password');
    expect(
        (await BusinessRepository(ApiClient(session))
                .createBooking({'quantity': 1}, 'same-key'))
            .guid,
        'b');
  });
  test('invalid response and empty collection', () async {
    var invalid = false;
    final session = AuthSession(
        baseUrl: 'https://example.test/api/v1',
        store: Store(),
        client: MockClient((_) async =>
            http.Response(jsonEncode({'data': invalid ? 'bad' : []}), 200)));
    final repo = BusinessRepository(ApiClient(session));
    expect((await repo.categories()).items, isEmpty);
    invalid = true;
    await expectLater(repo.categories(), throwsA(isA<ApiException>()));
  });
  test('request state ignores stale results and retry replaces errors',
      () async {
    final state = RequestState<List<int>>();
    final old = Completer<List<int>>();
    final first = state.load(() => old.future);
    await state.load(() async => <int>[]);
    old.complete([1]);
    await first;
    expect(state.data, isEmpty);
    var attempts = 0;
    await state.load(() async {
      if (++attempts == 1) throw Exception('failed');
      return [2];
    });
    expect(state.error, isNotNull);
    await state.retry();
    expect(state.data, [2]);
    state.dispose();
  });
}
