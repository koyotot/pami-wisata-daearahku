import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wisata_daerahku/screens/admin/operations_dashboard/operations_dashboard.dart';
import 'package:wisata_daerahku/screens/admin/operations_navigation_shell.dart';
import 'package:wisata_daerahku/widgets/floating_bottom_nav.dart';
import 'package:wisata_daerahku/widgets/operations_tabs.dart';
import 'admin_test_support.dart';
import 'operations_shell_test.dart' show overviewFixture;

// Captures use HTTP fixtures only; emulator screenshots are recorded separately.
const _capture = bool.fromEnvironment('OPERATIONS_CAPTURE');

Future<void> _screenshot(
    WidgetTester tester, GlobalKey boundary, String name) async {
  if (!_capture) return;
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
        'qa/admin-role1-post-relayout/results/widget-renders/test-fixture-$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final weight in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800
    ]) {
      final variant = weight == FontWeight.w400 ? 'regular' : '${weight.value}';
      final font = FontLoader('PlusJakartaSans_$variant');
      font.addFont(File('artifacts/phase1a-visual/font-${weight.value}.ttf')
          .readAsBytes()
          .then(ByteData.sublistView));
      await font.load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('personal segment keeps API values and unavailable metrics',
      (tester) async {
    var reads = 0;
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/overview')) {
        reads++;
        return jsonResponse({'data': overviewFixture()});
      }
      return jsonResponse(pageEnvelope([]));
    }, role: 1);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: OperationsNavigationShell(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kinerja Saya'));
    await tester.pumpAndSettle();
    final metrics =
        tester.widget<OperationsMetrics>(find.byType(OperationsMetrics));
    expect(find.text('Keputusan pribadi'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(metrics.values.map((v) => v.$2), ['1', '—', '—', '—']);
    expect(metrics.icons, isNull);
    expect(reads, 1);
    expect(tester.takeException(), isNull);
  });

  for (final screen in ['a00', 'e00', 'x01']) {
    for (final size in [const Size(360, 800), const Size(393, 852)]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
            '$screen ${size.width.toInt()}x${size.height.toInt()} text $scale',
            (tester) async {
          final role = screen == 'e00' ? 2 : 1;
          var overviewReads = 0;
          final session = await adminSession((request) async {
            if (request.url.path.endsWith('/overview')) {
              overviewReads++;
              return jsonResponse({
                'data': {
                  ...overviewFixture(),
                  if (screen == 'x01')
                    'metrics': {
                      'assigned_destinations': 0,
                      'pending_approvals': 0
                    },
                  'booking_trend': [
                    for (var i = 1; i <= 5; i++)
                      {'date': '2026-11-0$i', 'bookings': i},
                  ],
                }
              });
            }
            if (request.url.path.endsWith('/approvals')) {
              return jsonResponse({
                'data': {
                  'series': [
                    {
                      'date': '2026-11-01',
                      'approved_decisions': 2,
                      'rejected_decisions': 1
                    },
                    {
                      'date': '2026-11-05',
                      'approved_decisions': 0,
                      'rejected_decisions': 0
                    },
                  ]
                }
              });
            }
            return jsonResponse(pageEnvelope([]));
          }, role: role);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          final boundary = GlobalKey();
          await tester.pumpWidget(MaterialApp(
              home: RepaintBoundary(
            key: boundary,
            child: MediaQuery(
              data: MediaQueryData(
                  size: size,
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                  viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
                  textScaler: TextScaler.linear(scale)),
              child: OperationsNavigationShell(
                  repository: repositoryFor(session), session: session),
            ),
          )));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(FloatingBottomNav), findsOneWidget);
          expect(find.text('Rp0'), findsNothing);
          if (scale == 1) {
            await _screenshot(
                tester, boundary, '$screen-${size.width.toInt()}-top');
          }

          if (screen == 'x01') {
            expect(find.byType(OperationsMetrics), findsNothing);
            expect(find.byType(OperationsTrend), findsNothing);
            expect(find.byType(OperationsHomeTabs), findsNothing);
            await tester.scrollUntilVisible(
                find.text('Tarik turun untuk memeriksa penugasan.'), 150);
            await tester.drag(
                find.byType(ListView).first, const Offset(0, -300));
            await tester.pumpAndSettle();
            expect(
                tester
                    .getRect(
                        find.text('Tarik turun untuk memeriksa penugasan.'))
                    .bottom,
                lessThan(tester.getRect(find.byType(FloatingBottomNav)).top));
            await tester.drag(
                find.byType(ListView).first, const Offset(0, 5000));
            await tester.pumpAndSettle();
            final readsBeforePull = overviewReads;
            await tester.drag(
                find.byType(ListView).first, const Offset(0, 400));
            await tester.pumpAndSettle();
            expect(overviewReads, readsBeforePull + 1);
          } else {
            final metrics = tester.widget<OperationsMetrics>(
                find.byType(OperationsMetrics).first);
            expect(metrics.values.map((v) => v.$2),
                role == 1 ? ['3', '1'] : ['3', '1', '2', '1']);
            expect(metrics.icons, hasLength(role == 1 ? 2 : 4));
            expect(metrics.metadata, role == 1 ? isNull : hasLength(4));
            if (scale == 1) {
              final pending = tester.getRect(
                  find.text(role == 1 ? 'Pending approval' : 'Pending global'));
              final destination = tester.getRect(find.text(
                  role == 1 ? 'Destinasi ditugaskan' : 'Destinasi global'));
              expect(pending.top, closeTo(destination.top, 1));
              expect(pending.left, lessThan(destination.left));
            }
            expect(find.byType(OperationsHomeTabs),
                role == 1 ? findsOneWidget : findsNothing);
            final chartTitle = find
                .text(role == 2 ? 'Tren Keputusan Tim' : 'Aktivitas booking');
            await tester.scrollUntilVisible(chartTitle, 200);
            await Scrollable.ensureVisible(tester.element(chartTitle),
                alignment: .05);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (scale == 1) {
              expect(tester.getRect(find.byType(OperationsTrend).first).bottom,
                  lessThan(tester.getRect(find.byType(FloatingBottomNav)).top));
              await _screenshot(
                  tester, boundary, '$screen-${size.width.toInt()}-chart');
            }
            final financeLink = find.text(role == 1
                ? 'Buka dashboard keuangan'
                : 'Buka Financial Dashboard');
            await Scrollable.ensureVisible(tester.element(financeLink),
                alignment: .1);
            await tester.pumpAndSettle();
            expect(tester.getRect(financeLink).bottom,
                lessThan(tester.getRect(find.byType(FloatingBottomNav)).top));
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
