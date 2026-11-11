import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/booking_payment_state.dart';
import 'package:wisata_daerahku/data/payment_models.dart';
import 'package:wisata_daerahku/data/demo_payment_state.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/data/ticket_models.dart';
import 'package:wisata_daerahku/core/config/app_config.dart';

import 'booking_payment_test.dart' show FakeV3Server;
import 'user_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'Midtrans pending PNG is payable despite device clock skew; resume never charges',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final server = FakeV3Server(() => DateTime.utc(2026, 11, 11))
      ..startAttempt(method: 'qris', channel: 'qris');
    final session = await signedInSession(server.handle);
    currentUser = User(
        id: 'user-1',
        namaLengkap: 'User',
        email: 'u@example.test',
        noTelepon: '+6289655862781',
        password: '',
        createdAt: DateTime(2026),
        isLaravel: true);
    final state = BookingPaymentState(repositoryFor(session), 'booking-1',
        now: () => DateTime.utc(2050));
    try {
      await state.open();
      expect(state.phase, PaymentPhase.awaiting);
      await state.onResumed();
      expect(state.phase, PaymentPhase.awaiting);
      expect(server.createPosts, 0);
    } finally {
      state.dispose();
      currentUser = null;
    }
  });

  test('paid needs matching booking snapshot intent and applied attempt',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final server = FakeV3Server(() => DateTime.utc(2026, 11, 11))
      ..startAttempt()
      ..settlePaid();
    final session = await signedInSession(server.handle);
    currentUser = User(
        id: 'user-1',
        namaLengkap: 'User',
        email: 'u@example.test',
        noTelepon: '+6289655862781',
        password: '',
        createdAt: DateTime(2026),
        isLaravel: true);
    final state = BookingPaymentState(repositoryFor(session), 'booking-1');
    try {
      await state.open();
      expect(state.confirmed, isTrue);
      server.appliedAttemptGuid = 'other';
      await state.reload();
      expect(state.confirmed, isFalse);
    } finally {
      state.dispose();
      currentUser = null;
    }
  });

  for (final admission in [
    'temporarily_blocked',
    'revoked',
    'used',
    'unavailable'
  ]) {
    test('admission $admission overrides stale available QR and paid status',
        () {
      final tickets = BookingTickets({
        'booking_guid': 'booking-1',
        'ticket_state': 'available',
        'payment_status': 'paid',
        'entitlement': 'paid',
        'admission_state': admission,
        'admission_reason': 'refund_pending',
        'refund_pending': admission == 'temporarily_blocked',
        'quantity': 1,
        'checked_in_count': 0,
        'tickets': [
          {
            'guid': 'ticket-1',
            'sequence': 1,
            'qr_available': true,
            'status': 'not_checked_in',
            'admission_state': admission
          }
        ],
      });
      expect(tickets.tickets.single.qrAvailable, isFalse);
      expect(tickets.message, isNot(contains('Tunjukkan QR')));
    });
  }

  test('provider/environment mismatch cannot enable native payment choices',
      () {
    final server = FakeV3Server(() => DateTime.utc(2026, 11, 11));
    final data = server.intent()..['environment'] = 'demo';
    expect(PaymentSnapshot(data).payChoices.any((choice) => choice.available),
        isFalse);
  });

  test('cutoff uses elapsed server time and missing clock fails closed',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final server = FakeV3Server(() => DateTime.utc(2026, 11, 11))
      ..startAttempt(method: 'qris', channel: 'qris');
    var elapsed = Duration.zero;
    var omitClock = false;
    final session = await signedInSession((request) async {
      final response = await server.handle(request);
      if (omitClock && request.url.path.endsWith('/payment-intent')) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        (payload['data'] as Map).remove('server_time');
        return jsonResponse(payload);
      }
      return response;
    });
    currentUser = User(
        id: 'user-1',
        namaLengkap: 'User',
        email: 'u@example.test',
        noTelepon: '+6289655862781',
        password: '',
        createdAt: DateTime(2026),
        isLaravel: true);
    final state = BookingPaymentState(repositoryFor(session), 'booking-1',
        now: () => DateTime.utc(2050), elapsed: () => elapsed);
    try {
      await state.open();
      expect(state.windowOpen, isTrue);
      elapsed = const Duration(minutes: 15);
      state.onCountdownElapsed();
      expect(state.windowOpen, isFalse);
      expect(state.phase, PaymentPhase.verifying);
      expect(state.qrPng, isNull);
      expect(state.canRetry, isFalse);
      omitClock = true;
      await state.reload();
      expect(state.windowOpen, isFalse);
      expect(server.createPosts, 0);
    } finally {
      state.dispose();
      currentUser = null;
    }
  });

  test('production build never enables DEMO even when requested', () {
    if (AppConfig.isProduction) expect(AppConfig.demoPaymentEnabled, isFalse);
  });

  test('DEMO mutation state fails closed in a production build', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final server = FakeV3Server(() => DateTime.utc(2026, 11, 11));
    final session = await signedInSession(server.handle);
    currentUser = User(
        id: 'user-1',
        namaLengkap: 'User',
        email: 'u@example.test',
        noTelepon: '+6289655862781',
        password: '',
        createdAt: DateTime(2026),
        isLaravel: true);
    final state = DemoPaymentState(repositoryFor(session), 'booking-1');
    try {
      final data = server.intent()
        ..addAll({
          'provider': 'demo',
          'environment': 'demo',
          'test_only': true,
          'methods': [
            {'code': 'demo', 'available': true}
          ]
        });
      state.booking =
          Booking(bookingJson(guid: 'booking-1', status: 'awaiting_payment'));
      state.methods = PaymentSnapshot(data);
      state.intent = PaymentSnapshot(data);
      state.reconciled = true;
      expect(state.canPay, !AppConfig.isProduction);
    } finally {
      state.dispose();
      currentUser = null;
    }
  });
}
