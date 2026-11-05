import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wisata_daerahku/screens/operations_navigation_shell.dart';
import 'package:wisata_daerahku/screens/main_navigation_screen.dart';
import 'package:wisata_daerahku/screens/session_destination.dart';
import 'package:wisata_daerahku/screens/user_login_screen.dart';
import 'package:wisata_daerahku/widgets/floating_bottom_nav.dart';
import 'admin_test_support.dart';

Map<String, dynamic> overviewFixture() => {
      'generated_at': '2026-11-05T01:00:00Z',
      'period': {'from': '2026-11-01', 'to': '2026-11-05'},
      'metrics': {
        'assigned_destinations': 1,
        'pending_approvals': 3,
        'approved_decisions': 2,
        'rejected_decisions': 1
      },
      'personal': {'approved_decisions': 2, 'rejected_decisions': 1},
      'assigned_workload': {'personal_claims': 1},
      'booking_trend': <dynamic>[],
      'financial': {'availability': 'unavailable', 'gross_revenue': null},
    };
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('logout removes private child routes above the operations shell',
      (tester) async {
    final session = await adminSession(
        (request) async => request.url.path.endsWith('/overview')
            ? jsonResponse({'data': overviewFixture()})
            : jsonResponse(pageEnvelope([])),
        role: 1);
    await tester.pumpWidget(MaterialApp(
        home: OperationsNavigationShell(
            session: session,
            repository: repositoryFor(session),
            scannerBuilder: (_) =>
                const Scaffold(body: Text('Privat scanner')))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Scan QR'));
    await tester.pumpAndSettle();
    expect(find.text('Privat scanner'), findsOneWidget);
    await session.clear();
    await tester.pumpAndSettle();
    expect(find.text('Privat scanner'), findsNothing);
    expect(find.byType(UserLoginScreen), findsOneWidget);
    expect(find.byType(FloatingBottomNav), findsNothing);
  });
  testWidgets(
      'visitor navbar defaults remain icon-only and operation centers have separate labels',
      (tester) async {
    for (final role in <int?>[null, 1, 2]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              bottomNavigationBar: FloatingBottomNav(
                  index: 0, operationsRole: role, onSelected: (_) {}))));
      final center = role == null
          ? 'Jelajah'
          : role == 1
              ? 'Scan QR'
              : 'Analitik';
      expect(find.byTooltip(center), findsOneWidget);
      expect(find.text(center), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('operations navigation fits safe area at 360dp with large text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                padding: EdgeInsets.only(bottom: 34),
                textScaler: TextScaler.linear(2)),
            child: Scaffold(
                bottomNavigationBar: FloatingBottomNav(
                    index: 2, operationsRole: 1, onSelected: (_) {})))));
    expect(
        tester.getRect(find.byType(FloatingBottomNav)).bottom -
            tester.getRect(find.byType(InkWell).last).bottom,
        greaterThanOrEqualTo(34));
    expect(tester.takeException(), isNull);
  });
  test(
      'session routing preserves visitor and directs both staff roles into shell',
      () async {
    for (final role in [0, 1, 2]) {
      final session = await adminSession(
          (_) async => jsonResponse({'data': {}}),
          role: role == 0 ? 1 : role);
      session.role = role;
      final destination = sessionDestination(session: session);
      expect(
          destination,
          role == 0
              ? isA<MainNavigationScreen>()
              : isA<OperationsNavigationShell>());
    }
  });
  testWidgets(
      'Admin center pushes full-screen scanner then returns to previous tab; back returns home',
      (tester) async {
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/overview')) {
        return jsonResponse({'data': overviewFixture()});
      }
      return jsonResponse(pageEnvelope([]));
    }, role: 1);
    await tester.pumpWidget(MaterialApp(
        home: OperationsNavigationShell(
            repository: repositoryFor(session),
            session: session,
            scannerBuilder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup scanner uji'))))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Akun operasional Wisata Daerahku'), findsOneWidget);
    await tester.tap(find.byTooltip('Scan QR'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingBottomNav), findsNothing);
    expect(find.text('Tutup scanner uji'), findsOneWidget);
    await tester.tap(find.text('Tutup scanner uji'));
    await tester.pumpAndSettle();
    expect(find.text('Akun operasional Wisata Daerahku'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Beranda Admin'), findsOneWidget);
  });
  testWidgets(
      'Superadmin center is retained analytics tab and hides navbar for keyboard',
      (tester) async {
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/overview')) {
        return jsonResponse({'data': overviewFixture()});
      }
      if (request.url.path.endsWith('/approvals')) {
        return jsonResponse({
          'data': {'series': []}
        });
      }
      return jsonResponse(pageEnvelope([]));
    }, role: 2);
    Widget app([double inset = 0]) => MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: inset)),
            child: OperationsNavigationShell(
                repository: repositoryFor(session), session: session)));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Analitik'));
    await tester.pumpAndSettle();
    expect(find.text('Perbandingan destinasi'), findsOneWidget);
    expect(find.byType(FloatingBottomNav), findsOneWidget);
    await tester.pumpWidget(app(300));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingBottomNav), findsNothing);
  });
  testWidgets(
      'same-generation scope revalidation purges all cached tab content',
      (tester) async {
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/overview')) {
        return jsonResponse({'data': overviewFixture()});
      }
      return jsonResponse(pageEnvelope([]));
    }, role: 1);
    await tester.pumpWidget(MaterialApp(
        home: OperationsNavigationShell(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    await session.me();
    await tester.pumpAndSettle();
    expect(find.text('Akses diperbarui'), findsOneWidget);
    expect(find.text('Beranda Admin'), findsNothing);
    await tester.tap(find.text('Muat sesuai akses terbaru'));
    await tester.pumpAndSettle();
    expect(find.text('Beranda Admin'), findsOneWidget);
  });
  for (final role in [1, 2]) {
    testWidgets('role $role resume reloads fresh data without access confirmation',
        (tester) async {
      var overviewReads = 0;
      final session = await adminSession((request) async {
        if (request.url.path.endsWith('/overview')) {
          overviewReads++;
          return jsonResponse({'data': overviewFixture()});
        }
        if (request.url.path.endsWith('/approvals')) {
          return jsonResponse({'data': {
            'period': overviewFixture()['period'],
            'series': <dynamic>[],
            'team_operational_totals': <String, dynamic>{},
          }});
        }
        return jsonResponse(pageEnvelope([]));
      }, role: role);
      await tester.pumpWidget(MaterialApp(
          home: OperationsNavigationShell(
              repository: repositoryFor(session), session: session)));
      await tester.pumpAndSettle();
      final readsBeforeResume = overviewReads;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(overviewReads, greaterThan(readsBeforeResume));
      expect(find.text('Akses diperbarui'), findsNothing);
      expect(find.text('Muat sesuai akses terbaru'), findsNothing);
      expect(find.text(role == 2 ? 'Ringkasan Eksekutif' : 'Halo, Admin.'),
          findsOneWidget);
    });
  }
}
