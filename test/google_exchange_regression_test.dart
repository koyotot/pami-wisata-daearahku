import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'auth_session_test.dart' show MemoryStore, ok, tokens, user;

void main() {
  test('Google exchange sends Firebase token and validates Laravel identity',
      () async {
    final store = MemoryStore();
    final paths = <String>[];
    final session = AuthSession(
      baseUrl: 'https://api.example.test/api/v1',
      store: store,
      client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/google')) {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'id_token': 'firebase-token'});
          return ok(tokens('google'));
        }
        expect(request.headers['Authorization'], 'Bearer access-google');
        return ok(user('google'));
      }),
    );
    await session.google('firebase-token');
    expect(paths, ['/api/v1/auth/google', '/api/v1/auth/me']);
    expect(session.authenticated.value, isTrue);
    expect(jsonDecode(store.value!)['refresh_token'], 'refresh-google');
  });

  test('failed Google exchange preserves an existing Laravel session',
      () async {
    final store = MemoryStore();
    final session = AuthSession(
      baseUrl: 'https://api.example.test/api/v1',
      store: store,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) return ok(tokens('old'));
        if (request.url.path.endsWith('/me')) return ok(user('old'));
        return http.Response('{}', 401);
      }),
    );
    await session.login('old@example.test', 'password');
    await expectLater(session.google('bad'), throwsA(isA<ApiException>()));
    expect(session.authenticated.value, isTrue);
    expect(currentUser?.id, 'old');
    expect(jsonDecode(store.value!)['refresh_token'], 'refresh-old');
  });

  test('logout during Google exchange prevents a stale session', () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    final store = MemoryStore();
    final session = AuthSession(
      baseUrl: 'https://api.example.test/api/v1',
      store: store,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/google')) {
          started.complete();
          await gate.future;
          return ok(tokens('late'));
        }
        return ok(user('late'));
      }),
    );
    final pending = session.google('firebase-token');
    await started.future;
    await session.logout();
    gate.complete();
    await expectLater(pending, throwsA(isA<ApiException>()));
    expect(session.authenticated.value, isFalse);
    expect(store.value, isNull);
  });
}
