import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'package:wisata_daerahku/data/app_data.dart';

class MemoryStore implements SessionStore {
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

Map<String, dynamic> user(String id) =>
    {'guid': id, 'name': 'User', 'email': 'user@example.test', 'phone': null};
Map<String, dynamic> tokens(String id) => {
      'access_token': 'access-$id',
      'refresh_token': 'refresh-$id',
      'user': user(id)
    };
http.Response ok(Map<String, dynamic> data) =>
    http.Response(jsonEncode({'data': data}), 200);
void main() {
  test('logout response cannot clear a newer login', () async {
    final store = MemoryStore();
    final gate = Completer<void>();
    var logins = 0;
    final session = AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: store,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            return ok(tokens('${++logins}'));
          }
          await gate.future;
          return ok({'message': 'Logged out.'});
        }));
    await session.login('user@example.test', 'password');
    final pending = session.logout();
    await session.login('user@example.test', 'password');
    gate.complete();
    await pending;
    expect(currentUser?.id, '2');
    expect(jsonDecode(store.value!)['refresh_token'], 'refresh-2');
  });
  test(
      'validation errors preserve field messages without exposing server error bodies',
      () async {
    final session = AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: MemoryStore(),
        client: MockClient((request) async => http.Response(
            jsonEncode({
              'errors': {
                'email': ['Email sudah digunakan.']
              }
            }),
            422)));
    await expectLater(
        session.login('user@example.test', 'password'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Email sudah digunakan.')));
  });
  test(
      'concurrent unauthorized requests share one refresh and persist rotated pair',
      () async {
    final store = MemoryStore();
    var refreshes = 0;
    final gate = Completer<void>();
    final session = AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: store,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) return ok(tokens('old'));
          if (request.url.path.endsWith('/refresh')) {
            refreshes++;
            await gate.future;
            return ok(tokens('new'));
          }
          if (request.headers['Authorization'] == 'Bearer access-old') {
            return http.Response('{}', 401);
          }
          return ok(user('new'));
        }));
    await session.login('user@example.test', 'password');
    final requests = [session.me(), session.me()];
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await Future.wait(requests);
    expect(refreshes, 1);
    expect(jsonDecode(store.value!)['refresh_token'], 'refresh-new');
    expect(currentUser?.id, 'new');
  });
  test('failed refresh clears credentials and never retries indefinitely',
      () async {
    final store = MemoryStore();
    var refreshes = 0;
    final session = AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: store,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) return ok(tokens('old'));
          if (request.url.path.endsWith('/refresh')) refreshes++;
          return http.Response('{}', 401);
        }));
    await session.login('user@example.test', 'password');
    await expectLater(session.me(), throwsA(isA<ApiException>()));
    expect(refreshes, 1);
    expect(store.value, isNull);
    expect(currentUser, isNull);
  });
  test('response arriving after logout does not restore current user',
      () async {
    final store = MemoryStore();
    final gate = Completer<void>();
    final session = AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: store,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) return ok(tokens('old'));
          await gate.future;
          return ok(user('old'));
        }));
    await session.login('user@example.test', 'password');
    final pending = session.me();
    await session.clear();
    gate.complete();
    await pending;
    expect(currentUser, isNull);
    expect(store.value, isNull);
  });
}
