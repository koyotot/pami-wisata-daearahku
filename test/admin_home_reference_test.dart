import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wisata_daerahku/data/admin_state.dart' show isoDay;
import 'package:wisata_daerahku/screens/admin/operations_dashboard/operations_dashboard.dart';
import 'package:wisata_daerahku/screens/admin/operations_queue_screen.dart';
import 'package:wisata_daerahku/screens/admin/daftar_pendaftar_screen.dart';
import 'package:wisata_daerahku/widgets/operations_chrome.dart';
import 'package:wisata_daerahku/theme/app_colors.dart';
import 'admin_test_support.dart';
import 'operations_shell_test.dart' show overviewFixture;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final weight in [400, 500, 600, 700, 800]) {
      final font =
          FontLoader('PlusJakartaSans_${weight == 400 ? 'regular' : weight}');
      font.addFont(File('artifacts/phase1a-visual/font-$weight.ttf')
          .readAsBytes()
          .then(ByteData.sublistView));
      await font.load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader('packages/phosphor_icons/PhosphorRegular')
          ..addFont(rootBundle
              .load('packages/phosphor_icons/lib/fonts/Phosphor.ttf')))
        .load();
  });

  test('compact periods preserve month and year boundaries', () {
    for (final entry in [
      ('2026-11-01', '2026-11-06', '1–6 Nov 2026'),
      ('2026-11-06', '2026-11-06', '6 Nov 2026'),
      ('2026-10-31', '2026-11-06', '31 Okt–6 Nov 2026'),
    ]) {
      expect(
          operationsPeriodLabel({'from': entry.$1, 'to': entry.$2},
              includeYear: true),
          entry.$3);
    }
    expect(
        operationsPeriodLabel({'from': '2025-12-31', 'to': '2026-01-01'},
            includeYear: true),
        contains('2025'));
    expect(operationsPeriodLabel({}), 'Semua tanggal');
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('reference home layout and API values at text scale $scale',
        (tester) async {
      final session = await adminSession((request) async {
        if (request.url.path.endsWith('/overview')) {
          return jsonResponse({
            'data': {
              ...overviewFixture(),
              'period': {'from': '2026-11-01', 'to': '2026-11-06'},
              'metrics': {
                'assigned_destinations': 2,
                'pending_approvals': 0,
                'approved_decisions': 3
              },
              'booking_trend': [
                {'date': '2026-11-01', 'bookings': 5},
                {'date': '2026-11-06', 'bookings': 2},
              ],
            }
          });
        }
        if (request.url.path.endsWith('/destinations')) {
          return jsonResponse(pageEnvelope([
            {'guid': 'd1', 'name': 'Horeg Mini'},
            {
              'guid': 'd2',
              'name': scale == 1
                  ? 'Pantai'
                  : 'Pantai dengan nama destinasi yang sangat panjang'
            },
          ]));
        }
        if (request.url.path.endsWith('/action-center')) {
          return jsonResponse(pageEnvelope([
            {
              'booking_guid': 'b1',
              'destination_name_snapshot': 'Horeg Mini',
              'action': 'upcoming_visit',
              'visit_date': '2026-11-07',
              'claim_state': 'unclaimed'
            },
          ]));
        }
        if (request.url.path.endsWith('/financial')) {
          return jsonResponse({
            'data': {
              'financial': {
                'environment': 'demo',
                'provider': 'demo',
                'test_only': true,
                'currency': 'IDR',
                'source': 'simulated_demo_events',
                'availability': 'available',
                'scope': {
                  'mode': 'assigned_destinations',
                  'destination_guid': null
                },
                'gross_revenue': 1500000,
                'successful_transactions': 1,
              }
            }
          });
        }
        return jsonResponse(pageEnvelope([]));
      }, role: 1);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: AppColors.operationsTheme,
          home: MediaQuery(
              data: MediaQueryData(
                  size: const Size(360, 800),
                  textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                  key: boundary,
                  child: OperationsDashboard(
                      repository: repositoryFor(session), session: session)))));
      await tester.pumpAndSettle();
      expect(find.textContaining('1–6 Nov 2026'), findsOneWidget);
      expect(find.text('3 disetujui'), findsOneWidget);
      final metrics =
          tester.widget<OperationsMetrics>(find.byType(OperationsMetrics));
      expect(metrics.values.map((e) => e.$2), ['0', '2']);
      expect(tester.takeException(), isNull);
      await capture(tester, boundary, 'top-$scale');
      for (final title in [
        'Butuh perhatian',
        'Akses cepat',
        'Keuangan & aktivitas',
        'Aktivitas booking'
      ]) {
        final finder = find.text(title);
        await Scrollable.ensureVisible(tester.element(finder), alignment: .05);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1 && title == 'Butuh perhatian') {
          expect(find.text('Kunjungan mendatang'), findsOneWidget);
          expect(find.textContaining('7 November 2026'), findsOneWidget);
          await capture(tester, boundary, 'actions');
        }
        if (scale == 1 && title == 'Keuangan & aktivitas') {
          expect(find.text('Rp1.500.000'), findsOneWidget);
          await capture(tester, boundary, 'finance');
        }
      }
      final handle = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  }

  testWidgets(
      'home filters preserve destination and apply the displayed API period',
      (tester) async {
    final queries = <Map<String, String>>[];
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/overview')) {
        queries.add(request.url.queryParameters);
        return jsonResponse({'data': overviewFixture()});
      }
      if (request.url.path.endsWith('/destinations')) {
        return jsonResponse(pageEnvelope([
          {'guid': 'd1', 'name': 'Danau Baru'},
        ]));
      }
      return jsonResponse(pageEnvelope([]));
    }, role: 1);
    await tester.pumpWidget(MaterialApp(
        home: OperationsDashboard(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-destination-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('operations-destination-d1')));
    await tester.pumpAndSettle();
    expect(queries.last['destination_guid'], 'd1');
    await tester.tap(find.byKey(const ValueKey('home-date-filter')));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('operations-apply-period')));
    await tester.tap(find.byKey(const ValueKey('operations-apply-period')));
    await tester.pumpAndSettle();
    expect(queries.last,
        {'destination_guid': 'd1', 'from': '2026-11-01', 'to': '2026-11-05'});
    expect(tester.takeException(), isNull);
  });

  for (final role in [1, 2]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('action center filters for role $role at text scale $scale',
          (tester) async {
        final queries = <Map<String, String>>[];
        final session = await adminSession((request) async {
          if (request.url.path.endsWith('/action-center')) {
            queries.add(request.url.queryParameters);
          }
          return jsonResponse(pageEnvelope([]));
        }, role: role);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 800);
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        await tester.pumpWidget(MaterialApp(
            theme: AppColors.operationsTheme,
            home: MediaQuery(
                data: MediaQueryData(
                    size: const Size(360, 800),
                    textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(
                    key: boundary,
                    child: OperationsReportScreen(
                        section: 'action-center',
                        repository: repositoryFor(session),
                        session: session)))));
        await tester.pumpAndSettle();
        if (role == 1) {
          final bar = tester
              .widget<OperationsFilterBar>(find.byType(OperationsFilterBar));
          final now = DateTime.now().toUtc();
          expect(bar.filters['from'], isoDay(DateTime(now.year, now.month)));
          expect(
              bar.filters['to'], isoDay(DateTime(now.year, now.month + 1, 0)));
          expect(queries.last['from'], bar.filters['from']);
          expect(queries.last['to'], bar.filters['to']);
          await capture(tester, boundary, 'action-center-$scale');
          for (final control in ['destination', 'date']) {
            await tester
                .tap(find.byKey(ValueKey('action-center-$control-filter')));
            await tester.pumpAndSettle();
            expect(find.text('Filter Destinasi'), findsOneWidget);
            await tester.ensureVisible(
                find.byKey(const ValueKey('operations-apply-filters')));
            await tester
                .tap(find.byKey(const ValueKey('operations-apply-filters')));
            await tester.pumpAndSettle();
          }
        } else {
          expect(find.byType(OperationsFilterBar), findsNothing);
          expect(queries.last.containsKey('from'), isFalse);
          expect(queries.last.containsKey('to'), isFalse);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final title in [
    'Antrean approval',
    'Kinerja destinasi',
    'Kunjungan & check-in',
    'Data pendaftar'
  ]) {
    testWidgets('$title opens existing route', (tester) async {
      final session = await adminSession(
          (request) async => request.url.path.endsWith('/overview')
              ? jsonResponse({'data': overviewFixture()})
              : jsonResponse(pageEnvelope([])),
          role: 1);
      await tester.pumpWidget(MaterialApp(
          home: OperationsDashboard(
              repository: repositoryFor(session), session: session)));
      await tester.pumpAndSettle();
      final shortcut = find.byKey(ValueKey('home-shortcut-$title'));
      await Scrollable.ensureVisible(tester.element(shortcut), alignment: .1);
      await tester.pumpAndSettle();
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      if (title == 'Antrean approval') {
        expect(find.byType(OperationsQueueScreen), findsOneWidget);
      } else if (title == 'Data pendaftar') {
        expect(find.byType(DaftarPendaftarScreen), findsOneWidget);
      } else {
        expect(
            tester
                .widget<OperationsReportScreen>(
                    find.byType(OperationsReportScreen))
                .section,
            title == 'Kinerja destinasi' ? 'destinations' : 'visitors');
      }
      expect(tester.takeException(), isNull);
    });
  }
}

// These renders use HTTP fixtures and do not establish live API/device coverage.
Future<void> capture(
    WidgetTester tester, GlobalKey boundary, String name) async {
  if (!const bool.fromEnvironment('ADMIN_HOME_CAPTURE')) return;
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('artifacts/admin-home-reference/fixture-$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
