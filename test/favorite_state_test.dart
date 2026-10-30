import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/data/favorite_state.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

class _Store implements SessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String data) async {}
  @override
  Future<void> clear() async {}
}

http.Response _session(String name) => http.Response(
    jsonEncode({
      'data': {
        'access_token': 'access-$name',
        'refresh_token': 'refresh-$name',
        'user': {'guid': 'user-$name', 'name': name, 'email': '$name@test.test'}
      }
    }),
    200);

http.Response _favorites(List<String> ids, {int lastPage = 1}) => http.Response(
    jsonEncode({
      'data': ids
          .map((id) => {
                'guid': 'favorite-$id',
                'destination': {'guid': id, 'name': id}
              })
          .toList(),
      'meta': {'last_page': lastPage}
    }),
    200);

http.Response _me(http.Request request) {
  final name = request.headers['Authorization']!.split('-').last;
  return http.Response(
      jsonEncode({
        'data': {
          'guid': 'user-$name',
          'name': name,
          'email': '$name@test.test',
          'phone': null,
          'role': 0,
          'status': 'active'
        }
      }),
      200);
}

void main() {
  test('token refresh during mutation keeps repeated toggles locked', () async {
    final refresh = Completer<http.Response>();
    final refreshStarted = Completer<void>();
    var writes = 0;
    var saved = false;
    final session = AuthSession(
      baseUrl: 'https://example.test/api/v1',
      store: _Store(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return _session('a');
        if (request.url.path.endsWith('/auth/me')) return _me(request);
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshStarted.complete();
          return refresh.future;
        }
        if (request.method == 'GET') return _favorites(saved ? ['d1'] : []);
        writes++;
        if (writes == 1) return http.Response('{}', 401);
        saved = true;
        return http.Response(
            jsonEncode({
              'data': {
                'guid': 'favorite-d1',
                'destination': {'guid': 'd1', 'name': 'd1'}
              }
            }),
            200);
      }),
    );
    await session.login('a', 'password');
    final state =
        FavoriteState(repository: BusinessRepository(ApiClient(session)));
    await state.load();
    final first = state.toggle('d1');
    await refreshStarted.future;
    await state.toggle('d1');
    expect(writes, 1);
    refresh.complete(_session('a'));
    await first;
    expect(writes, 2); // Original request plus its authenticated retry.
    expect(state.isFavorite('d1'), isTrue);
    state.dispose();
  });

  test('load errors can retry without inventing a favorite', () async {
    var offline = true;
    final session = AuthSession(
      baseUrl: 'https://example.test/api/v1',
      store: _Store(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return _session('a');
        if (request.url.path.endsWith('/auth/me')) return _me(request);
        if (offline) throw http.ClientException('offline');
        return _favorites(['d1']);
      }),
    );
    await session.login('a', 'password');
    final state =
        FavoriteState(repository: BusinessRepository(ApiClient(session)));
    await state.load();
    expect(state.favorites.error, isA<ApiException>());
    expect(state.isFavorite('d1'), isFalse);
    offline = false;
    await state.favorites.retry();
    expect(state.favorites.error, isNull);
    expect(state.isFavorite('d1'), isTrue);
    state.dispose();
  });

  test('loads all pages and deduplicates destination GUIDs', () async {
    final session = AuthSession(
      baseUrl: 'https://example.test/api/v1',
      store: _Store(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return _session('a');
        if (request.url.path.endsWith('/auth/me')) return _me(request);
        return request.url.queryParameters['page'] == '1'
            ? _favorites(['d1'], lastPage: 2)
            : _favorites(['d1', 'd2'], lastPage: 2);
      }),
    );
    await session.login('a', 'password');
    final state =
        FavoriteState(repository: BusinessRepository(ApiClient(session)));
    await state.load();
    expect(state.favorites.data!.map((f) => f.destination.guid), ['d1', 'd2']);
    state.dispose();
  });

  test('rapid repeated toggles do not send duplicate mutations', () async {
    final mutation = Completer<http.Response>();
    final started = Completer<void>();
    var writes = 0;
    var saved = false;
    final session = AuthSession(
      baseUrl: 'https://example.test/api/v1',
      store: _Store(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) return _session('a');
        if (request.url.path.endsWith('/auth/me')) return _me(request);
        if (request.method == 'GET') return _favorites(saved ? ['d1'] : []);
        writes++;
        started.complete();
        final result = await mutation.future;
        saved = true;
        return result;
      }),
    );
    await session.login('a', 'password');
    final state =
        FavoriteState(repository: BusinessRepository(ApiClient(session)));
    await state.load();
    final first = state.toggle('d1');
    await started.future;
    await state.toggle('d1');
    expect(writes, 1);
    mutation.complete(http.Response(
        jsonEncode({
          'data': {
            'guid': 'favorite-d1',
            'destination': {'guid': 'd1', 'name': 'd1'}
          }
        }),
        200));
    await first;
    expect(state.isFavorite('d1'), isTrue);
    state.dispose();
  });

  test('late response from account A cannot replace account B favorites',
      () async {
    final old = Completer<http.Response>();
    var delayA = false;
    final session = AuthSession(
      baseUrl: 'https://example.test/api/v1',
      store: _Store(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return _session(jsonDecode(request.body)['email'] as String);
        }
        if (request.url.path.endsWith('/auth/me')) return _me(request);
        if (request.headers['Authorization'] == 'Bearer access-a') {
          if (delayA) return old.future;
          return _favorites(['a-only']);
        }
        return _favorites(['b-only']);
      }),
    );
    await session.login('a', 'password');
    final state =
        FavoriteState(repository: BusinessRepository(ApiClient(session)));
    await state.load();
    expect(state.isFavorite('a-only'), isTrue);
    delayA = true;
    final pending = state.load();
    await session.login('b', 'password');
    await state.load();
    expect(state.isFavorite('a-only'), isFalse);
    expect(state.isFavorite('b-only'), isTrue);
    old.complete(_favorites(['a-only']));
    await pending;
    expect(state.isFavorite('a-only'), isFalse);
    expect(state.isFavorite('b-only'), isTrue);
    await session.clear();
    expect(state.favorites.data, isNull);
    state.dispose();
  });
}
