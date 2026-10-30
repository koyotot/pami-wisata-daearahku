import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

class _Store implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async => value = data;
  @override
  Future<void> clear() async => value = null;
}

Map<String, dynamic> _login() => {
      'data': {
        'access_token': 'access-a',
        'refresh_token': 'refresh-a',
        'user': {'guid': 'user-a', 'name': 'A', 'email': 'a@example.test'}
      }
    };

void main() {
  test('favorite operations use Laravel bearer and destination GUID', () async {
    final requests = <http.Request>[];
    final session = AuthSession(
      baseUrl: 'https://example.test/api/v1',
      store: _Store(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(jsonEncode(_login()), 200);
        }
        requests.add(request);
        final favorite = {
          'guid': 'favorite-1',
          'destination': {'guid': 'destination-1', 'name': 'Pantai'}
        };
        return http.Response(
            jsonEncode({
              'data': request.method == 'GET'
                  ? [favorite]
                  : request.method == 'PUT'
                      ? favorite
                      : {'deleted': true},
              if (request.method == 'GET') 'meta': {'last_page': 1}
            }),
            200);
      }),
    );
    await session.login('a@example.test', 'password');
    final repository = BusinessRepository(ApiClient(session));
    expect(
        (await repository.favorites(query: {'page': '1'}))
            .items
            .single
            .destination
            .guid,
        'destination-1');
    expect((await repository.addFavorite('destination-1')).destination.guid,
        'destination-1');
    await repository.removeFavorite('destination-1');
    expect(requests.map((r) => r.method), ['GET', 'PUT', 'DELETE']);
    expect(requests.first.url.queryParameters['page'], '1');
    expect(requests.skip(1).map((r) => r.url.path),
        ['/api/v1/favorites/destination-1', '/api/v1/favorites/destination-1']);
    for (final request in requests) {
      expect(request.headers['Authorization'], 'Bearer access-a');
    }
  });

  test('anonymous favorite requests never reach the network', () async {
    var requests = 0;
    final session = AuthSession(
      baseUrl: 'https://example.test/api/v1',
      store: _Store(),
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    final repository = BusinessRepository(ApiClient(session));
    await expectLater(repository.favorites(), throwsA(isA<ApiException>()));
    await expectLater(
        repository.addFavorite('d'), throwsA(isA<ApiException>()));
    await expectLater(
        repository.removeFavorite('d'), throwsA(isA<ApiException>()));
    expect(requests, 0);
  });

  for (final status in [403, 404, 409, 422, 429, 500]) {
    test('favorite error HTTP $status propagates without fallback', () async {
      final session = AuthSession(
        baseUrl: 'https://example.test/api/v1',
        store: _Store(),
        client: MockClient((request) async =>
            request.url.path.endsWith('/auth/login')
                ? http.Response(jsonEncode(_login()), 200)
                : http.Response('{"message":"error"}', status)),
      );
      await session.login('a@example.test', 'password');
      await expectLater(
        BusinessRepository(ApiClient(session)).addFavorite('destination-1'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', status)),
      );
    });
  }

  test('connection failure is reported for favorite operation', () async {
    final session = AuthSession(
      baseUrl: 'https://example.test/api/v1',
      store: _Store(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(jsonEncode(_login()), 200);
        }
        throw http.ClientException('offline');
      }),
    );
    await session.login('a@example.test', 'password');
    await expectLater(BusinessRepository(ApiClient(session)).favorites(),
        throwsA(isA<ApiException>()));
  });

  test('401 and failed refresh clear the Laravel session', () async {
    final session = AuthSession(
      baseUrl: 'https://example.test/api/v1',
      store: _Store(),
      client: MockClient((request) async =>
          request.url.path.endsWith('/auth/login')
              ? http.Response(jsonEncode(_login()), 200)
              : http.Response('{"message":"unauthenticated"}', 401)),
    );
    await session.login('a@example.test', 'password');
    await expectLater(
      BusinessRepository(ApiClient(session)).favorites(),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    expect(session.authenticated.value, isFalse);
  });
}
