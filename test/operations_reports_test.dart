import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wisata_daerahku/screens/admin/operations_dashboard/operations_dashboard.dart';
import 'admin_test_support.dart';
import 'operations_shell_test.dart' show overviewFixture;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'destination report stays usable at approved mobile sizes and large text',
      (tester) async {
    final session = await adminSession(
        (_) async => jsonResponse(pageEnvelope([
              {
                'destination_guid': 'd1',
                'name': 'Pantai Indah',
                'capacity': 40,
                'allocated': 12,
                'confirmed_quantity': 8,
                'remaining': 28,
                'bookings': 4,
                'quantity_requested': 12
              }
            ], last: 2)),
        role: 1);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final size in [const Size(360, 800), const Size(393, 852)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: size, textScaler: const TextScaler.linear(2)),
              child: OperationsReportScreen(
                  key: ValueKey(size),
                  section: 'destinations',
                  repository: repositoryFor(session),
                  session: session))));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Berikutnya'), 250);
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
      'zero assignments shows explicit scoped state without made-up revenue',
      (tester) async {
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/overview')) {
        return jsonResponse({
          'data': {
            ...overviewFixture(),
            'metrics': {'assigned_destinations': 0, 'pending_approvals': 0}
          }
        });
      }
      return jsonResponse(pageEnvelope([]));
    }, role: 1);
    tester.view.physicalSize = const Size(393, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: OperationsDashboard(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada destinasi'), findsOneWidget);
    expect(find.byType(OperationsMetrics), findsNothing);
    expect(find.byType(OperationsTrend), findsNothing);
    expect(find.text('Destinasi'), findsNothing);
    expect(find.text('Tarik turun untuk memeriksa penugasan.'), findsOneWidget);
    expect(find.text('Rp0'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('visitor analytics preserves unavailable attendance and no-show',
      (tester) async {
    final session = await adminSession(
        (_) async => jsonResponse({
              'data': {
                'generated_at': '2026-11-05T01:00:00Z',
                'metrics': {
                  'checked_in_tickets': 5,
                  'checked_in_bookings': 2,
                  'attendance_rate': null,
                  'no_show_count': null
                }
              }
            }),
        role: 1);
    await tester.pumpWidget(MaterialApp(
        home: OperationsReportScreen(
            section: 'visitors',
            repository: repositoryFor(session),
            session: session)));
    await tester.pumpAndSettle();
    expect(find.text('5'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('0%'), findsNothing);
    expect(find.textContaining('belum terverifikasi'), findsOneWidget);
  });
  testWidgets(
      'destination rows paginate and capacity-zero occupancy stays unavailable',
      (tester) async {
    final pages = <String?>[];
    final session = await adminSession((request) async {
      pages.add(request.url.queryParameters['page']);
      return jsonResponse(pageEnvelope([
        {
          'destination_guid': 'd${pages.length}',
          'name': 'Pantai ${pages.length}',
          'capacity': 0,
          'allocated': 0,
          'confirmed_quantity': 0,
          'remaining': 0,
          'reserved_occupancy_percent': null,
          'confirmed_occupancy_percent': null
        }
      ], page: pages.length, last: 2));
    }, role: 1);
    await tester.pumpWidget(MaterialApp(
        home: OperationsReportScreen(
            section: 'destinations',
            repository: repositoryFor(session),
            session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Pantai 1'), findsOneWidget);
    expect(find.text('Okupansi: — · Belum tersedia'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Berikutnya'), 200);
    await tester.ensureVisible(find.text('Berikutnya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Berikutnya'));
    await tester.pumpAndSettle();
    expect(pages, ['1', '2']);
    expect(find.text('Pantai 2'), findsOneWidget);
  });
  testWidgets(
      'staff details use filtered team metrics and never infer per-admin SLA from aggregate list',
      (tester) async {
    final queries = <Map<String, String>>[];
    final session = await adminSession((request) async {
      queries.add(request.url.queryParameters);
      return jsonResponse({
        'data': {
          'team_operational_totals': {
            'approved_decisions': 4,
            'rejected_decisions': 1,
            'sla_compliance_percent': 80
          },
          'personal': {'approved_decisions': 0},
          'series': []
        }
      });
    }, role: 2);
    await tester.pumpWidget(MaterialApp(
        home: OperationsReportScreen(
            section: 'approvals',
            adminGuid: 'target-guid',
            adminName: 'Sari',
            repository: repositoryFor(session),
            session: session)));
    await tester.pumpAndSettle();
    expect(queries.single['admin_guid'], 'target-guid');
    expect(find.text('4'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('Sari'), findsOneWidget);
  });
  testWidgets(
      'scope revoked removes report rows and requires explicit scoped selector',
      (tester) async {
    var revoked = false;
    final session = await adminSession(
        (_) async => revoked
            ? jsonResponse({'message': 'Forbidden'}, 403)
            : jsonResponse(pageEnvelope([
                {
                  'destination_guid': 'secret',
                  'name': 'Destinasi Privat',
                  'capacity': 2
                }
              ])),
        role: 1);
    await tester.pumpWidget(MaterialApp(
        home: OperationsReportScreen(
            section: 'destinations',
            repository: repositoryFor(session),
            session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Destinasi Privat'), findsOneWidget);
    revoked = true;
    expect(find.byTooltip('Perbarui data'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('Destinasi Privat'), findsNothing);
    expect(find.textContaining('Pilih ulang destinasi yang dapat diakses'),
        findsOneWidget);
  });
  testWidgets('audit route presents honest backend gap', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: OperationsUnavailableScreen(audit: true)));
    expect(find.textContaining('Riwayat aktivitas global belum tersedia'),
        findsOneWidget);
  });
  testWidgets(
      'hidden report loads only after activation and does not fetch on app resume',
      (tester) async {
    var requests = 0;
    final session = await adminSession((_) async {
      requests++;
      return jsonResponse({
        'data': {
          'metrics': {'checked_in_tickets': 2}
        }
      });
    }, role: 1);
    Widget app(bool active) => MaterialApp(
        home: OperationsReportScreen(
            section: 'visitors',
            session: session,
            repository: repositoryFor(session),
            active: active));
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(requests, 0);
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(requests, 1);
  });
  testWidgets('same-session revalidation clears assigned filter choices',
      (tester) async {
    Map<String, String>? applied;
    final session = await adminSession(
        (_) async => jsonResponse(pageEnvelope([
              {'guid': 'private-destination', 'name': 'Pilihan Privat'}
            ])),
        role: 1);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      applied = await showOperationsFilters(context,
                          repository: repositoryFor(session),
                          session: session,
                          initial: const {
                            'destination_guid': 'private-destination'
                          });
                    },
                    child: const Text('Buka filter'))))));
    await tester.tap(find.text('Buka filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 destinasi dipilih'));
    await tester.pumpAndSettle();
    expect(find.text('Pilihan Privat'), findsOneWidget);
    await session.me();
    await tester.pumpAndSettle();
    expect(find.text('Pilihan Privat'), findsNothing);
    expect(find.textContaining('Tarik ke bawah untuk mencoba kembali'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Tutup').last);
    await tester.pumpAndSettle();
    final apply = tester.widget<FilledButton>(
        find.byKey(const ValueKey('operations-apply-filters')));
    expect(apply.onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('operations-apply-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Buka filter'), findsOneWidget);
    expect(applied, isEmpty);
  });
}
