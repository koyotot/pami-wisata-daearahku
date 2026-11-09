import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/booking_payment_state.dart';
import 'package:wisata_daerahku/data/booking_state.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/data/payment_models.dart';
import 'package:wisata_daerahku/screens/booking_payment_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'package:wisata_daerahku/services/payment_qr_export.dart';
import 'package:wisata_daerahku/widgets/booking_payment_section.dart';
import 'package:wisata_daerahku/widgets/booking_ticket_qr_section.dart';

import 'user_support.dart';

const _operationKey = 'booking_payment_operation_user-1_booking-1';
final _pngSignature = Uint8List.fromList(
    [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);
const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="#000"/></svg>';

/// Scripted Laravel payment API for BNI VA + QRIS. Mirrors the documented additive contract and
/// records every call with the injected fake clock so the polling contract can be asserted.
class FakeV3Server {
  FakeV3Server(this.clock);
  final DateTime Function() clock;

  String bookingStatus = 'awaiting_payment';
  String bookingPaymentStatus = 'unverified';
  String intentStatus = 'not_created';
  String? attemptStatus;
  String attemptGuid = 'att-0';
  String attemptMethod = 'virtual_account';
  String attemptChannel = 'bni';
  DateTime? attemptExpiresAt;
  String? appliedAttemptGuid;
  bool verificationPending = false;
  bool escalated = false;
  DateTime? paidAt;
  bool receiptAvailable = false;
  bool canCreate = true;
  bool canPay = true;
  String? switchReason = 'payment_switch_contract_unverified';
  bool bniAvailable = true;
  String? bniReason;
  bool qrisAvailable = true;
  String? qrisReason;
  bool ewalletAvailable = true;
  late DateTime bookingExpiry = clock().add(const Duration(hours: 2));
  String vaNumber = '8277012345678901';

  // Tickets
  String ticketState = 'scheduled';
  bool ticketQrAvailable = false;

  // Failure injection.
  bool offline = false;
  int? refreshFailure;
  String? retryAfter;
  int? createFailure;
  bool createCommitsThenFails = false;
  int qrStatus = 200;
  Completer<void>? refreshBarrier;
  void Function()? onRefresh;
  String createResponseStatus = 'pending';

  // Counters.
  int createPosts = 0;
  int refreshPosts = 0;
  int intentGets = 0;
  int methodsGets = 0;
  int bookingGets = 0;
  int qrGets = 0;
  int receiptGets = 0;
  int ticketGets = 0;
  int ticketQrGets = 0;
  int inFlight = 0;
  int maxInFlight = 0;
  int offlineRefreshAttempts = 0;
  final createKeys = <String>[];
  final createBodies = <Map<String, dynamic>>[];
  final storedKeyAtCreate = <String?>[];
  final refreshAt = <DateTime>[];
  final probeAt = <DateTime>[];
  final allRequests = <String>[];
  Future<String?> Function()? readStoredKey;

  int get totalRequests => allRequests.length;

  void settlePaid({String channel = 'bni', String method = 'virtual_account'}) {
    attemptMethod = method;
    attemptChannel = channel;
    attemptStatus = 'paid';
    intentStatus = 'paid';
    appliedAttemptGuid = attemptGuid;
    verificationPending = false;
    escalated = false;
    bookingStatus = 'confirmed';
    bookingPaymentStatus = 'paid';
    paidAt = clock();
    receiptAvailable = true;
    canCreate = false;
  }

  void startAttempt(
      {String method = 'virtual_account',
      String channel = 'bni',
      String status = 'pending'}) {
    attemptGuid = 'att-${createPosts + 1}';
    attemptMethod = method;
    attemptChannel = channel;
    attemptStatus = status;
    intentStatus = 'processing';
    attemptExpiresAt = clock().add(const Duration(minutes: 30));
    canCreate = false;
  }

  Map<String, dynamic> _instruction() {
    if (attemptStatus != 'pending') return {'presentation_type': 'unavailable'};
    if (attemptExpiresAt != null && !clock().isBefore(attemptExpiresAt!)) {
      return {'presentation_type': 'unavailable'};
    }
    if (attemptMethod == 'qris') {
      return {
        'presentation_type': 'qr_payload',
        'qr_content': '00020101021226670016COM.NOBUBANK.WWW',
        'copyable': false
      };
    }
    return {
      'presentation_type': 'virtual_account',
      'bank_code': 'bni',
      'va_number': vaNumber,
      'copyable': true
    };
  }

  List<Map<String, dynamic>> _methods() => [
        {
          'code': 'qris',
          'available': qrisAvailable,
          'presentation_type': 'qr_payload',
          'reason': qrisReason,
          'channels': [
            {
              'channel': 'qris',
              'available': qrisAvailable,
              'presentation_type': 'qr_payload',
              'reason': qrisReason
            }
          ]
        },
        {
          'code': 'virtual_account',
          'available': bniAvailable,
          'presentation_type': 'virtual_account',
          'reason': bniReason,
          'channel': 'bni',
          'channels': [
            {
              'channel': 'bni',
              'available': bniAvailable,
              'presentation_type': 'virtual_account',
              'reason': bniReason
            }
          ]
        },
        {
          'code': 'ewallet',
          'available': ewalletAvailable,
          'presentation_type': 'ewallet_redirect',
          'reason': null,
          'channels': [
            {
              'channel': 'dana',
              'available': ewalletAvailable,
              'presentation_type': 'ewallet_redirect',
              'reason': null
            },
            {
              'channel': 'shopeepay',
              'available': ewalletAvailable,
              'presentation_type': 'ewallet_redirect',
              'reason': null
            }
          ]
        }
      ];

  Map<String, dynamic> intent() => {
        'booking_guid': 'booking-1',
        'booking_status': bookingStatus,
        'booking_number': 'BK-0001',
        'invoice_number': 'INV-2026-0001',
        'quantity': 2,
        'unit_price': 10000,
        'subtotal': 20000,
        'service_fee': 0,
        'total_amount': 20000,
        'paid_at': paidAt?.toUtc().toIso8601String(),
        'applied_attempt_guid': appliedAttemptGuid,
        'receipt_available': receiptAvailable,
        'can_create': canCreate,
        'can_switch': false,
        'switch_reason': switchReason,
        'availability': canPay ? 'available' : 'unavailable',
        'reason': canPay ? null : (bniReason ?? qrisReason),
        'can_pay': canPay,
        'amount': 20000,
        'currency': 'IDR',
        'payment_status': bookingPaymentStatus,
        'expires_at': bookingExpiry.toUtc().toIso8601String(),
        'provider': 'doku',
        'environment': 'sandbox',
        'test_only': true,
        'intent_guid': intentStatus == 'not_created' ? null : 'intent-1',
        'status': intentStatus,
        'methods': _methods(),
        'last_attempt': attemptStatus == null
            ? null
            : {
                'attempt_guid': attemptGuid,
                'status': attemptStatus,
                'method': attemptMethod,
                'channel': attemptChannel,
                'started_at': '2026-11-09T08:00:00+00:00',
                'finished_at': null,
                'expires_at': attemptExpiresAt?.toUtc().toIso8601String(),
                'verification_pending': verificationPending,
                'escalated': escalated,
              },
        'instruction': _instruction(),
      };

  Map<String, dynamic> tickets() => {
        'booking_guid': 'booking-1',
        'visit_date': '2026-11-15',
        'timezone': 'Asia/Jakarta',
        'qr_available_from': '2026-11-10',
        'quantity': 2,
        'checked_in_count': 0,
        'payment_status': bookingPaymentStatus,
        'ticket_state': ticketState,
        'tickets': [
          for (var i = 1; i <= 2; i++)
            {
              'guid': 'ticket-$i',
              'sequence': i,
              'status': 'not_checked_in',
              'qr_available': ticketQrAvailable,
              'checked_in_at': null
            }
        ],
      };

  http.Response _ok(Object data) => jsonResponse({'data': data});

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    allRequests.add('${request.method} $path');
    if (offline && request.method == 'POST' && path.endsWith('/refresh')) {
      offlineRefreshAttempts++;
    }
    if (offline) throw http.ClientException('offline');
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    try {
      if (request.method == 'POST' && path.endsWith('/refresh')) {
        refreshPosts++;
        refreshAt.add(clock());
        await refreshBarrier?.future;
        if (refreshFailure != null) {
          return http.Response(jsonEncode({'message': 'x'}), refreshFailure!,
              headers: {
                'content-type': 'application/json',
                if (retryAfter != null) 'retry-after': retryAfter!,
              });
        }
        onRefresh?.call();
        return _ok(intent());
      }
      if (request.method == 'POST' && path.endsWith('/payment-attempts')) {
        createPosts++;
        createKeys.add(request.headers['Idempotency-Key'] ?? '');
        createBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        storedKeyAtCreate.add(await readStoredKey?.call());
        if (createFailure != null) {
          return jsonResponse({'message': 'x'}, createFailure!);
        }
        final body = createBodies.last;
        startAttempt(
            method: body['method_code'] as String,
            channel: body['channel'] as String);
        if (createCommitsThenFails) return jsonResponse({'message': 'x'}, 500);
        return _ok({
          ...intent(),
          'attempt_guid': attemptGuid,
          'status': createResponseStatus,
          'method_code': attemptMethod,
          'channel': attemptChannel,
          'expires_at': attemptExpiresAt!.toUtc().toIso8601String(),
        });
      }
      if (request.method == 'GET' &&
          path.contains('/payment-attempts/') &&
          path.endsWith('/qr')) {
        qrGets++;
        if (qrStatus != 200) return jsonResponse({'message': 'x'}, qrStatus);
        return http.Response(_svg, 200, headers: {
          'content-type': 'image/svg+xml',
          'cache-control': 'private, no-store'
        });
      }
      if (request.method == 'GET' &&
          path.contains('/tickets/') &&
          path.endsWith('/qr')) {
        ticketQrGets++;
        return http.Response(_svg, 200,
            headers: {'content-type': 'image/svg+xml'});
      }
      if (request.method == 'GET' && path.endsWith('/documents/receipt')) {
        receiptGets++;
        return http.Response('%PDF-1.4 receipt', 200,
            headers: {'content-type': 'application/pdf'});
      }
      if (path.endsWith('/payment-intent')) {
        intentGets++;
        probeAt.add(clock());
        return _ok(intent());
      }
      if (path.endsWith('/payments/methods')) {
        methodsGets++;
        return _ok(intent());
      }
      if (path.endsWith('/bookings/booking-1/tickets')) {
        ticketGets++;
        return _ok(tickets());
      }
      if (path.endsWith('/bookings/booking-1')) {
        bookingGets++;
        return _ok({
          ...bookingJson(guid: 'booking-1', status: bookingStatus),
          'payment_status': bookingPaymentStatus,
          'payment_expires_at': bookingExpiry.toUtc().toIso8601String(),
        });
      }
      return jsonResponse({'message': 'not found'}, 404);
    } finally {
      inFlight--;
    }
  }
}

class FakeExporter implements PaymentQrExporter {
  bool isSupported = true;
  PaymentQrExportResult nextResult = PaymentQrExportResult.saved;
  final saved = <Uint8List>[];
  final shared = <Uint8List>[];
  final names = <String>[];
  @override
  bool get supported => isSupported;
  @override
  Future<PaymentQrExportResult> save(Uint8List png,
      {required String fileName}) async {
    saved.add(png);
    names.add(fileName);
    return nextResult;
  }

  @override
  Future<PaymentQrExportResult> share(Uint8List png,
      {required String fileName}) async {
    shared.add(png);
    names.add(fileName);
    return nextResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  late DateTime now;
  late FakeV3Server server;
  late AuthSession session;
  late BusinessRepository repository;
  late FakeExporter exporter;
  final documents = <String>[];

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    now = DateTime.utc(2026, 11, 9, 8);
    server = FakeV3Server(() => now);
    server.readStoredKey = () =>
        const FlutterSecureStorage().read(key: _operationKey);
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
    exporter = FakeExporter();
    documents.clear();
  });
  tearDown(() => currentUser = null);

  Future<SavedDocument> fakeSaver(
      BusinessRepository repo, String guid, String type,
      {String? bookingNumber}) async {
    final response = await repo.downloadDocument(guid, type);
    documents.add(type);
    return SavedDocument('/tmp/$type-$bookingNumber.pdf', response.bytes.length);
  }

  BookingPaymentScreen screen({Key? key}) => BookingPaymentScreen(
      key: key,
      bookingGuid: 'booking-1',
      repository: repository,
      exporter: exporter,
      now: () => now,
      jitter: () => 0.5,
      rasterizer: (svg) async => _pngSignature,
      documentSaver: fakeSaver);

  Future<void> pumpScreen(WidgetTester tester,
      {Size size = const Size(393, 852),
      double textScale = 1,
      GlobalKey<NavigatorState>? navigatorKey}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!),
        home: screen()));
    await tester.pump();
    await tester.pump();
  }

  /// Advances both the fake clock and Flutter's fake timers one second at a time.
  Future<void> elapse(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  Finder choice(String method, String channel) =>
      find.byKey(Key('pay-choice-$method-$channel'));
  Finder start() => find.byKey(const Key('pay-start'));
  Future<void> tap(WidgetTester tester, Finder finder, {int times = 1}) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    for (var i = 0; i < times; i++) {
      await tester.tap(finder, warnIfMissed: false);
    }
  }

  bool enabled(WidgetTester tester, Finder finder) =>
      tester.widget<ButtonStyleButton>(finder).onPressed != null;

  group('PaymentSnapshot additive contract', () {
    test('reads invoice, paid and attempt expiry without coercing to zero', () {
      final json = server.intent();
      server.settlePaid();
      final paid = PaymentSnapshot(server.intent());
      expect(PaymentSnapshot(json).invoiceNumber, 'INV-2026-0001');
      expect(paid.totalAmount, 20000);
      expect(paid.unitPrice, 10000);
      expect(paid.quantity, 2);
      expect(paid.paidAt, now);
      expect(paid.appliedAttemptGuid, 'att-0');
      expect(paid.receiptAvailable, isTrue);

      final bare = PaymentSnapshot({
        'booking_guid': 'booking-1',
        'amount': 20000,
        'currency': 'IDR',
        'status': 'not_created',
        'last_attempt': {'attempt_guid': 'a', 'status': 'pending'},
      });
      expect(bare.paidAt, isNull);
      expect(bare.attemptExpiresAt, isNull);
      expect(bare.subtotal, isNull);
      expect(bare.serviceFee, isNull);
      expect(bare.invoiceNumber, isNull);
      expect(bare.canCreate, isFalse);
      expect(bare.receiptAvailable, isFalse);
    });

    test('attempt expiry comes from last_attempt, not the booking deadline',
        () {
      server.startAttempt();
      final snapshot = PaymentSnapshot(server.intent());
      expect(snapshot.attemptExpiresAt, server.attemptExpiresAt);
      expect(snapshot.attemptExpiresAt, isNot(server.bookingExpiry));
    });

    test('only BNI VA and QRIS are payable choices; wallets are never offered',
        () {
      final snapshot = PaymentSnapshot(server.intent());
      expect(snapshot.payChoices.map((c) => c.key).toList(),
          ['virtual_account/bni', 'qris/qris']);
      expect(snapshot.payChoices.every((c) => c.available), isTrue);

      server.bniAvailable = false;
      server.bniReason = 'provider_expiry_window_unverified';
      final blocked = PaymentSnapshot(server.intent());
      final bni = blocked.payChoices.firstWhere((c) => c.channel == 'bni');
      expect(bni.available, isFalse);
      expect(bni.reason, 'provider_expiry_window_unverified');

      server.canPay = false;
      expect(PaymentSnapshot(server.intent()).payChoices.every((c) => c.available),
          isFalse);
    });
  });

  group('selection and create', () {
    testWidgets(
        'opening and leaving the page creates nothing; two options, no amount input, no wallet',
        (tester) async {
      await pumpScreen(tester);
      expect(choice('virtual_account', 'bni'), findsOneWidget);
      expect(choice('qris', 'qris'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('DANA'), findsNothing);
      expect(find.textContaining('ShopeePay'), findsNothing);
      expect(find.text('Rp20.000'), findsWidgets);
      expect(find.text('INV-2026-0001'), findsOneWidget);
      expect(enabled(tester, start()), isFalse);
      await unmount(tester);
      expect(server.createPosts, 0);
    });

    testWidgets('unavailable channels show the server reason and no CTA',
        (tester) async {
      server.bniAvailable = false;
      server.bniReason = 'provider_expiry_window_unverified';
      server.qrisAvailable = false;
      server.qrisReason = 'channel_contract_unverified';
      server.canPay = false;
      server.canCreate = false;
      await pumpScreen(tester);
      expect(find.textContaining('batas waktu pembayaran'), findsWidgets);
      expect(find.textContaining('provider_expiry_window_unverified'),
          findsWidgets);
      await tap(tester, choice('virtual_account', 'bni'));
      await tester.pump();
      expect(enabled(tester, start()), isFalse);
      await tap(tester, start());
      await tester.pump();
      expect(server.createPosts, 0);
    });

    testWidgets(
        'CTA creates exactly once with the persisted key and only method/channel',
        (tester) async {
      await pumpScreen(tester);
      await tap(tester, choice('qris', 'qris'));
      await tester.pump();
      expect(enabled(tester, start()), isTrue);
      await tap(tester, start(), times: 2);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(server.createPosts, 1);
      expect(server.createBodies.single, {
        'method_code': 'qris',
        'channel': 'qris',
      });
      expect(server.createKeys.single, isNotEmpty);
      // The key was already in secure storage when the POST happened, and is cleared once resolved.
      expect(server.storedKeyAtCreate.single, contains(server.createKeys.single));
      expect(await const FlutterSecureStorage().read(key: _operationKey),
          isNull);
      expect(find.byKey(const Key('pay-qr-image')), findsOneWidget);
      // Instruction is shown; the page never offers a second create.
      expect(start(), findsNothing);
    });

    testWidgets('uncommitted failure: key survives restart and is reused once',
        (tester) async {
      server.createFailure = 500;
      await pumpScreen(tester);
      await tap(tester, choice('virtual_account', 'bni'));
      await tester.pump();
      await tap(tester, start());
      await tester.pump();
      await tester.pump();
      expect(server.createPosts, 1);
      final stored = await const FlutterSecureStorage().read(key: _operationKey);
      expect(stored, contains(server.createKeys.single));
      await unmount(tester);

      server.createFailure = null;
      await pumpScreen(tester);
      // Restart never auto-creates.
      expect(server.createPosts, 1);
      await tap(tester, choice('virtual_account', 'bni'));
      await tester.pump();
      await tap(tester, start());
      await tester.pump();
      await tester.pump();
      expect(server.createPosts, 2);
      expect(server.createKeys.last, server.createKeys.first);
    });

    testWidgets(
        'timeout after the server committed recovers the old attempt without a second POST',
        (tester) async {
      server.createCommitsThenFails = true;
      await pumpScreen(tester);
      await tap(tester, choice('virtual_account', 'bni'));
      await tester.pump();
      await tap(tester, start());
      await tester.pump();
      await tester.pump();
      expect(server.createPosts, 1);
      expect(find.byKey(const Key('pay-va-number')), findsOneWidget);
      expect(start(), findsNothing);
      await unmount(tester);

      await pumpScreen(tester);
      expect(server.createPosts, 1);
      expect(find.byKey(const Key('pay-va-number')), findsOneWidget);
      expect(await const FlutterSecureStorage().read(key: _operationKey),
          isNull);
    });

    testWidgets('an active attempt blocks switching and explains why',
        (tester) async {
      server.startAttempt();
      server.switchReason = 'payment_attempt_unresolved';
      await pumpScreen(tester);
      expect(choice('qris', 'qris'), findsNothing);
      expect(start(), findsNothing);
      expect(find.byKey(const Key('pay-switch-note')), findsOneWidget);
      expect(find.textContaining('tidak dapat diganti'), findsOneWidget);
    });
  });

  group('instructions', () {
    testWidgets('VA shows the server number and copies the raw digits',
        (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      server.startAttempt();
      await pumpScreen(tester);
      expect(find.text('8277 0123 4567 8901'), findsOneWidget);
      expect(find.textContaining('Bank BNI'), findsWidgets);
      await tap(tester, find.byKey(const Key('pay-va-copy')));
      await tester.pump();
      expect(copied, '8277012345678901');
      expect(find.textContaining('disalin'), findsWidgets);
    });

    testWidgets(
        'QRIS image comes from the server endpoint, is labelled as payment QR, and exports PNG',
        (tester) async {
      final semantics = tester.ensureSemantics();
      server.startAttempt(method: 'qris', channel: 'qris');
      await pumpScreen(tester);
      expect(server.qrGets, 1);
      expect(find.byKey(const Key('pay-qr-image')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('QR pembayaran QRIS.*bukan tiket masuk')),
          findsOneWidget);
      expect(find.textContaining('Tiket masuk'), findsNothing);

      await tap(tester, find.byKey(const Key('pay-qr-save')));
      await tester.pump();
      await tester.pump();
      expect(exporter.saved.single, _pngSignature);
      expect(find.textContaining('tersimpan'), findsWidgets);

      await tap(tester, find.byKey(const Key('pay-qr-share')));
      await tester.pump();
      await tester.pump();
      expect(exporter.shared.single, _pngSignature);
      semantics.dispose();
    });

    for (final entry in {
      PaymentQrExportResult.cancelled: 'dibatalkan',
      PaymentQrExportResult.denied: 'izin',
      PaymentQrExportResult.failed: 'gagal',
      PaymentQrExportResult.unavailable: 'belum tersedia',
    }.entries) {
      testWidgets('export ${entry.key.name} shows a truthful state',
          (tester) async {
        server.startAttempt(method: 'qris', channel: 'qris');
        exporter.nextResult = entry.key;
        await pumpScreen(tester);
        await tap(tester, find.byKey(const Key('pay-qr-save')));
        await tester.pump();
        await tester.pump();
        expect(find.textContaining(entry.value), findsWidgets);
        expect(find.textContaining('tersimpan'), findsNothing);
      });
    }

    testWidgets('platform without export support says so and keeps the QR',
        (tester) async {
      server.startAttempt(method: 'qris', channel: 'qris');
      exporter.isSupported = false;
      await pumpScreen(tester);
      expect(find.byKey(const Key('pay-qr-image')), findsOneWidget);
      expect(find.byKey(const Key('pay-qr-save')), findsNothing);
      expect(find.textContaining('belum tersedia di perangkat ini'),
          findsOneWidget);
    });

    testWidgets('QR load failure is shown without crashing', (tester) async {
      server.startAttempt(method: 'qris', channel: 'qris');
      server.qrStatus = 404;
      await pumpScreen(tester);
      expect(find.byKey(const Key('pay-qr-image')), findsNothing);
      expect(find.textContaining('QR pembayaran belum dapat dimuat'),
          findsOneWidget);
      expect(find.byKey(const Key('pay-qr-retry')), findsOneWidget);
    });
  });

  group('countdown', () {
    testWidgets(
        'uses last_attempt.expires_at, survives reopen and zero only asks the gate',
        (tester) async {
      server.startAttempt();
      server.attemptExpiresAt = now.add(const Duration(minutes: 25));
      await pumpScreen(tester);
      expect(find.text('00:25:00'), findsOneWidget);
      expect(find.text('02:00:00'), findsNothing);
      await elapse(tester, 60);
      expect(find.text('00:24:00'), findsOneWidget);
      await unmount(tester);
      await pumpScreen(tester);
      expect(find.text('00:24:00'), findsOneWidget);

      await unmount(tester);
      server.attemptExpiresAt = now.add(const Duration(seconds: 5));
      await pumpScreen(tester);
      expect(find.text('00:00:05'), findsOneWidget);
      server.refreshAt.clear();
      await elapse(tester, 6);
      expect(find.textContaining('Waktu habis'), findsOneWidget);
      // The server still says pending: nothing is marked expired locally and no create happened.
      expect(find.textContaining('Kedaluwarsa'), findsNothing);
      expect(server.createPosts, 0);
    });
  });

  group('polling contract v3', () {
    testWidgets(
        'keeps polling past three minutes with >=10s gaps, backoff to 60s and a single in-flight request',
        (tester) async {
      server.startAttempt();
      server.attemptExpiresAt = now.add(const Duration(minutes: 30));
      await pumpScreen(tester);
      await elapse(tester, 240);
      expect(server.refreshAt.length, greaterThanOrEqualTo(5));
      final gaps = [
        for (var i = 1; i < server.refreshAt.length; i++)
          server.refreshAt[i].difference(server.refreshAt[i - 1])
      ];
      expect(gaps.every((g) => g >= const Duration(seconds: 10)), isTrue);
      expect(gaps.every((g) => g <= const Duration(seconds: 62)), isTrue);
      expect(gaps.last, greaterThan(gaps.first));
      expect(server.refreshAt.last.difference(server.refreshAt.first),
          greaterThan(const Duration(minutes: 3)));
      expect(server.maxInFlight, 1);
      expect(server.createPosts, 0);
    });

    testWidgets('a manual check inside the cooldown is coalesced, not sent',
        (tester) async {
      server.startAttempt();
      await pumpScreen(tester);
      final check = find.byKey(const Key('pay-check'));
      expect(enabled(tester, check), isFalse);
      await tap(tester, check);
      await tester.pump();
      expect(server.refreshPosts, 0);
      await elapse(tester, 11);
      expect(server.refreshPosts, 1);
      expect(enabled(tester, check), isFalse);
      await elapse(tester, 12);
      expect(enabled(tester, check), isTrue);
      await tap(tester, check, times: 2);
      await tester.pump();
      expect(server.refreshPosts, 2);
      expect(server.createPosts, 0);
    });

    testWidgets('429 honours Retry-After', (tester) async {
      server.startAttempt();
      server.refreshFailure = 429;
      server.retryAfter = '45';
      await pumpScreen(tester);
      await elapse(tester, 12);
      expect(server.refreshPosts, 1);
      expect(find.textContaining('Terlalu banyak permintaan'), findsWidgets);
      server.refreshFailure = null;
      await elapse(tester, 40);
      expect(server.refreshPosts, 1);
      await elapse(tester, 12);
      expect(server.refreshPosts, 2);
      final gap = server.refreshAt[1].difference(server.refreshAt[0]);
      expect(gap, greaterThanOrEqualTo(const Duration(seconds: 45)));
    });

    testWidgets('offline pauses provider refresh and recovers by probing',
        (tester) async {
      server.startAttempt();
      await pumpScreen(tester);
      server.offline = true;
      await elapse(tester, 12);
      expect(find.textContaining('Tidak ada koneksi'), findsWidgets);
      final posts = server.refreshPosts;
      await elapse(tester, 150);
      // Only the first failed refresh detects the outage; afterwards just cheap read-only probes.
      expect(server.offlineRefreshAttempts, 1);
      expect(server.allRequests.length, lessThan(40));
      server.offline = false;
      await elapse(tester, 130);
      expect(find.textContaining('Tidak ada koneksi'), findsNothing);
      expect(server.refreshPosts, greaterThan(posts));
    });

    testWidgets('route cover and background pause; resume reads once',
        (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      server.startAttempt();
      await pumpScreen(tester, navigatorKey: navigator);
      await elapse(tester, 12);
      final before = server.totalRequests;
      navigator.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('cover'))));
      await tester.pump(const Duration(milliseconds: 400));
      final covered = server.totalRequests;
      await elapse(tester, 120);
      expect(server.totalRequests, covered);
      expect(covered, greaterThanOrEqualTo(before));
      navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(server.totalRequests, greaterThan(covered));

      final afterReturn = server.totalRequests;
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await elapse(tester, 120);
      expect(server.totalRequests, afterReturn);
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(server.intentGets, greaterThan(1));
      expect(server.totalRequests, greaterThan(afterReturn));
    });

    testWidgets('dispose and session change stop everything', (tester) async {
      server.startAttempt();
      await pumpScreen(tester);
      await unmount(tester);
      final stopped = server.totalRequests;
      await elapse(tester, 120);
      expect(server.totalRequests, stopped);

      await pumpScreen(tester);
      await elapse(tester, 12);
      session.sessionChanges.value++;
      await tester.pump();
      final ended = server.totalRequests;
      await elapse(tester, 120);
      expect(server.totalRequests, ended);
    });

    testWidgets('needs_review is watched read-only, never by provider refresh',
        (tester) async {
      server.startAttempt();
      server.intentStatus = 'needs_review';
      await pumpScreen(tester);
      await elapse(tester, 90);
      expect(server.refreshPosts, 0);
      expect(server.intentGets, greaterThan(1));
      expect(find.byKey(const Key('pay-inline-state')), findsOneWidget);
    });
  });

  group('status and navigation contract', () {
    final scenarios = <String, void Function(FakeV3Server)>{
      'failed': (s) {
        s.startAttempt(status: 'failed');
        s.intentStatus = 'requires_payment';
        s.canCreate = false;
      },
      'expired': (s) {
        s.startAttempt(status: 'expired');
        s.intentStatus = 'requires_payment';
        s.canCreate = false;
      },
      'unknown': (s) => s.startAttempt(status: 'unknown'),
      'needs_review': (s) {
        s.startAttempt();
        s.intentStatus = 'needs_review';
      },
      'local timer zero with redirect hint': (s) {
        s.startAttempt();
        s.attemptExpiresAt = s.clock().subtract(const Duration(seconds: 5));
      },
    };
    for (final scenario in scenarios.entries) {
      testWidgets('${scenario.key} stays inline and never shows success',
          (tester) async {
        scenario.value(server);
        await pumpScreen(tester);
        await elapse(tester, 25);
        expect(find.byKey(const Key('pay-success')), findsNothing);
        expect(find.byKey(const Key('pay-inline-state')), findsOneWidget);
        expect(find.byType(BookingPaymentScreen), findsOneWidget);
        expect(start(), findsNothing);
        expect(find.byKey(const Key('pay-retry')), findsNothing);
        expect(server.createPosts, 0);
      });
    }

    testWidgets('create 200 and a QR on screen never count as paid',
        (tester) async {
      server.createResponseStatus = 'paid';
      var changes = 0;
      void listener() => changes++;
      BookingEvents.changed.addListener(listener);
      addTearDown(() => BookingEvents.changed.removeListener(listener));
      await pumpScreen(tester);
      await tap(tester, choice('qris', 'qris'));
      await tester.pump();
      await tap(tester, start());
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('pay-qr-image')), findsOneWidget);
      expect(find.byKey(const Key('pay-success')), findsNothing);
      await elapse(tester, 30);
      expect(find.byKey(const Key('pay-success')), findsNothing);
    });

    testWidgets('retry needs an explicit CTA and a fresh can_create; double tap is safe',
        (tester) async {
      server.startAttempt(status: 'failed');
      server.intentStatus = 'requires_payment';
      server.canCreate = true;
      await pumpScreen(tester);
      expect(start(), findsNothing);
      await tap(tester, find.byKey(const Key('pay-retry')));
      await tester.pump();
      expect(server.createPosts, 0);
      await tap(tester, choice('virtual_account', 'bni'));
      await tester.pump();
      await tap(tester, start(), times: 2);
      await tester.pump();
      await tester.pump();
      expect(server.createPosts, 1);
    });

    testWidgets('retry is not offered once the server says can_create=false',
        (tester) async {
      server.startAttempt(status: 'expired');
      server.intentStatus = 'requires_payment';
      server.canCreate = false;
      await pumpScreen(tester);
      expect(find.byKey(const Key('pay-retry')), findsNothing);
      expect(find.textContaining('Kedaluwarsa'), findsWidgets);
    });

    for (final broken in <String, void Function(FakeV3Server)>{
      'booking not confirmed': (s) => s.bookingStatus = 'awaiting_payment',
      'booking payment not paid': (s) => s.bookingPaymentStatus = 'unverified',
      'intent not paid': (s) => s.intentStatus = 'processing',
      'applied attempt differs': (s) => s.appliedAttemptGuid = 'other',
      'applied attempt missing': (s) => s.appliedAttemptGuid = null,
    }.entries) {
      testWidgets('paid facts disagree (${broken.key}): no success',
          (tester) async {
        server.startAttempt();
        server.settlePaid();
        broken.value(server);
        await pumpScreen(tester);
        expect(find.byKey(const Key('pay-success')), findsNothing);
        expect(find.byKey(const Key('pay-inline-state')), findsOneWidget);
      });
    }

    testWidgets(
        'verified paid opens success once with authoritative invoice, method, time and total',
        (tester) async {
      var changes = 0;
      void listener() => changes++;
      BookingEvents.changed.addListener(listener);
      addTearDown(() => BookingEvents.changed.removeListener(listener));
      server.startAttempt();
      server.onRefresh = () => server.settlePaid();
      await pumpScreen(tester);
      expect(find.byKey(const Key('pay-success')), findsNothing);
      await elapse(tester, 12);
      expect(find.byKey(const Key('pay-success')), findsOneWidget);
      expect(find.text('INV-2026-0001'), findsWidgets);
      expect(find.textContaining('BNI Virtual Account'), findsWidgets);
      expect(find.text('Rp20.000'), findsWidgets);
      expect(find.textContaining('WIB'), findsWidgets);
      expect(changes, 1);
      await elapse(tester, 30);
      expect(changes, 1);
      // Polling stops after the verified terminal state.
      final stopped = server.refreshPosts;
      await elapse(tester, 90);
      expect(server.refreshPosts, stopped);
    });

    testWidgets('receipt downloads through the authenticated document flow',
        (tester) async {
      server.startAttempt();
      server.settlePaid();
      await pumpScreen(tester);
      await tester.ensureVisible(find.byKey(const Key('pay-receipt')));
      await tap(tester, find.byKey(const Key('pay-receipt')));
      await tester.pump();
      await tester.pump();
      expect(server.receiptGets, 1);
      expect(documents, ['receipt']);
    });

    testWidgets('receipt stays disabled while the server says unavailable',
        (tester) async {
      server.startAttempt();
      server.settlePaid();
      server.receiptAvailable = false;
      await pumpScreen(tester);
      await tester.ensureVisible(find.byKey(const Key('pay-receipt')));
      expect(enabled(tester, find.byKey(const Key('pay-receipt'))), isFalse);
    });

    testWidgets('H-6 shows a scheduled ticket date and no QR', (tester) async {
      server.startAttempt();
      server.settlePaid();
      server.ticketState = 'scheduled';
      await pumpScreen(tester);
      await tester.pump();
      expect(find.textContaining('10 November 2026'), findsWidgets);
      expect(find.textContaining('mulai'), findsWidgets);
      expect(find.byKey(const Key('pay-qr-image')), findsNothing);
    });

    testWidgets('H-4 shows pending issuance, then the per-visitor QR section',
        (tester) async {
      server.startAttempt();
      server.settlePaid();
      server.ticketState = 'available';
      server.ticketQrAvailable = false;
      await pumpScreen(tester);
      await tester.pump();
      expect(find.textContaining('sedang diterbitkan'), findsWidgets);
      server.ticketQrAvailable = true;
      await tester.ensureVisible(find.byKey(const Key('pay-ticket-refresh')));
      await tap(tester, find.byKey(const Key('pay-ticket-refresh')));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('sedang diterbitkan'), findsNothing);
      expect(find.byKey(const Key('pay-view-ticket')), findsOneWidget);
      // The entry QR is the existing per-visitor section, separate from the payment QR.
      await tap(tester, find.byKey(const Key('pay-view-ticket')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.byType(BookingTicketQrSection), findsOneWidget);
      expect(server.ticketQrGets, 1);
      expect(find.byKey(const Key('pay-qr-image')), findsNothing);
    });

    testWidgets('payment adjustment after paid replaces success', (tester) async {
      server.startAttempt();
      server.settlePaid();
      await pumpScreen(tester);
      expect(find.byKey(const Key('pay-success')), findsOneWidget);
      server.attemptStatus = 'reversed';
      server.intentStatus = 'needs_review';
      server.bookingPaymentStatus = 'reversed';
      final element = tester.element(find.byType(BookingPaymentScreen));
      expect(element, isNotNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('pay-success')), findsNothing);
      expect(find.byKey(const Key('pay-inline-state')), findsOneWidget);
    });
  });

  group('layout', () {
    final sizes = {
      '320': const Size(320, 640),
      '393': const Size(393, 852),
      '430': const Size(430, 932),
    };
    final setups = <String, void Function(FakeV3Server)>{
      'choose': (s) {},
      'unavailable': (s) {
        s.bniAvailable = false;
        s.bniReason = 'provider_expiry_window_unverified';
        s.qrisAvailable = false;
        s.qrisReason = 'channel_contract_unverified';
        s.canPay = false;
        s.canCreate = false;
      },
      'va': (s) {
        s.vaNumber = '82770123456789012345';
        s.startAttempt();
      },
      'qris': (s) => s.startAttempt(method: 'qris', channel: 'qris'),
      'failed': (s) {
        s.startAttempt(status: 'failed');
        s.canCreate = true;
      },
      'paid': (s) {
        s.startAttempt();
        s.settlePaid();
        s.ticketState = 'available';
      },
    };
    for (final size in sizes.entries) {
      for (final scale in [1.0, 2.0]) {
        for (final setup in setups.entries) {
          testWidgets(
              '${setup.key} fits ${size.key}px at text scale ${scale}x',
              (tester) async {
            setup.value(server);
            await pumpScreen(tester, size: size.value, textScale: scale);
            await tester.pump();
            expect(tester.takeException(), isNull);
            await unmount(tester);
          });
        }
      }
    }
  });

  group('platform export', () {
    const channel = MethodChannel('id.wisatadaerahku.app/payment_qr');
    final calls = <MethodCall>[];

    Future<void> mock(Future<Object?> Function(MethodCall call) handler) async {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) {
        calls.add(call);
        return handler(call);
      });
    }

    tearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    test('save and share go through the dedicated channel with PNG metadata',
        () async {
      await mock((call) async => call.method == 'saveImage' ? 'saved' : 'shared');
      final exporter = PlatformPaymentQrExporter(forceAndroid: true);
      expect(exporter.supported, isTrue);
      expect(await exporter.save(_pngSignature, fileName: 'qris-BK-0001.png'),
          PaymentQrExportResult.saved);
      expect(await exporter.share(_pngSignature, fileName: 'qris-BK-0001.png'),
          PaymentQrExportResult.shared);
      expect(calls.map((c) => c.method), ['saveImage', 'shareImage']);
      final args = calls.first.arguments as Map;
      expect(args['mimeType'], 'image/png');
      expect(args['fileName'], 'qris-BK-0001.png');
      expect(args['bytes'], _pngSignature);
    });

    test('platform errors map to truthful results', () async {
      final exporter = PlatformPaymentQrExporter(forceAndroid: true);
      await mock((call) async => 'cancelled');
      expect(await exporter.save(_pngSignature, fileName: 'a.png'),
          PaymentQrExportResult.cancelled);
      await mock((call) async => throw PlatformException(code: 'PERMISSION_DENIED'));
      expect(await exporter.save(_pngSignature, fileName: 'a.png'),
          PaymentQrExportResult.denied);
      await mock((call) async => throw PlatformException(code: 'CANCELLED'));
      expect(await exporter.share(_pngSignature, fileName: 'a.png'),
          PaymentQrExportResult.cancelled);
      await mock((call) async => throw PlatformException(code: 'IO_ERROR'));
      expect(await exporter.share(_pngSignature, fileName: 'a.png'),
          PaymentQrExportResult.failed);
      await mock((call) async => throw MissingPluginException());
      expect(await exporter.save(_pngSignature, fileName: 'a.png'),
          PaymentQrExportResult.unavailable);
      await mock((call) async => throw PlatformException(code: 'UNAVAILABLE'));
      expect(await exporter.share(_pngSignature, fileName: 'a.png'),
          PaymentQrExportResult.unavailable);
    });

    test('non-Android targets are reported as unavailable', () async {
      await mock((call) async => 'saved');
      final exporter = PlatformPaymentQrExporter(forceAndroid: false);
      expect(exporter.supported, isFalse);
      expect(await exporter.save(_pngSignature, fileName: 'a.png'),
          PaymentQrExportResult.unavailable);
      expect(calls, isEmpty);
    });

    test('file names are sanitised', () {
      expect(paymentQrFileName('BK/0001 ../x'), 'qris-BK_0001_.._x.png');
      expect(paymentQrFileName(''), 'qris-pembayaran.png');
    });

    testWidgets('SVG from the server rasterises to a PNG', (tester) async {
      final png = await tester.runAsync(
          () => rasterizePaymentQr(Uint8List.fromList(utf8.encode(_svg)), size: 64));
      expect(png!.sublist(0, 8), _pngSignature.sublist(0, 8));
    });
  });

  group('verification pending', () {
    const message =
        'Pembayaran Anda sedang diverifikasi. Jangan bayar ulang. Kami akan memperbarui status setelah ada konfirmasi dari penyedia pembayaran.';

    /// 30 minutes passed and the provider has not told us the outcome.
    void pendingVerification(FakeV3Server s,
        {String status = 'pending', bool escalated = false}) {
      s.startAttempt(status: status);
      s.attemptExpiresAt = s.clock().subtract(const Duration(minutes: 2));
      s.verificationPending = true;
      s.escalated = escalated;
      s.canCreate = true;
    }

    test('the snapshot reads both booleans and defaults to false', () {
      expect(PaymentSnapshot(server.intent()).verificationPending, isFalse);
      pendingVerification(server, escalated: true);
      final snapshot = PaymentSnapshot(server.intent());
      expect(snapshot.verificationPending, isTrue);
      expect(snapshot.escalated, isTrue);
      final bare = PaymentSnapshot({
        'booking_guid': 'booking-1',
        'amount': 20000,
        'currency': 'IDR',
        'last_attempt': {'attempt_guid': 'a', 'status': 'pending'},
      });
      expect(bare.verificationPending, isFalse);
      expect(bare.escalated, isFalse);
    });

    for (final status in ['pending', 'unknown', 'expired', 'failed']) {
      testWidgets('state: $status + verification_pending is verifying, never retryable',
          (tester) async {
        pendingVerification(server, status: status);
        final state = BookingPaymentState(repository, 'booking-1',
            now: () => now, jitter: () => 0.5);
        await state.open();
        expect(state.phase, PaymentPhase.verifying, reason: status);
        expect(state.canRetry, isFalse);
        expect(state.chooserVisible, isFalse);
        expect(state.verificationPending, isTrue);
        final choice = state.snapshot!.payChoices.first;
        expect(state.canStartWith(choice), isFalse);
        await state.start(choice);
        expect(server.createPosts, 0);
        state.dispose();
      });
    }

    testWidgets('state: success still needs the server-verified paid facts',
        (tester) async {
      pendingVerification(server);
      final state = BookingPaymentState(repository, 'booking-1',
          now: () => now, jitter: () => 0.5);
      await state.open();
      expect(state.confirmed, isFalse);
      // A paid attempt without the booking agreeing is not success, flag or not.
      server.attemptStatus = 'paid';
      await state.reload();
      expect(state.phase, PaymentPhase.verifying);
      expect(state.confirmed, isFalse);
      server.settlePaid();
      await state.reload();
      expect(state.phase, PaymentPhase.paid);
      expect(state.verificationPending, isFalse);
      state.dispose();
    });

    testWidgets(
        'screen: truthful message, no expiry, no retry, no new payment, polling continues',
        (tester) async {
      pendingVerification(server);
      await pumpScreen(tester);
      expect(find.text(message), findsOneWidget);
      expect(find.byKey(const Key('pay-inline-state')), findsOneWidget);
      expect(find.byKey(const Key('pay-va-number')), findsNothing);
      expect(find.byKey(const Key('pay-countdown')), findsNothing);
      expect(find.textContaining('Waktu habis'), findsNothing);
      expect(find.textContaining('Kedaluwarsa'), findsNothing);
      expect(find.textContaining('Gagal'), findsNothing);
      expect(find.byKey(const Key('pay-retry')), findsNothing);
      expect(start(), findsNothing);
      expect(choice('qris', 'qris'), findsNothing);
      expect(find.byKey(const Key('pay-success')), findsNothing);
      final before = server.refreshPosts + server.intentGets;
      await elapse(tester, 25);
      expect(server.refreshPosts + server.intentGets, greaterThan(before));
      expect(server.createPosts, 0);
      await unmount(tester);
    });

    testWidgets(
        'screen: an expired-status attempt with verification pending is not shown as expired',
        (tester) async {
      pendingVerification(server, status: 'expired');
      await pumpScreen(tester);
      expect(find.text(message), findsOneWidget);
      expect(find.text('Pembayaran Kedaluwarsa'), findsNothing);
      expect(find.byKey(const Key('pay-retry')), findsNothing);
      await unmount(tester);
    });

    testWidgets('screen: escalated keeps the same truthful message and no retry',
        (tester) async {
      pendingVerification(server, escalated: true);
      await pumpScreen(tester);
      expect(find.text(message), findsOneWidget);
      expect(find.byKey(const Key('pay-retry')), findsNothing);
      expect(start(), findsNothing);
      await unmount(tester);
    });

    testWidgets(
        'screen: the provider confirming later opens success from verified facts only',
        (tester) async {
      pendingVerification(server);
      server.onRefresh = () => server.settlePaid();
      await pumpScreen(tester);
      expect(find.byKey(const Key('pay-success')), findsNothing);
      await elapse(tester, 12);
      expect(find.byKey(const Key('pay-success')), findsOneWidget);
      expect(find.text(message), findsNothing);
    });

    testWidgets('screen: fits 320 wide at 2.0x text scale', (tester) async {
      pendingVerification(server, escalated: true);
      await pumpScreen(tester, size: const Size(320, 640), textScale: 2);
      await tester.pump();
      expect(find.byKey(const Key('pay-inline-state')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('booking section: the entry says status, never "pay again"',
        (tester) async {
      pendingVerification(server);
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: BookingPaymentSection(
                      booking: Booking(bookingJson(
                          guid: 'booking-1', status: 'awaiting_payment')),
                      repository: repository,
                      onReturned: () async {})))));
      await tester.pump();
      await tester.pump();
      expect(find.text('Lihat Status Pembayaran'), findsOneWidget);
      expect(find.text('Pilih Metode Pembayaran'), findsNothing);
      expect(find.text('Lanjutkan Pembayaran'), findsNothing);
    });
  });

  group('entry from the booking payment section', () {
    Future<void> pumpSection(WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: BookingPaymentSection(
                      booking: Booking(bookingJson(
                          guid: 'booking-1', status: 'awaiting_payment')),
                      repository: repository,
                      onReturned: () async {})))));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('offers the checkout without creating anything', (tester) async {
      await pumpSection(tester);
      final open = find.byKey(const Key('payment-open-checkout'));
      expect(open, findsOneWidget);
      expect(find.text('Pilih Metode Pembayaran'), findsOneWidget);
      expect(server.createPosts, 0);
      await tap(tester, open);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(BookingPaymentScreen), findsOneWidget);
      expect(server.createPosts, 0);
    });

    testWidgets('reopens the same attempt', (tester) async {
      server.startAttempt();
      await pumpSection(tester);
      expect(find.text('Lanjutkan Pembayaran'), findsOneWidget);
    });

    testWidgets('fail-closed channels show the reason and no checkout CTA',
        (tester) async {
      server.bniAvailable = false;
      server.bniReason = 'provider_expiry_window_unverified';
      server.qrisAvailable = false;
      server.qrisReason = 'channel_contract_unverified';
      server.canPay = false;
      server.canCreate = false;
      server.ewalletAvailable = false;
      await pumpSection(tester);
      expect(find.byKey(const Key('payment-open-checkout')), findsNothing);
      expect(find.textContaining('batas waktu pembayaran'), findsWidgets);
    });
  });

  group('BookingPaymentState', () {
    testWidgets('concurrent start() calls create once even without the UI gate',
        (tester) async {
      final state = BookingPaymentState(repository, 'booking-1',
          now: () => now, jitter: () => 0.5);
      await state.open();
      final choice = state.snapshot!.payChoices
          .firstWhere((c) => c.key == 'virtual_account/bni');
      final first = state.start(choice);
      final second = state.start(choice);
      await Future.wait([first, second]);
      expect(server.createPosts, 1);
      expect(state.phase, PaymentPhase.awaiting);
      state.dispose();
    });

    testWidgets('only the verified-paid predicate unlocks success',
        (tester) async {
      final state = BookingPaymentState(repository, 'booking-1',
          now: () => now, jitter: () => 0.5);
      server.startAttempt();
      server.settlePaid();
      await state.open();
      expect(state.confirmed, isTrue);
      expect(state.phase, PaymentPhase.paid);
      server.appliedAttemptGuid = 'other';
      await state.reload();
      expect(state.confirmed, isFalse);
      state.dispose();
    });
  });
}
