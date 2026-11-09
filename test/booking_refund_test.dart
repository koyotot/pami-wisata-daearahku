import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/booking_refund_state.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/data/payment_models.dart';
import 'package:wisata_daerahku/screens/booking_payment_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'package:wisata_daerahku/widgets/booking_refund_section.dart';

import 'booking_payment_test.dart' show FakeV3Server;
import 'user_support.dart';

const _storageKey = 'booking_refund_operation_user-1_booking-1';
final _uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
const _longReason =
    'Saya tidak dapat berkunjung pada tanggal yang dipilih karena ada keperluan keluarga mendesak.';

Map<String, dynamic> refundJson(
        {String status = 'requested',
        String? message,
        String? reason = _longReason,
        String? decisionNote,
        String? channel,
        int amount = 20000}) =>
    {
      'guid': 'refund-1',
      'booking_guid': 'booking-1',
      'status': status,
      'message': message ?? 'Pengajuan pengembalian dana sedang ditinjau.',
      'amount': amount,
      'currency': 'IDR',
      'requested_at': '2026-11-09T08:00:00+00:00',
      'decided_at': null,
      'refunded_at': status == 'refunded' || status == 'manual_refunded'
          ? '2026-11-10T08:00:00+00:00'
          : null,
      'refund_channel': channel,
      'reason': reason,
      'decision_note': decisionNote,
    };

/// Scripted Laravel refund API: payment-intent (gate + latest refund), list and create.
class FakeRefundServer {
  String bookingStatus = 'confirmed';
  String paymentStatus = 'paid';
  Map<String, dynamic>? refund;

  int intentGets = 0;
  int postCount = 0;
  final keys = <String>[];
  final bodies = <Map<String, dynamic>>[];
  final storedKeyAtPost = <String?>[];
  Future<String?> Function()? readStoredKey;

  /// Throws a transport error for the first N POSTs.
  int dropPosts = 0;

  /// The dropped POST still lands on the server (response lost).
  bool dropAfterCommit = false;
  int? failStatus;
  String? failCode;
  Completer<void>? barrier;

  Map<String, dynamic> intent() => {
        'booking_guid': 'booking-1',
        'booking_status': bookingStatus,
        'payment_status': paymentStatus,
        'amount': 20000,
        'currency': 'IDR',
        'status': paymentStatus == 'paid' ? 'paid' : 'processing',
        'provider': 'doku',
        'last_attempt': null,
        'refund_request': refund,
      };

  http.Response _ok(Object data) => jsonResponse({'data': data});

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path.endsWith('/payment-intent')) {
      intentGets++;
      return _ok(intent());
    }
    if (request.method == 'GET' && path.endsWith('/refund-requests')) {
      return _ok({
        'refund_requests': [if (refund != null) refund]
      });
    }
    if (request.method == 'POST' && path.endsWith('/refund-requests')) {
      postCount++;
      keys.add(request.headers['Idempotency-Key'] ?? '');
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      storedKeyAtPost.add(await readStoredKey?.call());
      await barrier?.future;
      if (dropPosts > 0) {
        dropPosts--;
        if (dropAfterCommit) refund = refundJson();
        throw http.ClientException('offline');
      }
      if (failStatus != null) {
        return jsonResponse({
          'message': 'x',
          if (failCode != null) 'code': failCode,
          if (failStatus == 422)
            'errors': {
              'reason': ['The reason field must be at least 5 characters.']
            },
        }, failStatus!);
      }
      refund = refundJson();
      return _ok(refund!);
    }
    return jsonResponse({'message': 'not found'}, 404);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late FakeRefundServer server;
  late AuthSession session;
  late BusinessRepository repository;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    server = FakeRefundServer();
    server.readStoredKey =
        () => const FlutterSecureStorage().read(key: _storageKey);
    session = await signedInSession(server.handle);
    currentUser = User(
        id: 'user-1',
        namaLengkap: 'User',
        email: 'u@example.test',
        noTelepon: '+6289655862781',
        password: '',
        createdAt: DateTime(2026),
        isLaravel: true);
    repository = repositoryFor(session);
  });
  tearDown(() => currentUser = null);

  Future<BookingRefundState> loadedState() async {
    final state = BookingRefundState(repository, 'booking-1');
    await state.load();
    addTearDown(state.dispose);
    return state;
  }

  group('RefundRequest model and truthful copy', () {
    test('parses the summary shape and tolerates a null refund_request', () {
      final snapshot = PaymentSnapshot(server.intent());
      expect(snapshot.refundRequest, isNull);
      server.refund = refundJson(status: 'rejected', decisionNote: 'Tiket sudah terbit.');
      final refund = PaymentSnapshot(server.intent()).refundRequest!;
      expect(refund.guid, 'refund-1');
      expect(refund.status, 'rejected');
      expect(refund.amount, 20000);
      expect(refund.decisionNote, 'Tiket sudah terbit.');
      expect(refund.reason, _longReason);
      expect(refund.requestedAt, isNotNull);
      expect(refund.refundedAt, isNull);
    });

    test('a malformed refund_request is an invalid response, not a refund', () {
      final json = server.intent()..['refund_request'] = {'status': 5};
      expect(() => PaymentSnapshot(json).refundRequest,
          throwsA(isA<ApiException>()));
    });

    test('refund-requests list and create hit the documented endpoints', () async {
      server.refund = refundJson();
      final list = await repository.refundRequests('booking-1');
      expect(list.single.status, 'requested');
      final created = await repository.requestRefund('booking-1', 'key-1', 'alasan sah');
      expect(created.status, 'requested');
      expect(server.keys.single, 'key-1');
      expect(server.bodies.single, {'reason': 'alasan sah'});
    });

    test('only refunded may read as money returned, whatever the server message says',
        () {
      const lying = 'Dana Anda sudah dikembalikan ke rekening.';
      for (final status in const [
        'requested',
        'rejected',
        'approved',
        'manual_action_required',
        'refund_pending',
        'needs_review',
        'brand_new_status',
      ]) {
        final refund = RefundRequest(refundJson(status: status, message: lying));
        final shown =
            '${refund.title} ${refund.message} ${refund.statusLabel}'.toLowerCase();
        expect(shown, isNot(contains('dikembalikan')), reason: status);
        expect(shown, isNot(contains('sudah kembali')), reason: status);
        expect(refund.isRefunded, isFalse, reason: status);
      }
      final refunded = RefundRequest(
          refundJson(status: 'refunded', message: 'Dana telah dikembalikan.'));
      expect(refunded.isRefunded, isTrue);
      expect(refunded.message, 'Dana telah dikembalikan.');
    });

    test('manual_refunded is a closed, manual refund and says it was not a DOKU refund',
        () {
      final refund = RefundRequest(refundJson(
          status: 'manual_refunded',
          channel: 'manual',
          message: 'Dana dikembalikan melalui DOKU otomatis.'));
      expect(refund.isManualRefunded, isTrue);
      expect(refund.isRefunded, isFalse);
      expect(refund.isClosedRefund, isTrue);
      expect(refund.isActive, isFalse);
      expect(refund.channel, 'manual');
      expect(refund.refundedAt, isNotNull);
      expect(refund.statusLabel, 'Dana dikembalikan manual');
      expect(refund.title, 'Dana Dikembalikan Manual');
      expect(refund.message, contains('Dana dikembalikan manual oleh pengelola'));
      expect(refund.message, contains('bukan pengembalian otomatis'));
      expect(refund.message, contains('DOKU'));
      // The server wording is not trusted for this status either: it must not claim an automatic refund.
      expect(refund.message, isNot(contains('melalui DOKU otomatis')));
    });

    test('provider refunded stays distinct and refund_channel is read as provider/manual/null',
        () {
      final provider = RefundRequest(refundJson(
          status: 'refunded',
          channel: 'provider',
          message: 'Dana telah dikembalikan.'));
      expect(provider.isRefunded, isTrue);
      expect(provider.isManualRefunded, isFalse);
      expect(provider.isClosedRefund, isTrue);
      expect(provider.channel, 'provider');
      expect(RefundRequest(refundJson(status: 'refunded')).channel, isNull);
      expect(
          RefundRequest(refundJson(status: 'requested', channel: 'weird')).channel,
          isNull);
    });

    test('no status other than refunded and manual_refunded may claim money returned',
        () {
      const lying = 'Dana Anda sudah dikembalikan ke rekening, dikembalikan manual.';
      for (final status in const [
        'requested',
        'rejected',
        'approved',
        'manual_action_required',
        'refund_pending',
        'needs_review',
        'manual_refund',
        'brand_new_status',
      ]) {
        final refund = RefundRequest(
            refundJson(status: status, message: lying, channel: 'manual'));
        final shown =
            '${refund.title} ${refund.message} ${refund.statusLabel}'.toLowerCase();
        expect(shown, isNot(contains('dikembalikan')), reason: status);
        expect(refund.isClosedRefund, isFalse, reason: status);
      }
    });

    test('approved and manual_action_required read as approved but still manual', () {
      for (final status in const ['approved', 'manual_action_required']) {
        final text = RefundRequest(refundJson(status: status, message: ''))
            .message
            .toLowerCase();
        expect(text, contains('disetujui'));
        expect(text, contains('manual'));
        expect(text, contains('belum'));
      }
    });

    test('a truthful backend message is used as the primary copy', () {
      final refund = RefundRequest(refundJson(
          status: 'manual_action_required',
          message: 'Disetujui. Pengelola akan memproses secara manual.'));
      expect(refund.message, 'Disetujui. Pengelola akan memproses secara manual.');
    });

    test('active and blocking statuses', () {
      for (final status in const [
        'requested',
        'approved',
        'manual_action_required',
        'refund_pending',
        'needs_review'
      ]) {
        expect(RefundRequest(refundJson(status: status)).isActive, isTrue);
      }
      expect(RefundRequest(refundJson(status: 'rejected')).isActive, isFalse);
      expect(RefundRequest(refundJson(status: 'refunded')).isActive, isFalse);
    });

    test('409 and 422 map to clear Indonesian messages', () {
      String message(int status, [String? code]) =>
          refundErrorMessage(ApiException('x', status, code));
      expect(message(409, 'ticket_already_used'),
          'Tiket sudah dipakai sehingga tidak dapat diajukan pengembalian dana.');
      expect(message(409, 'refund_already_requested'),
          contains('sudah pernah diajukan'));
      expect(message(409, 'refund_not_available'), contains('tidak tersedia'));
      expect(message(409, 'idempotency_conflict'), contains('berbeda'));
      expect(message(422), contains('5'));
      expect(message(404), contains('tidak ditemukan'));
      expect(refundErrorMessage(const ApiException('x', null, 'timeout')),
          contains('tidak terkirim ganda'));
    });

    test('reason validation: trimmed, 5 to 500 characters', () {
      expect(validateRefundReason(''), isNotNull);
      expect(validateRefundReason('   abc  '), isNotNull);
      expect(validateRefundReason('abcde'), isNull);
      expect(validateRefundReason('a' * 500), isNull);
      expect(validateRefundReason('a' * 501), isNotNull);
    });
  });

  group('BookingRefundState', () {
    test('CTA only for a paid and confirmed booking without an active or refunded request',
        () async {
      var state = await loadedState();
      expect(state.canRequest, isTrue);

      server.paymentStatus = 'unverified';
      state = await loadedState();
      expect(state.canRequest, isFalse);
      server.paymentStatus = 'paid';
      server.bookingStatus = 'awaiting_payment';
      state = await loadedState();
      expect(state.canRequest, isFalse);
      server.bookingStatus = 'confirmed';

      const expected = {
        'requested': false,
        'approved': false,
        'manual_action_required': false,
        'refund_pending': false,
        'needs_review': false,
        'refunded': false,
        'manual_refunded': false,
        'rejected': true,
        'something_unknown': false,
      };
      for (final entry in expected.entries) {
        server.refund = refundJson(status: entry.key);
        state = await loadedState();
        expect(state.canRequest, entry.value, reason: entry.key);
      }
    });

    test('a failed first load shows nothing and offers no CTA', () async {
      server.refund = null;
      final failing = await signedInSession((r) async => jsonResponse({'message': 'x'}, 500));
      final state = BookingRefundState(repositoryFor(failing), 'booking-1');
      addTearDown(state.dispose);
      await state.load();
      expect(state.loaded, isFalse);
      expect(state.canRequest, isFalse);
    });

    test('sends reason only, with a stored UUID Idempotency-Key, and clears it on success',
        () async {
      final state = await loadedState();
      final ok = await state.submit('  $_longReason  ');
      expect(ok, isTrue);
      expect(server.postCount, 1);
      expect(server.bodies.single, {'reason': _longReason});
      expect(server.bodies.single.keys, ['reason']);
      expect(server.keys.single, matches(_uuidV4));
      expect(server.storedKeyAtPost.single, contains(server.keys.single));
      expect(await const FlutterSecureStorage().read(key: _storageKey), isNull);
      expect(state.refund!.status, 'requested');
      expect(state.canRequest, isFalse);
      expect(state.error, isNull);
    });

    test('a retry after a timeout reuses the same key and reason', () async {
      final state = await loadedState();
      server.dropPosts = 1;
      expect(await state.submit(_longReason), isFalse);
      expect(state.error, contains('tidak terkirim ganda'));
      expect(await const FlutterSecureStorage().read(key: _storageKey),
          contains(server.keys.single));
      expect(state.pendingReason, _longReason);

      // A different reason cannot be attached to the unfinished key.
      expect(await state.submit('alasan lain yang berbeda'), isTrue);
      expect(server.postCount, 2);
      expect(server.keys[1], server.keys[0]);
      expect(server.bodies[1], {'reason': _longReason});
      expect(await const FlutterSecureStorage().read(key: _storageKey), isNull);
    });

    test('the stored key survives a restart and the landed request clears it',
        () async {
      final state = await loadedState();
      server.dropPosts = 1;
      server.dropAfterCommit = true;
      await state.submit(_longReason);

      final restarted = BookingRefundState(repository, 'booking-1');
      addTearDown(restarted.dispose);
      await restarted.load();
      expect(restarted.refund!.status, 'requested');
      expect(restarted.pendingReason, isNull);
      expect(await const FlutterSecureStorage().read(key: _storageKey), isNull);
      expect(restarted.canRequest, isFalse);
    });

    test('a manually refunded request closes the booking: no CTA and the stored key is dropped',
        () async {
      await const FlutterSecureStorage().write(
          key: _storageKey, value: jsonEncode({'key': 'k-1', 'reason': _longReason}));
      server.refund = refundJson(status: 'manual_refunded', channel: 'manual');
      final state = await loadedState();
      expect(state.canRequest, isFalse);
      expect(state.refund!.isManualRefunded, isTrue);
      expect(state.pendingReason, isNull);
      expect(await const FlutterSecureStorage().read(key: _storageKey), isNull);
      expect(await state.submit(_longReason), isFalse);
      expect(server.postCount, 0);
    });

    test('422 clears the key, keeps the form usable and says what is wrong', () async {
      final state = await loadedState();
      server.failStatus = 422;
      expect(await state.submit(_longReason), isFalse);
      expect(state.error, contains('5'));
      expect(await const FlutterSecureStorage().read(key: _storageKey), isNull);
      expect(state.pendingReason, isNull);
      expect(state.canRequest, isTrue);

      server.failStatus = null;
      expect(await state.submit(_longReason), isTrue);
      expect(server.keys[1], isNot(server.keys[0]));
    });

    test('409 codes map to messages and definitive ones clear the key', () async {
      for (final code in const [
        'refund_already_requested',
        'refund_not_available',
        'ticket_already_used',
        'idempotency_conflict',
      ]) {
        final state = await loadedState();
        server.failStatus = 409;
        server.failCode = code;
        expect(await state.submit(_longReason), isFalse, reason: code);
        expect(state.error, refundErrorMessage(ApiException('x', 409, code)));
        expect(await const FlutterSecureStorage().read(key: _storageKey), isNull,
            reason: code);
      }
      final state = await loadedState();
      server.failCode = 'ticket_already_used';
      await state.submit(_longReason);
      expect(state.error, contains('Tiket sudah dipakai'));
    });

    test('invalid reasons never reach the server', () async {
      final state = await loadedState();
      expect(await state.submit('abc'), isFalse);
      expect(await state.submit('a' * 501), isFalse);
      expect(server.postCount, 0);
      expect(state.error, isNotNull);
      expect(await const FlutterSecureStorage().read(key: _storageKey), isNull);
    });

    test('concurrent submits send exactly one request', () async {
      final state = await loadedState();
      server.barrier = Completer<void>();
      final first = state.submit(_longReason);
      final second = state.submit(_longReason);
      expect(await second, isFalse);
      server.barrier!.complete();
      expect(await first, isTrue);
      expect(server.postCount, 1);
    });

    test('does not submit when the booking is not eligible', () async {
      server.paymentStatus = 'unverified';
      final state = await loadedState();
      expect(await state.submit(_longReason), isFalse);
      expect(server.postCount, 0);
    });
  });

  group('BookingRefundSection', () {
    Future<void> pump(WidgetTester tester,
        {Size size = const Size(393, 852), double textScale = 1}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: BookingRefundSection(
                      repository: repository, bookingGuid: 'booking-1')))));
      await tester.pump();
      await tester.pump();
    }

    Finder open() => find.byKey(const Key('refund-open'));
    Finder field() => find.byKey(const Key('refund-reason'));
    Finder submit() => find.byKey(const Key('refund-submit'));

    testWidgets('hidden unless the booking is paid and confirmed', (tester) async {
      server.paymentStatus = 'unverified';
      await pump(tester);
      expect(find.byKey(const Key('refund-section')), findsNothing);
      expect(find.text('Ajukan Pengembalian Dana'), findsNothing);
    });

    testWidgets('opens the sheet, validates, submits once and shows the request',
        (tester) async {
      await pump(tester);
      expect(find.text('Ajukan Pengembalian Dana'), findsOneWidget);
      await tester.tap(open());
      await tester.pumpAndSettle();

      await tester.enterText(field(), 'abc');
      await tester.tap(submit());
      await tester.pump();
      expect(find.byKey(const Key('refund-reason-error')), findsOneWidget);
      expect(server.postCount, 0);

      await tester.enterText(field(), _longReason);
      await tester.pump();
      await tester.tap(submit(), warnIfMissed: false);
      await tester.tap(submit(), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(server.postCount, 1);
      expect(server.bodies.single, {'reason': _longReason});
      expect(field(), findsNothing);
      expect(find.byKey(const Key('refund-status-requested')), findsOneWidget);
      expect(find.text('Ajukan Pengembalian Dana'), findsNothing);
    });

    testWidgets('submit is disabled and shows progress while sending', (tester) async {
      await pump(tester);
      await tester.tap(open());
      await tester.pumpAndSettle();
      server.barrier = Completer<void>();
      await tester.enterText(field(), _longReason);
      await tester.pump();
      await tester.tap(submit());
      await tester.pump();
      expect(tester.widget<ButtonStyleButton>(submit()).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      server.barrier!.complete();
      await tester.pumpAndSettle();
      expect(field(), findsNothing);
    });

    testWidgets('a 409 ticket_already_used error stays in the sheet in Indonesian',
        (tester) async {
      await pump(tester);
      await tester.tap(open());
      await tester.pumpAndSettle();
      server.failStatus = 409;
      server.failCode = 'ticket_already_used';
      await tester.enterText(field(), _longReason);
      await tester.pump();
      await tester.tap(submit());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('refund-submit-error')), findsOneWidget);
      expect(find.textContaining('Tiket sudah dipakai'), findsOneWidget);
    });

    testWidgets('a rejected request shows the decision note and allows a new request',
        (tester) async {
      server.refund = refundJson(
          status: 'rejected',
          message: 'Pengajuan ditolak.',
          decisionNote: 'Kunjungan sudah lewat.');
      await pump(tester);
      expect(find.textContaining('Kunjungan sudah lewat.'), findsOneWidget);
      expect(open(), findsOneWidget);
    });

    testWidgets('manual_action_required never reads as money returned', (tester) async {
      server.refund = refundJson(
          status: 'manual_action_required',
          message: 'Dana sudah dikembalikan.');
      await pump(tester);
      expect(find.textContaining('dikembalikan'), findsNothing);
      expect(find.textContaining('manual'), findsWidgets);
      expect(open(), findsNothing);
    });

    testWidgets('manual_refunded is shown as a manual refund with its date and no CTA',
        (tester) async {
      server.refund = refundJson(
          status: 'manual_refunded',
          channel: 'manual',
          message: 'Dana dikembalikan.');
      await pump(tester);
      expect(find.byKey(const Key('refund-status-manual_refunded')), findsOneWidget);
      expect(find.text('Dana Dikembalikan Manual'), findsOneWidget);
      expect(find.textContaining('Dana dikembalikan manual oleh pengelola'),
          findsOneWidget);
      expect(find.textContaining('bukan pengembalian otomatis'), findsOneWidget);
      expect(find.textContaining('10 November 2026'), findsOneWidget);
      expect(open(), findsNothing);
      expect(find.byKey(const Key('refund-refresh')), findsNothing);
    });

    testWidgets('refunded shows returned money and no CTA', (tester) async {
      server.refund = refundJson(
          status: 'refunded', message: 'Dana telah dikembalikan.');
      await pump(tester);
      expect(find.textContaining('dikembalikan'), findsWidgets);
      expect(open(), findsNothing);
    });

    for (final size in const [Size(320, 640), Size(393, 852), Size(430, 932)]) {
      for (final scale in const [1.0, 2.0]) {
        for (final status in const [
          null,
          'requested',
          'manual_action_required',
          'refund_pending',
          'rejected',
          'refunded',
          'manual_refunded',
        ]) {
          testWidgets('no overflow ${size.width.toInt()}w x$scale ${status ?? 'cta'}',
              (tester) async {
            if (status != null) {
              server.refund = refundJson(
                  status: status,
                  message: 'Pengajuan pengembalian dana Anda ${'sedang diproses oleh pengelola ' * 4}',
                  decisionNote: 'Catatan keputusan yang cukup panjang ${'dari pengelola ' * 6}');
            }
            await pump(tester, size: size, textScale: scale);
            expect(find.byKey(const Key('refund-section')), findsOneWidget);
            expect(tester.takeException(), isNull);
          });
        }
        testWidgets('no overflow sheet ${size.width.toInt()}w x$scale', (tester) async {
          await pump(tester, size: size, textScale: scale);
          await tester.ensureVisible(open());
          await tester.pump();
          await tester.tap(open());
          await tester.pumpAndSettle();
          await tester.enterText(field(), 'abc');
          await tester.ensureVisible(submit());
          await tester.pump();
          await tester.tap(submit());
          await tester.pump();
          expect(find.byKey(const Key('refund-reason-error')), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('payment success placement', () {
    testWidgets('the paid screen offers the refund action without extra intent reads',
        (tester) async {
      var now = DateTime.utc(2026, 11, 9, 8);
      final paid = FakeV3Server(() => now)..settlePaid();
      final paidSession = await signedInSession((request) async {
        if (request.url.path.endsWith('/refund-requests')) {
          return jsonResponse({
            'data': {'refund_requests': []}
          });
        }
        return paid.handle(request);
      });
      tester.view.physicalSize = const Size(393, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: BookingPaymentScreen(
              bookingGuid: 'booking-1',
              repository: repositoryFor(paidSession),
              now: () => now,
              jitter: () => 0.5)));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('pay-success')), findsOneWidget);
      expect(find.byKey(const Key('refund-open')), findsOneWidget);
      expect(paid.intentGets, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
