import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'package:wisata_daerahku/services/fcm_device_manager.dart';
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

Map<String, dynamic> user(String id,
        {int role = 0, String status = 'active'}) =>
    {
      'guid': id,
      'name': 'User',
      'email': 'user@example.test',
      'phone': null,
      'role': role,
      'status': status
    };
Map<String, dynamic> tokens(String id) => {
      'access_token': 'access-$id',
      'refresh_token': 'refresh-$id',
      'user': user(id)
    };
http.Response ok(Map<String, dynamic> data) =>
    http.Response(jsonEncode({'data': data}), 200);
void main() {
  for (final role in [0, 1, 2]) {
    test('login and restore validate role $role from auth/me', () async {
      final store = MemoryStore();
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/login')) return ok(tokens('u'));
        return ok(user('u', role: role));
      });
      final session = AuthSession(
          baseUrl: 'https://api.example.test/api/v1',
          store: store,
          client: client);
      await session.login('u@example.test', 'password');
      expect(session.role, role);
      expect(session.status, 'active');
      final restored = AuthSession(
          baseUrl: 'https://api.example.test/api/v1',
          store: store,
          client: client);
      await restored.restore();
      expect(restored.role, role);
      expect(restored.authenticated.value, isTrue);
    });
  }
  for (final identity in [user('u', status: 'suspended'), user('u', role: 3)]) {
    test('login rejects inactive or unknown identity $identity', () async {
      final store = MemoryStore();
      final session = AuthSession(
          baseUrl: 'https://api.example.test/api/v1',
          store: store,
          client: MockClient((request) async =>
              request.url.path.endsWith('/login')
                  ? ok(tokens('u'))
                  : ok(identity)));
      await expectLater(session.login('u@example.test', 'password'),
          throwsA(isA<ApiException>()));
      expect(session.authenticated.value, isFalse);
      expect(session.role, isNull);
      expect(store.value, isNull);
    });
  }
  for (final method in ['google', 'register']) {
    test('$method uses role from auth/me', () async {
      final paths = <String>[];
      final session = AuthSession(
          baseUrl: 'https://api.example.test/api/v1',
          store: MemoryStore(),
          client: MockClient((request) async {
            paths.add(request.url.path);
            return request.url.path.endsWith('/me')
                ? ok(user('u', role: 0))
                : ok(tokens('u'));
          }));
      if (method == 'google') {
        await session.google('firebase-id-token');
      } else {
        await session.register(
            'User', 'u@example.test', 'password', 'password');
      }
      expect(session.role, 0);
      expect(paths, ['/api/v1/auth/$method', '/api/v1/auth/me']);
    });
  }
  for (final role in [1, 2]) {
    test('google login rejects and revokes role $role session', () async {
      final store = MemoryStore();
      final paths = <String>[];
      String? logoutAuth;
      final session = AuthSession(
          baseUrl: 'https://api.example.test/api/v1',
          store: store,
          client: MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path.endsWith('/logout')) {
              logoutAuth = request.headers['Authorization'];
              return ok({'message': 'Logged out.'});
            }
            return request.url.path.endsWith('/me')
                ? ok(user('admin', role: role))
                : ok(tokens('admin'));
          }));
      await expectLater(session.google('firebase-id-token'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)));
      expect(session.authenticated.value, isFalse);
      expect(session.role, isNull);
      expect(session.deviceSessionReady, isFalse);
      expect(currentUser, isNull);
      expect(store.value, isNull);
      expect(logoutAuth, 'Bearer access-admin');
      expect(paths.last, '/api/v1/auth/logout');
    });
  }
  test('google exchange failure leaves no session', () async {
    final store = MemoryStore();
    final session = AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: store,
        client: MockClient((request) async => http.Response('{}', 401)));
    await expectLater(
        session.google('bad'), throwsA(isA<ApiException>()));
    expect(session.authenticated.value, isFalse);
    expect(store.value, isNull);
  });
  test('failed account switch clears previous identity', () async {
    var attempts = 0;
    final store = MemoryStore();
    final session = AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: store,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/me'))
            return ok(user('admin', role: 2));
          return ++attempts == 1
              ? ok(tokens('admin'))
              : http.Response('{}', 401);
        }));
    await session.login('admin@example.test', 'password');
    await expectLater(session.login('other@example.test', 'bad'),
        throwsA(isA<ApiException>()));
    expect(session.role, isNull);
    expect(currentUser, isNull);
    expect(session.authenticated.value, isFalse);
    expect(store.value, isNull);
  });
  test('auth/me cannot restore identity while logout is in progress', () async {
    final responseGate = Completer<void>();
    final logoutGate = Completer<void>();
    var meCalls = 0;
    final session = AuthSession(
      baseUrl: 'https://api.example.test/api/v1',
      store: MemoryStore(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) return ok(tokens('old'));
        if (request.url.path.endsWith('/me')) {
          if (meCalls++ > 0) await responseGate.future;
          return ok(user('old', role: 2));
        }
        return ok({'message': 'Logged out.'});
      }),
    );
    await session.login('admin@example.test', 'password');
    final generation = session.sessionGeneration;
    expect(session.isCurrentGeneration(generation), isTrue);
    session.beforeDeviceLogout = () => logoutGate.future;
    final pendingMe = session.me();
    final pendingLogout = session.logout();
    expect(session.isCurrentGeneration(generation), isFalse);
    responseGate.complete();
    await expectLater(pendingMe, throwsA(isA<ApiException>()));
    expect(session.role, isNull);
    expect(session.authenticated.value, isFalse);
    logoutGate.complete();
    await pendingLogout;
    expect(session.isCurrentGeneration(generation), isFalse);
  });
  test('server role follows account changes and is cleared on logout',
      () async {
    var count = 0;
    final session = AuthSession(
      baseUrl: 'https://api.example.test/api/v1',
      store: MemoryStore(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          final data = tokens('${++count}');
          (data['user'] as Map<String, dynamic>)['role'] = count == 1 ? 2 : 0;
          return ok(data);
        }
        if (request.url.path.endsWith('/me'))
          return ok(user('$count', role: count == 1 ? 2 : 0));
        return ok({'message': 'Logged out.'});
      }),
    );
    await session.login('admin@example.test', 'password');
    expect(session.role, 2);
    await session.login('user@example.test', 'password');
    expect(session.role, 0);
    await session.logout();
    expect(session.role, isNull);
  });

  test('conflict exposes the backend business message', () async {
    final session = AuthSession(
      baseUrl: 'https://api.example.test/api/v1',
      store: MemoryStore(),
      client: MockClient((request) async => http.Response(
          jsonEncode({'message': 'Booking is no longer awaiting approval.'}),
          409)),
    );
    await expectLater(
        session.login('user@example.test', 'password'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message',
            'Booking is no longer awaiting approval.')));
  });

  test('failed device removal does not block logout', () async {
    var loggedOut = false;
    final session = AuthSession(
      baseUrl: 'https://api.example.test/api/v1',
      store: MemoryStore(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) return ok(tokens('1'));
        if (request.url.path.endsWith('/me')) return ok(user('1'));
        if (request.url.path.endsWith('/devices')) {
          return request.method == 'DELETE'
              ? http.Response('{}', 500)
              : ok({'registered': true});
        }
        loggedOut = true;
        return ok({'message': 'Logged out.'});
      }),
    );
    final manager = FcmDeviceManager(session)..attach();
    manager.updateToken('device-token');
    await session.login('a@example.test', 'password');
    await session.logout();
    expect(loggedOut, isTrue);
    expect(session.authenticated.value, isFalse);
    manager.dispose();
  });
  test('device registration is ordered across account changes and logout',
      () async {
    final firstPut = Completer<void>();
    final started = Completer<void>();
    final secondStarted = Completer<void>();
    final operations = <String>[];
    var logins = 0;
    final session = AuthSession(
      baseUrl: 'https://api.example.test/api/v1',
      store: MemoryStore(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return ok(tokens('${++logins}'));
        }
        if (request.url.path.endsWith('/me')) return ok(user('$logins'));
        if (request.url.path.endsWith('/devices')) {
          final auth = request.headers['Authorization']!;
          operations.add('${request.method} $auth');
          if (request.method == 'PUT' && auth.endsWith('1')) {
            started.complete();
            await firstPut.future;
          }
          if (request.method == 'PUT' && auth.endsWith('2')) {
            secondStarted.complete();
          }
          return ok({'registered': request.method == 'PUT'});
        }
        return ok({'message': 'Logged out.'});
      }),
    );
    final manager = FcmDeviceManager(session)..attach();
    manager.updateToken('device-token');
    await session.login('a@example.test', 'password');
    await started.future;
    final switching = session.login('b@example.test', 'password');
    firstPut.complete();
    await switching;
    // Queue a logout after the second registration and wait for both operations.
    await secondStarted.future;
    await session.logout();
    expect(operations, [
      'PUT Bearer access-1',
      'DELETE Bearer access-1',
      'PUT Bearer access-2',
      'DELETE Bearer access-2',
    ]);
    manager.dispose();
  });
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
          if (request.url.path.endsWith('/me')) return ok(user('$logins'));
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
    var meCalls = 0;
    final gate = Completer<void>();
    final session = AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: store,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) return ok(tokens('old'));
          if (request.url.path.endsWith('/me') && meCalls++ == 0)
            return ok(user('old'));
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
    var meCalls = 0;
    final session = AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: store,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) return ok(tokens('old'));
          if (request.url.path.endsWith('/me') && meCalls++ == 0)
            return ok(user('old'));
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
    var meCalls = 0;
    final session = AuthSession(
        baseUrl: 'https://api.example.test/api/v1',
        store: store,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/login')) return ok(tokens('old'));
          if (request.url.path.endsWith('/me') && meCalls++ == 0)
            return ok(user('old'));
          await gate.future;
          return ok(user('old'));
        }));
    await session.login('user@example.test', 'password');
    final pending = session.me();
    await session.clear();
    gate.complete();
    await expectLater(pending, throwsA(isA<ApiException>()));
    expect(currentUser, isNull);
    expect(store.value, isNull);
  });
}
