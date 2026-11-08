import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/data/ewallet_payment_state.dart';
import 'package:wisata_daerahku/data/payment_return_link.dart';
import 'package:wisata_daerahku/screens/payment_return_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'package:wisata_daerahku/widgets/ewallet_payment_section.dart';

import 'user_support.dart';

const _wallet = 'https://pay.wallet-fixture.example.com/checkout?token=abc';
const _pointerKey = 'ewallet_pointer_user-1';

/// Scripted Laravel payment API. Mirrors the documented contract; counts every mutating call.
class FakeWalletServer {
  String bookingStatus = 'awaiting_payment';
  String bookingPaymentStatus = 'unverified';
  String intentStatus = 'processing';
  String? attemptStatus = 'pending';
  String attemptGuid = 'att-1';
  int createPosts = 0;
  int refreshPosts = 0;
  int intentGets = 0;
  final createKeys = <String>[];

  /// Applied at the start of a refresh POST; lets a test make the provider "settle".
  void Function()? onRefresh;
  int? refreshFailure;
  int? readFailure;
  int? createFailure;
  void Function()? afterCreate;
  Completer<void>? refreshBarrier;

  /// The POST created an attempt server-side, but the response is lost (500).
  bool createCommitsThenFails = false;

  Map<String, dynamic> intent() => {
        'booking_guid': 'booking-1',
        'intent_guid': 'intent-1',
        'status': attemptStatus == null ? 'not_created' : intentStatus,
        'amount': 20000,
        'currency': 'IDR',
        'provider': 'doku',
        'environment': 'sandbox',
        'test_only': true,
        'can_pay': bookingStatus == 'awaiting_payment',
        'booking_status': bookingStatus,
        'payment_status': bookingPaymentStatus,
        'reason': null,
        'methods': _methods(),
        'last_attempt': attemptStatus == null
            ? null
            : {
                'attempt_guid': attemptGuid,
                'status': attemptStatus,
                'method': 'ewallet',
                'channel': 'dana',
                'started_at': '2026-11-08T08:00:00+00:00',
                'finished_at': null,
                'expires_at': '2026-11-08T09:00:00+00:00',
              },
        'instruction': attemptStatus == 'pending'
            ? {
                'presentation_type': 'ewallet_redirect',
                'redirect_url': _wallet,
                'requires_external_authorization': true
              }
            : {'presentation_type': 'unavailable'},
      };

  List<Map<String, dynamic>> _methods() => [
        {
          'code': 'ewallet',
          'available': true,
          'presentation_type': 'ewallet_redirect',
          'reason': null,
          'channels': [
            {'channel': 'dana', 'available': true, 'reason': null},
            {'channel': 'shopeepay', 'available': true, 'reason': null},
          ]
        }
      ];

  void settlePaid() {
    attemptStatus = 'paid';
    intentStatus = 'paid';
    bookingStatus = 'confirmed';
    bookingPaymentStatus = 'paid';
  }

  http.Response _ok(Object data) => jsonResponse({'data': data});

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'POST' && path.endsWith('/refresh')) {
      refreshPosts++;
      await refreshBarrier?.future;
      if (refreshFailure != null) {
        return jsonResponse({'message': 'x'}, refreshFailure!);
      }
      onRefresh?.call();
      return _ok(intent());
    }
    if (request.method == 'POST' && path.endsWith('/payment-attempts')) {
      createPosts++;
      createKeys.add(request.headers['Idempotency-Key'] ?? '');
      if (createFailure != null) {
        return jsonResponse({'message': 'x'}, createFailure!);
      }
      attemptStatus = 'pending';
      attemptGuid = 'att-$createPosts';
      if (createCommitsThenFails) return jsonResponse({'message': 'x'}, 500);
      final response = _ok({
        'booking_guid': 'booking-1',
        'intent_guid': 'intent-1',
        'attempt_guid': attemptGuid,
        'provider': 'doku',
        'environment': 'sandbox',
        'test_only': true,
        'status': 'pending',
        'method_code': 'ewallet',
        'channel': (jsonDecode(request.body) as Map)['channel'],
        'amount': 20000,
        'currency': 'IDR',
        'instruction': {
          'presentation_type': 'ewallet_redirect',
          'redirect_url': _wallet,
          'requires_external_authorization': true
        },
      });
      afterCreate?.call();
      return response;
    }
    if (readFailure != null) {
      return jsonResponse({'message': 'x'}, readFailure!);
    }
    if (path.endsWith('/payment-intent')) {
      intentGets++;
      return _ok(intent());
    }
    if (path.endsWith('/payments/methods')) return _ok(intent());
    if (path.endsWith('/bookings/booking-1')) {
      return _ok({
        ...bookingJson(guid: 'booking-1', status: bookingStatus),
        'payment_status': bookingPaymentStatus
      });
    }
    return jsonResponse({'message': 'not found'}, 404);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeWalletServer server;
  late AuthSession session;
  late BusinessRepository repository;
  final launched = <Uri>[];

  Future<bool> launcher(Uri url) async {
    launched.add(url);
    return true;
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    launched.clear();
    server = FakeWalletServer();
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

  Future<void> savePointer({String attempt = 'att-1'}) =>
      const FlutterSecureStorage().write(
          key: _pointerKey,
          value: EwalletPointer('booking-1', attempt, 'dana').encode());

  Future<String?> storedPointer() =>
      const FlutterSecureStorage().read(key: _pointerKey);

  Future<void> pumpReturn(WidgetTester tester, PaymentReturnHint hint,
      {BusinessRepository? repo,
      Duration pollInterval = const Duration(hours: 1)}) async {
    await tester.pumpWidget(MaterialApp(
        home: PaymentReturnScreen(
            hint: hint,
            repository: repo ?? repository,
            launcher: launcher,
            pollInterval: pollInterval)));
    await tester.pumpAndSettle();
  }

  /// Dispose the screen so its polling timer is cancelled before the test ends.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  group('PaymentReturnLink', () {
    test('accepts only /payment/return and reads the untrusted hint', () {
      expect(PaymentReturnLink.parse('/payment/return')!.hint,
          PaymentReturnHint.none);
      expect(PaymentReturnLink.parse('/payment/return?result=success')!.hint,
          PaymentReturnHint.success);
      expect(PaymentReturnLink.parse('/payment/return?result=CANCEL')!.hint,
          PaymentReturnHint.cancel);
      expect(PaymentReturnLink.parse('/payment/return/?result=error')!.hint,
          PaymentReturnHint.error);
      expect(PaymentReturnLink.parse('/payment/return?result=weird')!.hint,
          PaymentReturnHint.unknown);
      expect(PaymentReturnLink.parse('/payment/return?result=')!.hint,
          PaymentReturnHint.unknown);
    });

    test('rejects every other route', () {
      for (final name in [
        null,
        '',
        '/',
        '/payment',
        '/payment/return/extra',
        '/payments/return',
        '/other/payment/return',
        '/payment/returned',
      ]) {
        expect(PaymentReturnLink.parse(name), isNull, reason: '$name');
      }
    });
  });

  group('return screen', () {
    testWidgets('pauses inquiries in the background and refreshes on return',
        (tester) async {
      await savePointer();
      await pumpReturn(tester, PaymentReturnHint.none,
          pollInterval: const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      final backgroundPosts = server.refreshPosts;

      server.onRefresh = server.settlePaid;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      final confirmed =
          find.byKey(const Key('return-confirmed')).evaluate().length;
      await unmount(tester);

      expect(backgroundPosts, 1);
      expect(confirmed, 1);
      expect(server.createPosts, 0);
    });

    testWidgets('success hint with a pending server is NOT paid',
        (tester) async {
      await savePointer();
      await pumpReturn(tester, PaymentReturnHint.success);

      expect(server.refreshPosts, 1);
      expect(find.byKey(const Key('return-pending')), findsOneWidget);
      expect(find.byKey(const Key('return-confirmed')), findsNothing);
      expect(find.text('Pembayaran Terkonfirmasi'), findsNothing);
      expect(find.byKey(const Key('return-hint-note')), findsOneWidget);
      expect(server.createPosts, 0);
      expect(await storedPointer(), isNotNull); // still waiting
      await unmount(tester);
    });

    testWidgets(
        'confirms only when the server says paid and clears the pointer',
        (tester) async {
      await savePointer();
      server.onRefresh = server.settlePaid;
      await pumpReturn(tester, PaymentReturnHint.none);

      expect(find.byKey(const Key('return-confirmed')), findsOneWidget);
      expect(find.text('Pembayaran Terkonfirmasi'), findsOneWidget);
      expect(await storedPointer(), isNull);
      await unmount(tester);
    });

    testWidgets(
        'an attempt marked paid while the booking is not confirmed is not confirmed',
        (tester) async {
      await savePointer();
      server.onRefresh = () {
        server.attemptStatus = 'paid';
        server.intentStatus = 'paid';
      };
      await pumpReturn(tester, PaymentReturnHint.success);

      expect(find.byKey(const Key('return-confirmed')), findsNothing);
      expect(find.byKey(const Key('return-pending')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('cancel hint still refreshes and says the payment is not done',
        (tester) async {
      await savePointer();
      await pumpReturn(tester, PaymentReturnHint.cancel);

      expect(server.refreshPosts, 1);
      expect(find.textContaining('membatalkan'), findsOneWidget);
      expect(find.byKey(const Key('return-pending')), findsOneWidget);
      expect(find.byKey(const Key('return-confirmed')), findsNothing);
      await unmount(tester);
    });

    testWidgets('cancel hint cannot override a server-verified payment',
        (tester) async {
      await savePointer();
      server.onRefresh = server.settlePaid;
      await pumpReturn(tester, PaymentReturnHint.cancel);

      expect(find.byKey(const Key('return-confirmed')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a failed provider result shows a retryable not-paid state',
        (tester) async {
      await savePointer();
      server.onRefresh = () {
        server.attemptStatus = 'failed';
        server.intentStatus = 'requires_payment';
      };
      await pumpReturn(tester, PaymentReturnHint.error);

      expect(find.byKey(const Key('return-failed')), findsOneWidget);
      expect(find.text('Pembayaran Tidak Berhasil'), findsOneWidget);
      expect(await storedPointer(), isNull);
      expect(server.createPosts, 0);
      await unmount(tester);
    });

    testWidgets(
        'server errors keep the pointer, never re-create and allow retry',
        (tester) async {
      await savePointer();
      server.refreshFailure = 500;
      server.readFailure = 500;
      await pumpReturn(tester, PaymentReturnHint.none);

      expect(find.byKey(const Key('return-unreachable')), findsOneWidget);
      expect(find.byKey(const Key('return-confirmed')), findsNothing);
      expect(server.createPosts, 0);
      expect(await storedPointer(), isNotNull);

      server.refreshFailure = null;
      server.readFailure = null;
      await tester.tap(find.byKey(const Key('return-refresh')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('return-pending')), findsOneWidget);
      expect(server.refreshPosts, 2);
      await unmount(tester);
    });

    testWidgets(
        'a refresh failure alone still shows the server state it can read',
        (tester) async {
      await savePointer();
      server.refreshFailure = 429;
      await pumpReturn(tester, PaymentReturnHint.none);

      expect(find.byKey(const Key('return-pending')), findsOneWidget);
      expect(find.byKey(const Key('return-error')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('no unfinished payment shows a friendly message',
        (tester) async {
      await pumpReturn(tester, PaymentReturnHint.success);

      expect(find.byKey(const Key('return-none')), findsOneWidget);
      expect(find.text('Tidak Ada Pembayaran yang Sedang Berjalan'),
          findsOneWidget);
      expect(server.refreshPosts, 0);
      expect(server.createPosts, 0);
      await unmount(tester);
    });

    testWidgets(
        'a signed-out visitor is asked to log in without losing the pointer',
        (tester) async {
      await savePointer();
      final signedOut = repositoryFor(AuthSession(
          baseUrl: 'https://example.test/api/v1', store: MemoryStore()));
      await pumpReturn(tester, PaymentReturnHint.none, repo: signedOut);

      expect(find.byKey(const Key('return-needs-login')), findsOneWidget);
      expect(server.refreshPosts, 0);
      expect(await storedPointer(), isNotNull);
      await unmount(tester);
    });
  });

  group('routing', () {
    Widget app({String? initialRoute}) => MaterialApp(
        initialRoute: initialRoute ?? '/',
        home: const Scaffold(body: Text('HOME')),
        onGenerateRoute: (settings) =>
            paymentReturnRoute(settings, repository: () => repository));

    testWidgets('cold start opens the return screen above home; back pops home',
        (tester) async {
      await savePointer();
      await tester
          .pumpWidget(app(initialRoute: '/payment/return?result=cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentReturnScreen), findsOneWidget);
      expect(find.textContaining('membatalkan'), findsOneWidget);
      await tester.tap(find.byKey(const Key('return-back')));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(find.byType(PaymentReturnScreen), findsNothing);
      await unmount(tester);
    });

    testWidgets('warm start (platform pushRoute) opens the return screen',
        (tester) async {
      await savePointer();
      await tester.pumpWidget(app());
      expect(find.text('HOME'), findsOneWidget);

      await tester.binding.handlePushRoute('/payment/return?result=success');
      await tester.pumpAndSettle();

      expect(find.byType(PaymentReturnScreen), findsOneWidget);
      expect(find.byKey(const Key('return-pending')), findsOneWidget);
      expect(find.byKey(const Key('return-confirmed')), findsNothing);
      await unmount(tester);
    });

    test('other routes fall through to the normal router', () {
      expect(paymentReturnRoute(const RouteSettings(name: '/payment/other')),
          isNull);
      expect(paymentReturnRoute(const RouteSettings(name: '/')), isNull);
    });
  });

  group('app resume', () {
    Future<void> resume(WidgetTester tester) async {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
    }

    Future<void> pumpSection(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: EwalletPaymentSection(
                      booking: Booking(bookingJson(
                          guid: 'booking-1', status: 'awaiting_payment')),
                      repository: repository,
                      launcher: launcher,
                      onChanged: () async {})))));
      await tester.pumpAndSettle();
    }

    testWidgets('booking inquiries pause while the wallet is in front',
        (tester) async {
      await savePointer();
      await pumpSection(tester);
      await resume(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      final backgroundPosts = server.refreshPosts;
      await unmount(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(backgroundPosts, 1);
      expect(server.createPosts, 0);
    });

    testWidgets('refreshes exactly once for a known pending attempt',
        (tester) async {
      await savePointer();
      await pumpSection(tester);
      expect(server.refreshPosts, 0); // mounting is read-only

      await resume(tester);

      expect(server.refreshPosts, 1);
      expect(server.createPosts, 0);
      expect(find.textContaining('belum berarti pembayaran berhasil'),
          findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a verified payment found on resume confirms the booking',
        (tester) async {
      await savePointer();
      await pumpSection(tester);
      server.onRefresh = server.settlePaid;

      await resume(tester);

      expect(find.textContaining('terkonfirmasi oleh server'), findsOneWidget);
      expect(await storedPointer(), isNull);
      await unmount(tester);
    });

    testWidgets('does nothing without a pointer', (tester) async {
      server.attemptStatus = null; // nothing in flight
      await pumpSection(tester);

      await resume(tester);

      expect(server.refreshPosts, 0);
      expect(server.createPosts, 0);
      expect(find.byKey(const Key('ewallet-pay-dana')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('starting a payment', () {
    EwalletPaymentState newState() =>
        EwalletPaymentState(repository, 'booking-1',
            launcher: launcher, pollInterval: const Duration(hours: 1));

    testWidgets('resume during an inquiry restarts polling after it completes',
        (tester) async {
      await savePointer();
      final state = newState();
      await state.recover();
      state.startPolling();
      server.refreshBarrier = Completer<void>();
      final refresh = state.refresh();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      server.refreshBarrier!.complete();
      await refresh;
      await tester.pumpAndSettle();
      final polling = state.polling;
      state.dispose();

      expect(polling, isTrue);
      expect(server.refreshPosts, 2);
      expect(server.createPosts, 0);
    });

    for (final status in ['paid', 'unknown', 'expired']) {
      test('does not open a stale checkout after the server reports $status',
          () async {
        server.attemptStatus = null;
        server.afterCreate = () {
          if (status == 'paid') {
            server.settlePaid();
          } else {
            server.attemptStatus = status;
          }
        };
        final state = newState();
        await state.recover();
        await state.start('dana');
        state.dispose();

        expect(server.createPosts, 1);
        expect(launched, isEmpty);
      });
    }

    test('opens the wallet once, saves the pointer and never marks paid',
        () async {
      server.attemptStatus = null;
      final state = newState();
      await state.recover();
      expect(state.canStart, isTrue);

      await state.start('dana');

      expect(server.createPosts, 1);
      expect(launched, [Uri.parse(_wallet)]);
      expect(await storedPointer(), isNotNull);
      expect(state.confirmed, isFalse);
      expect(state.phase, EwalletPhase.pending);
      state.dispose();
    });

    test('an uncertain POST is retried only with the same Idempotency-Key',
        () async {
      server.attemptStatus = null;
      server.createFailure = 503; // nothing created
      final state = newState();
      await state.recover();

      await state.start('dana');
      expect(server.createPosts, 1);
      expect(state.error, isNotNull);
      expect(launched, isEmpty);

      server.createFailure = null;
      await state.start('dana');

      expect(server.createPosts, 2);
      expect(server.createKeys.toSet(), hasLength(1));
      expect(server.createKeys.first, isNotEmpty);
      expect(launched, hasLength(1));
      state.dispose();
    });

    test(
        'a lost response that did create the attempt is recovered, not re-created',
        () async {
      server.attemptStatus = null;
      server.createCommitsThenFails = true;
      final state = newState();
      await state.recover();

      await state.start('dana');
      expect(server.createPosts, 1);
      expect(state.phase, EwalletPhase.pending); // found by the follow-up read
      expect(await storedPointer(), isNotNull);

      server.createCommitsThenFails = false;
      await state.start('dana'); // user presses again: reopen, never POST

      expect(server.createPosts, 1);
      expect(launched, hasLength(1));
      state.dispose();
    });

    test('a different wallet is refused while an uncertain attempt is stored',
        () async {
      server.attemptStatus = null;
      server.createFailure = 500;
      final state = newState();
      await state.recover();
      await state.start('dana');

      server.createFailure = null;
      await state.start('shopeepay');

      expect(server.createPosts, 1);
      expect(state.error, contains('DANA'));
      state.dispose();
    });

    test('polling is bounded and stops when the attempt becomes terminal',
        () async {
      await savePointer();
      final state = EwalletPaymentState(repository, 'booking-1',
          launcher: launcher,
          pollInterval: const Duration(milliseconds: 10),
          pollWindow: const Duration(milliseconds: 30));
      await state.recover();
      state.startPolling();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(state.polling, isFalse);
      expect(server.refreshPosts, inInclusiveRange(1, 3));
      state.dispose();
    });
  });
}
