import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/screens/user/main_navigation_screen.dart';
import 'package:wisata_daerahku/screens/shared/session_destination.dart';
import 'package:wisata_daerahku/screens/auth/verify_email_otp_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'auth_session_test.dart' show MemoryStore, ok, tokens, user;

void main() {
  AuthSession sessionFor(MemoryStore store,
          Future<http.Response> Function(http.Request) handler) =>
      AuthSession(
          baseUrl: 'https://api.example.test/api/v1',
          store: store,
          client: MockClient(handler));

  Future<void> register(AuthSession session) => session.register(
      'User', 'user@example.test', 'password123', 'password123');

  test('register OTP rechecks bearer identity then selects user dashboard',
      () async {
    final store = MemoryStore();
    var verified = false;
    final paths = <String>[];
    final session = sessionFor(store, (request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/register')) return ok(tokens('u'));
      if (request.url.path.endsWith('/verify-otp')) {
        verified = true;
        return ok({'message': 'verified'});
      }
      expect(request.url.path, endsWith('/me'));
      expect(request.headers['Authorization'], 'Bearer access-u');
      return ok(
          {...user('u'), 'email_verified_at': verified ? '2026-01-01' : null});
    });
    await register(session);
    final generation = session.sessionGeneration;
    expect(sessionDestination(session: session), isA<VerifyEmailOtpScreen>());
    expect(session.authenticated.value, isFalse);
    await session.verifyEmailOtp('user@example.test', '012345');
    expect(sessionDestination(session: session), isA<MainNavigationScreen>());
    expect(session.isCurrentGeneration(generation), isTrue);
    expect(currentUser?.id, 'u');
    expect(jsonDecode(store.value!)['access_token'], 'access-u');
    expect(paths, [
      '/api/v1/auth/register',
      '/api/v1/auth/me',
      '/api/v1/auth/email-verification/verify-otp',
      '/api/v1/auth/me'
    ]);
  });

  for (final code in ['invalid_otp', 'expired_otp']) {
    test('$code preserves pending session and cannot select dashboard',
        () async {
      final store = MemoryStore();
      var meCalls = 0;
      final session = sessionFor(store, (request) async {
        if (request.url.path.endsWith('/register')) return ok(tokens('u'));
        if (request.url.path.endsWith('/me')) {
          meCalls++;
          return ok({...user('u'), 'email_verified_at': null});
        }
        return http.Response(jsonEncode({'code': code}), 422);
      });
      await register(session);
      await expectLater(session.verifyEmailOtp('user@example.test', '000000'),
          throwsA(isA<ApiException>().having((e) => e.status, 'status', 422)));
      expect(session.authenticated.value, isFalse);
      expect(sessionDestination(session: session), isA<VerifyEmailOtpScreen>());
      expect(store.value, isNotNull);
      expect(meCalls, 1);
    });
  }

  for (final identity in [
    {...user('u'), 'email_verified_at': null},
    {...user('u'), 'email_verified_at': ''},
    user('other'),
    {...user('u'), 'email': 'other@example.test'},
    user('u', role: 1),
    user('u', role: 2),
    user('u', status: 'suspended'),
  ]) {
    test('OTP success rejects invalid final identity $identity', () async {
      final store = MemoryStore();
      var verified = false;
      final session = sessionFor(store, (request) async {
        if (request.url.path.endsWith('/register')) return ok(tokens('u'));
        if (request.url.path.endsWith('/verify-otp')) {
          verified = true;
          return ok({'message': 'verified'});
        }
        return ok(
            verified ? identity : {...user('u'), 'email_verified_at': null});
      });
      await register(session);
      await expectLater(session.verifyEmailOtp('user@example.test', '012345'),
          throwsA(isA<ApiException>()));
      expect(session.authenticated.value, isFalse);
      expect(session.deviceSessionReady, isFalse);
      expect(sessionDestination(session: session),
          isNot(isA<MainNavigationScreen>()));
    });
  }

  for (final duringMe in [false, true]) {
    test('logout racing OTP ${duringMe ? 'me' : 'verify'} cannot reactivate',
        () async {
      final store = MemoryStore();
      final started = Completer<void>();
      final gate = Completer<void>();
      var verified = false;
      final session = sessionFor(store, (request) async {
        if (request.url.path.endsWith('/register')) return ok(tokens('u'));
        if (request.url.path.endsWith('/verify-otp')) {
          if (!duringMe) {
            started.complete();
            await gate.future;
          }
          verified = true;
          return ok({'message': 'verified'});
        }
        if (request.url.path.endsWith('/logout'))
          return ok({'message': 'logout'});
        if (verified && duringMe) {
          started.complete();
          await gate.future;
        }
        return ok({
          ...user('u'),
          'email_verified_at': verified ? '2026-01-01' : null
        });
      });
      await register(session);
      final pending = session.verifyEmailOtp('user@example.test', '012345');
      final rejected = expectLater(pending, throwsA(isA<ApiException>()));
      await started.future;
      await session.logout();
      gate.complete();
      await rejected;
      expect(session.authenticated.value, isFalse);
      expect(currentUser, isNull);
      expect(store.value, isNull);
    });
  }

  test(
      'OTP completion rotates expired access token without losing registration identity',
      () async {
    final store = MemoryStore();
    var verified = false;
    var refreshes = 0;
    final session = sessionFor(store, (request) async {
      if (request.url.path.endsWith('/register')) return ok(tokens('u'));
      if (request.url.path.endsWith('/verify-otp')) {
        verified = true;
        return ok({'message': 'verified'});
      }
      if (request.url.path.endsWith('/refresh')) {
        refreshes++;
        return ok({
          ...tokens('u'),
          'access_token': 'rotated',
          'refresh_token': 'rotated-refresh'
        });
      }
      if (verified && request.headers['Authorization'] == 'Bearer access-u') {
        return http.Response('{}', 401);
      }
      return ok(
          {...user('u'), 'email_verified_at': verified ? '2026-01-01' : null});
    });
    await register(session);
    await session.verifyEmailOtp('user@example.test', '012345');
    expect(refreshes, 1);
    expect(session.authenticated.value, isTrue);
    expect(jsonDecode(store.value!)['refresh_token'], 'rotated-refresh');
  });

  test(
      'missing pending JWT cannot create authenticated session after valid OTP',
      () async {
    final session =
        sessionFor(MemoryStore(), (_) async => ok({'message': 'verified'}));
    await expectLater(session.verifyEmailOtp('user@example.test', '012345'),
        throwsA(isA<ApiException>()));
    expect(session.authenticated.value, isFalse);
    expect(session.deviceSessionReady, isFalse);
  });

  test('stale OTP generation cannot verify newer same-email registration',
      () async {
    final store = MemoryStore();
    var otpCalls = 0;
    final session = sessionFor(store, (request) async {
      if (request.url.path.endsWith('/register')) return ok(tokens('u'));
      if (request.url.path.endsWith('/verify-otp')) otpCalls++;
      return ok({...user('u'), 'email_verified_at': null});
    });
    await register(session);
    final staleGeneration = session.sessionGeneration;
    await session.clear();
    await register(session);
    await expectLater(
        session.verifyEmailOtp('user@example.test', '012345',
            expectedGeneration: staleGeneration),
        throwsA(isA<ApiException>()));
    expect(otpCalls, 0);
    expect(session.verificationRequired, isTrue);
    expect(session.authenticated.value, isFalse);
    expect(store.value, isNotNull);
  });

  test('revoked JWT and refresh after OTP cannot open dashboard', () async {
    final store = MemoryStore();
    var verified = false;
    final session = sessionFor(store, (request) async {
      if (request.url.path.endsWith('/register')) return ok(tokens('u'));
      if (request.url.path.endsWith('/verify-otp')) {
        verified = true;
        return ok({'message': 'verified'});
      }
      if (verified) return http.Response('{}', 401);
      return ok({...user('u'), 'email_verified_at': null});
    });
    await register(session);
    await expectLater(session.verifyEmailOtp('user@example.test', '012345'),
        throwsA(isA<ApiException>()));
    expect(session.authenticated.value, isFalse);
    expect(store.value, isNull);
    expect(sessionDestination(session: session),
        isNot(isA<MainNavigationScreen>()));
  });

  test(
      'retry after successful OTP and transient me failure does not reuse consumed OTP',
      () async {
    final store = MemoryStore();
    var otpCalls = 0;
    var postVerificationMeCalls = 0;
    final session = sessionFor(store, (request) async {
      if (request.url.path.endsWith('/register')) return ok(tokens('u'));
      if (request.url.path.endsWith('/verify-otp')) {
        otpCalls++;
        return otpCalls == 1
            ? ok({'message': 'verified'})
            : http.Response('{}', 422);
      }
      if (otpCalls > 0) {
        if (++postVerificationMeCalls == 1) return http.Response('{}', 500);
        return ok(user('u'));
      }
      return ok({...user('u'), 'email_verified_at': null});
    });
    await register(session);
    await expectLater(session.verifyEmailOtp('user@example.test', '012345'),
        throwsA(isA<ApiException>()));
    expect(session.authenticated.value, isFalse);
    await session.verifyEmailOtp('user@example.test', '012345');
    expect(otpCalls, 1);
    expect(postVerificationMeCalls, 2);
    expect(session.authenticated.value, isTrue);
  });
}
