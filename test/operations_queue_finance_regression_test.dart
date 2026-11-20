import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/screens/admin/operations_dashboard/operations_dashboard.dart';
import 'package:wisata_daerahku/screens/admin/operations_queue_screen.dart';
import 'package:wisata_daerahku/screens/admin/operations_booking_screen.dart';
import 'package:wisata_daerahku/screens/admin/operations_navigation_shell.dart';
import 'package:wisata_daerahku/screens/admin/daftar_wisata_screen.dart';
import 'package:wisata_daerahku/screens/auth/user_login_screen.dart';
import 'admin_test_support.dart';
import 'operations_test_support.dart';

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final provider in ['doku', 'midtrans', 'mixed', 'demo', 'unknown']) {
    testWidgets('finance sandbox validates historical provider $provider',
        (tester) async {
      final session = await adminSession((request) async {
        expectSync(request.url.queryParameters['environment'], isNull);
        const environment = 'sandbox';
        return jsonResponse({
          'data': {
            'financial': {
              'environment': environment,
              'provider': provider,
              'test_only': true,
              'currency': 'IDR',
              'availability': 'partial',
              'source': 'verified_sandbox_events',
              'scope': {'mode': 'global', 'destination_guid': null},
              'gross_revenue': 12345,
              'successful_transactions': 2,
            }
          }
        });
      }, role: 2);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: OperationsFinancialScreen(
                  repository: repositoryFor(session), session: session))));
      await tester.pumpAndSettle();
      expect(
          find.text('Sandbox · Data uji'),
          ['doku', 'midtrans', 'mixed'].contains(provider)
              ? findsOneWidget
              : findsNothing);
      final invalid = find.textContaining('Laporan yang diterima tidak sesuai');
      expect(
          invalid,
          ['doku', 'midtrans', 'mixed'].contains(provider)
              ? findsNothing
              : findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
      'finance reload switches to production and rejects inconsistent metadata',
      (tester) async {
    var environment = 'sandbox';
    var source = 'verified_sandbox_events';
    var testOnly = true;
    var availability = 'partial';
    Completer<void>? delayed;
    final session = await adminSession((request) async {
      expectSync(request.url.queryParameters['environment'], isNull);
      final response = jsonResponse({
        'data': {
          'financial': {
            'environment': environment,
            'provider': 'midtrans',
            'test_only': testOnly,
            'currency': 'IDR',
            'availability': availability,
            'source': source,
            'scope': {'mode': 'global', 'destination_guid': null},
            'gross_revenue': environment == 'sandbox' ? 12345 : 67890,
          }
        }
      });
      await delayed?.future;
      return response;
    }, role: 2);
    await tester.pumpWidget(MaterialApp(
        home: OperationsFinancialScreen(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Sandbox · Data uji'), findsOneWidget);
    expect(find.text('Rp12.345'), findsOneWidget);

    void refresh() {
      final observer = tester.state(find.byType(OperationsFinancialScreen))
          as WidgetsBindingObserver;
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    }

    Future<void> reload() async {
      refresh();
      await tester.pumpAndSettle();
    }

    final older = Completer<void>();
    delayed = older;
    refresh();
    await tester.pump();
    expect(find.text('Rp12.345'), findsNothing);
    delayed = null;

    environment = 'production';
    source = 'verified_production_events';
    testOnly = false;
    session.sessionChanges.value++;
    await tester.pumpAndSettle();
    expect(find.text('Produksi'), findsOneWidget);
    expect(find.text('Rp67.890'), findsOneWidget);
    expect(find.text('Rp12.345'), findsNothing);
    older.complete();
    await tester.pumpAndSettle();
    expect(find.text('Rp67.890'), findsOneWidget);
    expect(find.text('Rp12.345'), findsNothing);

    source = 'simulated_demo_events';
    await reload();
    expect(find.textContaining('Laporan yang diterima tidak sesuai'),
        findsOneWidget);
    expect(find.text('Rp67.890'), findsNothing);

    source = 'verified_production_events';
    testOnly = true;
    await reload();
    expect(find.text('Rp67.890'), findsNothing);

    testOnly = false;
    availability = 'unavailable';
    source = 'unavailable';
    await reload();
    expect(find.text('Data keuangan belum tersedia untuk periode ini.'),
        findsOneWidget);
    expect(find.text('Rp67.890'), findsNothing);
  });

  testWidgets('action center preserves server urgency order and guarded route',
      (tester) async {
    final requests = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/b1')) {
        return jsonResponse({'data': operationalBooking()});
      }
      return jsonResponse(pageEnvelope([
        {...operationalQueueRow(), 'action': 'approval_deadline_approaching'},
        {...operationalQueueRow(guid: 'b2'), 'action': 'upcoming_visit'}
      ]));
    }, role: 1, log: requests);
    await tester.pumpWidget(MaterialApp(
        home: OperationsReportScreen(
            section: 'action-center',
            repository: repositoryFor(session),
            session: session)));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Mendekati batas persetujuan')).dy,
        lessThan(tester.getTopLeft(find.text('Kunjungan mendatang')).dy));
    await _tap(tester, find.text('Mendekati batas persetujuan'));
    expect(find.byType(OperationsBookingScreen), findsOneWidget);
    expect(
        find.byKey(const ValueKey('booking-primary-action')), findsOneWidget);
    expect(requests.where((request) => request.method != 'GET'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('destination performance switches to management and quota route',
      (tester) async {
    final requests = <http.Request>[];
    final session = await adminSession(
        (_) async => jsonResponse(pageEnvelope([])),
        role: 1,
        log: requests);
    await tester.pumpWidget(MaterialApp(
        home: OperationsReportScreen(
            section: 'destinations',
            repository: repositoryFor(session),
            session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Kinerja'), findsOneWidget);
    await _tap(tester, find.text('Kelola'));
    expect(
        tester.widget<DaftarWisataScreen>(find.byType(DaftarWisataScreen)).mode,
        'manage');
    expect(requests.last.url.path, '/api/v1/admin/destinations');
    expect(requests.every((request) => request.method == 'GET'), isTrue);
  });

  testWidgets('admin profile logout clears the private shell', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await adminSession(
        (request) async => request.url.path.endsWith('/auth/logout')
            ? jsonResponse({'data': {}})
            : jsonResponse(pageEnvelope([])),
        role: 1);
    await tester.pumpWidget(MaterialApp(
        home: OperationsNavigationShell(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Admin'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Keluar akun'), 180);
    await _tap(tester, find.text('Keluar akun'));
    await _tap(tester, find.byKey(const ValueKey('operations-logout-confirm')));
    expect(session.authenticated.value, isFalse);
    expect(find.byType(UserLoginScreen), findsOneWidget);
    expect(find.text('Admin'), findsNothing);
    expect(find.byType(OperationsNavigationShell), findsNothing);
  });

  testWidgets('queue ownership filters use server claims across pages',
      (tester) async {
    final requests = <http.Request>[];
    final session = await adminSession((request) async {
      final page = int.parse(request.url.queryParameters['page']!);
      return jsonResponse(pageEnvelope([
        if (page == 1) ...[
          operationalQueueRow(guid: 'free'),
          operationalQueueRow(guid: 'mine', owner: 'admin-1'),
        ] else
          operationalQueueRow(guid: 'other', owner: 'other-admin')
      ], page: page, last: 2));
    }, role: 1, log: requests);
    await tester.pumpWidget(MaterialApp(
        home: OperationsQueueScreen(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Muat berikutnya'));
    expect(requests.map((r) => r.url.queryParameters['page']), ['1', '2']);
    expect(find.byKey(const ValueKey<String?>('other')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('queue-ownership-mine')));
    expect(find.byKey(const ValueKey<String?>('mine')), findsOneWidget);
    expect(find.byKey(const ValueKey<String?>('free')), findsNothing);
    expect(find.byKey(const ValueKey<String?>('other')), findsNothing);
    await _tap(tester, find.text('Tersedia'));
    expect(find.byKey(const ValueKey<String?>('free')), findsOneWidget);
    expect(find.byKey(const ValueKey<String?>('mine')), findsNothing);
    await _tap(tester, find.text('Semua'));
    expect(find.byKey(const ValueKey<String?>('other')), findsOneWidget);
    await session.me();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String?>('mine')), findsNothing);
    expect(find.byKey(const ValueKey<String?>('other')), findsNothing);
  });

  testWidgets('queue empty and network error recover through pull-to-refresh',
      (tester) async {
    var reads = 0;
    final session = await adminSession((request) async {
      reads++;
      return reads == 2
          ? jsonResponse({'message': 'Fixture network error'}, 500)
          : jsonResponse(pageEnvelope([]));
    }, role: 1);
    await tester.pumpWidget(MaterialApp(
        home: OperationsQueueScreen(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Antrean sudah kosong'), findsOneWidget);
    for (final expected in [2, 3]) {
      await tester.drag(find.byType(ListView).first, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(reads, expected);
      expect(find.text('Muat ulang'), findsNothing);
    }
    expect(find.text('Antrean sudah kosong'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final foreignScope in [false, true]) {
    testWidgets('finance demo disclosure rejects foreign scope=$foreignScope',
        (tester) async {
      final requests = <http.Request>[];
      final session = await adminSession(
          (request) async => jsonResponse({
                'data': {
                  'financial': {
                    'environment': 'demo',
                    'provider': 'demo',
                    'test_only': true,
                    'currency': 'IDR',
                    'source': 'simulated_demo_events',
                    'availability': 'partial',
                    'scope': {
                      'mode': foreignScope ? 'global' : 'assigned_destinations',
                      'destination_guid': null
                    },
                    'gross_revenue': 12345,
                    'successful_transactions': 2
                  }
                }
              }),
          role: 1,
          log: requests);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: OperationsFinancialScreen(
                  preview: true,
                  repository: repositoryFor(session),
                  session: session))));
      await tester.pumpAndSettle();
      expect(requests.single.method, 'GET');
      expect(requests.single.url.queryParameters['environment'], isNull);
      expect(find.text('Demo · Data simulasi'),
          foreignScope ? findsNothing : findsOneWidget);
      if (foreignScope) {
        expect(find.textContaining('Laporan yang diterima tidak sesuai'),
            findsOneWidget);
        expect(find.text('Gross tercatat'), findsNothing);
      } else {
        expect(find.text('Gross tercatat'), findsOneWidget);
        expect(find.text('Rp12.345'), findsOneWidget);
        expect(
            find.text('Sumber: Simulasi DEMO · data sebagian'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
