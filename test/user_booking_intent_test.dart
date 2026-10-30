import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/booking_errors.dart';
import 'package:wisata_daerahku/data/booking_intent.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'user_support.dart';

/// Scripted server: each hook can be replaced per test.
class ScriptedRepository extends BusinessRepository {
  ScriptedRepository(AuthSession session) : super(ApiClient(session));
  final keys = <String>[];
  final payloads = <Map<String, dynamic>>[];
  final abandonedKeys = <String>[];
  int intentCalls = 0;
  Future<Booking> Function(Json fields, String key)? onCreate;
  Future<BookingIntentState> Function(String key)? onIntent;
  Future<BookingIntentState> Function(String key)? onAbandon;
  final Map<String, Booking> bookingsByGuid = {};

  @override
  Future<Booking> createBooking(Json fields, String idempotencyKey) {
    payloads.add(Map.of(fields));
    keys.add(idempotencyKey);
    return onCreate!(fields, idempotencyKey);
  }

  @override
  Future<BookingIntentState> bookingIntent(String key) {
    intentCalls++;
    return onIntent!(key);
  }

  @override
  Future<BookingIntentState> abandonBookingIntent(String key) {
    abandonedKeys.add(key);
    return onAbandon!(key);
  }

  @override
  Future<Booking> booking(String guid) async =>
      bookingsByGuid[guid] ?? Booking(bookingJson(guid: guid));
}

BookingIntentState intentState(String state,
        {bool replaySafe = false, bool keyExpired = false, Booking? booking}) =>
    BookingIntentState({
      'key': 'k',
      'state': state,
      'replay_safe': replaySafe,
      'key_expired': keyExpired,
      'booking': booking?.json,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fields = {
    'destination_guid': 'dest-1',
    'visit_date': '2027-03-10',
    'quantity': 2,
    'visitor_name': 'User',
    'visitor_email': 'u@example.test',
    'visitor_phone': '0812345678',
    'notes': '',
  };
  late AuthSession session;
  late ScriptedRepository repository;
  late BookingIntent intent;

  void signIn(String id) => currentUser = User(
      id: id,
      namaLengkap: 'User',
      email: 'u@example.test',
      noTelepon: '1',
      password: '',
      createdAt: DateTime(2026),
      isLaravel: true);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    signIn('user-1');
    session = AuthSession();
    repository = ScriptedRepository(session);
    intent = BookingIntent(repository: repository);
  });
  tearDown(() => currentUser = null);

  Future<void> leaveUnknown() async {
    repository.onCreate = (_, __) async =>
        throw const ApiException('timeout', null, 'timeout');
    await expectLater(intent.submit('user-1', fields),
        throwsA(isA<ApiException>().having((e) => e.outcomeUnknown, 'unknown', true)));
  }

  group('submit', () {
    test('success returns the booking with its server status and clears the intent',
        () async {
      repository.onCreate = (_, __) async =>
          Booking(bookingJson(status: 'pending_approval'));
      final booking = await intent.submit('user-1', fields);
      expect(booking.bookingNumber, 'BK-0001');
      expect(booking.status, 'pending_approval');
      expect(await intent.pending('user-1'), isNull);
      expect(repository.keys, hasLength(1));
    });

    test('the intent is persisted before the POST is sent', () async {
      final gate = Completer<Booking>();
      repository.onCreate = (_, __) => gate.future;
      final first = intent.submit('user-1', fields);
      while (repository.keys.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final stored = await const FlutterSecureStorage()
          .read(key: 'booking_intent_user-1');
      expect(stored, contains(repository.keys.single));
      gate.complete(Booking(bookingJson()));
      await first;
    });

    test('422 clears the fresh intent', () async {
      repository.onCreate = (_, __) async =>
          throw const ApiException('invalid', 422);
      await expectLater(
          intent.submit('user-1', fields), throwsA(isA<ApiException>()));
      expect(await intent.pending('user-1'), isNull);
    });

    for (final code in definitiveCreateRejections) {
      test('409 $code clears the fresh intent', () async {
        repository.onCreate = (_, __) async =>
            throw ApiException('conflict', 409, code, {'remaining': 1});
        await expectLater(intent.submit('user-1', fields),
            throwsA(isA<ApiException>().having((e) => e.code, 'code', code)));
        expect(await intent.pending('user-1'), isNull);
      });
    }

    for (final failure in [
      const ApiException('t', null, 'timeout'),
      const ApiException('n', null, 'network'),
      const ApiException('i', 200, 'invalid_response'),
      const ApiException('s', 503),
    ]) {
      test('unknown outcome (${failure.code ?? failure.status}) keeps the intent',
          () async {
        repository.onCreate = (_, __) async => throw failure;
        await expectLater(
            intent.submit('user-1', fields), throwsA(isA<ApiException>()));
        expect(await intent.pending('user-1'), fields);
      });
    }

    test('an unresolved intent blocks a new booking and sends nothing', () async {
      await leaveUnknown();
      final posts = repository.keys.length;
      await expectLater(
          intent.submit('user-1', {...fields, 'quantity': 9}),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', 'intent_unresolved')));
      expect(repository.keys.length, posts);
      expect(await intent.pending('user-1'), fields);
    });

    test('resend keeps the original key and payload and clears on success',
        () async {
      await leaveUnknown();
      repository.onCreate = (_, __) async => Booking(bookingJson());
      final booking = await intent
          .submit('user-1', {...fields, 'quantity': 9}, reconcile: true);
      expect(booking.guid, 'booking-1');
      expect(repository.keys[1], repository.keys[0]);
      expect(repository.payloads[1], fields);
      expect(await intent.pending('user-1'), isNull);
    });

    test('a resend that is still unknown keeps the intent and never retries itself',
        () async {
      await leaveUnknown();
      await expectLater(
          intent.submit('user-1', fields, reconcile: true),
          throwsA(isA<ApiException>()));
      expect(repository.keys, hasLength(2));
      expect(await intent.pending('user-1'), fields);
    });

    test('double tap is rejected while a POST is in flight', () async {
      final gate = Completer<Booking>();
      repository.onCreate = (_, __) => gate.future;
      final first = intent.submit('user-1', fields);
      while (repository.keys.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await expectLater(
          intent.submit('user-1', fields), throwsA(isA<ApiException>()));
      await expectLater(
          intent.reconcile('user-1'), throwsA(isA<ApiException>()));
      await expectLater(
          intent.abandon('user-1'), throwsA(isA<ApiException>()));
      gate.complete(Booking(bookingJson()));
      await first;
      expect(repository.keys, hasLength(1));
    });

    test('a session change mid-flight keeps the intent for reconciliation',
        () async {
      final gate = Completer<Booking>();
      repository.onCreate = (_, __) => gate.future;
      final first = intent.submit('user-1', fields);
      while (repository.keys.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await session.clear();
      gate.complete(Booking(bookingJson()));
      await expectLater(first, throwsA(isA<ApiException>()));
      signIn('user-1');
      expect(await intent.pending('user-1'), fields);
    });

    test('another account is rejected', () async {
      await expectLater(
          intent.submit('other-user', fields), throwsA(isA<ApiException>()));
      expect(repository.keys, isEmpty);
    });
  });

  group('reconcile', () {
    test('without an intent there is nothing to do', () async {
      expect(await intent.reconcile('user-1'), isA<IntentNone>());
      expect(repository.intentCalls, 0);
    });

    test('completed returns the CURRENT server status and deletes the intent',
        () async {
      await leaveUnknown();
      repository.onIntent = (key) async {
        expect(key, repository.keys.single);
        return intentState('completed',
            replaySafe: true,
            booking: Booking(bookingJson(status: 'confirmed')));
      };
      final result = await intent.reconcile('user-1');
      expect(result, isA<IntentCompleted>());
      expect((result as IntentCompleted).booking.status, 'confirmed');
      expect(await intent.pending('user-1'), isNull);
    });

    test('completed after key expiry still resolves to the booking', () async {
      await leaveUnknown();
      repository.onIntent = (_) async => intentState('completed',
          keyExpired: true, booking: Booking(bookingJson(status: 'cancelled')));
      final result = await intent.reconcile('user-1');
      expect((result as IntentCompleted).booking.status, 'cancelled');
      expect(await intent.pending('user-1'), isNull);
    });

    test('not_found replay-safe keeps the intent; resend uses the same key/payload',
        () async {
      await leaveUnknown();
      repository.onIntent =
          (_) async => intentState('not_found', replaySafe: true);
      final result = await intent.reconcile('user-1');
      expect(result, isA<IntentNotFound>());
      expect((result as IntentNotFound).replaySafe, isTrue);
      expect(await intent.pending('user-1'), fields);
      repository.onCreate = (_, __) async => Booking(bookingJson());
      await intent.submit('user-1', {}, reconcile: true);
      expect(repository.keys[1], repository.keys[0]);
      expect(repository.payloads[1], fields);
    });

    test('abandoned on the server cannot be resent and keeps the intent for cleanup',
        () async {
      await leaveUnknown();
      repository.onIntent = (_) async => intentState('abandoned');
      final result = await intent.reconcile('user-1');
      expect(result, isA<IntentUnusable>());
      expect((result as IntentUnusable).abandoned, isTrue);
      expect(await intent.pending('user-1'), fields);
    });

    test('a failed check keeps the intent', () async {
      await leaveUnknown();
      repository.onIntent =
          (_) async => throw const ApiException('t', null, 'timeout');
      await expectLater(
          intent.reconcile('user-1'), throwsA(isA<ApiException>()));
      expect(await intent.pending('user-1'), fields);
    });

    test('a response that arrives after logout does not delete the intent',
        () async {
      await leaveUnknown();
      final gate = Completer<BookingIntentState>();
      repository.onIntent = (_) => gate.future;
      final check = intent.reconcile('user-1');
      while (repository.intentCalls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await session.clear();
      gate.complete(intentState('completed', booking: Booking(bookingJson())));
      await expectLater(check, throwsA(isA<ApiException>()));
      signIn('user-1');
      expect(await intent.pending('user-1'), fields);
    });
  });

  group('abandon', () {
    test('abandons on the server first, then deletes the local intent', () async {
      await leaveUnknown();
      repository.onAbandon = (key) async {
        expect(await intent.pending('user-1'), fields,
            reason: 'local intent must survive until the server answered');
        return intentState('abandoned');
      };
      final result = await intent.abandon('user-1');
      expect(result, isA<IntentAbandoned>());
      expect(repository.abandonedKeys.single, repository.keys.single);
      expect(await intent.pending('user-1'), isNull);
      // After abandoning, a new booking may start with a new key.
      repository.onCreate = (_, __) async => Booking(bookingJson());
      await intent.submit('user-1', fields);
      expect(repository.keys[1], isNot(repository.keys[0]));
    });

    test('intent_already_completed resolves to that booking and deletes the intent',
        () async {
      await leaveUnknown();
      repository.bookingsByGuid['booking-9'] =
          Booking(bookingJson(guid: 'booking-9', status: 'confirmed'));
      repository.onAbandon = (_) async => throw const ApiException(
          'A booking was already created for this attempt.',
          409,
          'intent_already_completed',
          {'booking_guid': 'booking-9'});
      final result = await intent.abandon('user-1');
      expect(result, isA<IntentCompleted>());
      expect((result as IntentCompleted).booking.guid, 'booking-9');
      expect(result.booking.status, 'confirmed');
      expect(await intent.pending('user-1'), isNull);
    });

    test('a failed abandon keeps the local intent', () async {
      await leaveUnknown();
      repository.onAbandon =
          (_) async => throw const ApiException('t', null, 'timeout');
      await expectLater(
          intent.abandon('user-1'), throwsA(isA<ApiException>()));
      expect(await intent.pending('user-1'), fields);
    });

    test('an unexpected abandon answer does not delete the intent', () async {
      await leaveUnknown();
      repository.onAbandon = (_) async => intentState('not_found');
      await expectLater(
          intent.abandon('user-1'), throwsA(isA<ApiException>()));
      expect(await intent.pending('user-1'), fields);
    });
  });

  group('bookingErrorMessage', () {
    String message(String code, [Map<String, dynamic>? context]) =>
        bookingErrorMessage(ApiException('server text', 409, code, context));

    test('every structured code has its own precise Indonesian message', () {
      final codes = [
        'quota_unavailable',
        'insufficient_capacity',
        'booking_window_closed',
        'visit_date_too_close',
        'idempotency_conflict',
        'idempotency_key_expired',
        'idempotency_key_abandoned',
        'intent_already_completed',
        'booking_not_cancellable',
        'booking_already_cancelled',
      ];
      final messages = codes.map(message).toSet();
      expect(messages, hasLength(codes.length));
      expect(messages, isNot(contains('server text')));
    });

    test('insufficient capacity reports the remaining seats', () {
      expect(message('insufficient_capacity', {'remaining': 3}),
          contains('hanya 3 orang'));
      expect(message('insufficient_capacity', {'remaining': 0}),
          contains('penuh'));
      expect(message('insufficient_capacity'), contains('tidak mencukupi'));
    });

    test('unknown 409 code falls back to the server message', () {
      expect(message('something_new'), 'server text');
      expect(bookingErrorMessage(const ApiException('Terjadi konflik.', 409)),
          'Terjadi konflik.');
    });

    test('unknown outcome of a mutation never reads as success or failure', () {
      const timeout = ApiException('Koneksi habis waktu.', null, 'timeout');
      expect(bookingErrorMessage(timeout, mutation: true),
          contains('Hasil belum diketahui'));
      expect(bookingErrorMessage(timeout), 'Koneksi habis waktu.');
      expect(
          bookingErrorMessage(const ApiException('x', 503), mutation: true),
          contains('Hasil belum diketahui'));
    });

    test('non-API errors get a generic message', () {
      expect(bookingErrorMessage(StateError('x')), contains('kesalahan'));
    });
  });
}
