import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/screens/daftar_pendaftar_screen.dart';
import 'package:wisata_daerahku/screens/operations_booking_screen.dart';
import 'package:wisata_daerahku/screens/operations_dashboard.dart';
import 'package:wisata_daerahku/screens/operations_navigation_shell.dart';
import 'package:wisata_daerahku/theme/app_colors.dart';
import 'admin_test_support.dart';
import 'operations_test_support.dart';
import 'operations_shell_test.dart' show overviewFixture;

Future<void> openSheet(
    WidgetTester tester, Future<void> Function(BuildContext) open,
    {double scale = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      theme: AppColors.visitorTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => open(context),
                  child: const Text('Open'))))));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Use the committed product fonts so Ahem does not invent picker overflows.
    for (final weight in [400, 500, 600, 700, 800]) {
      final loader =
          FontLoader('PlusJakartaSans_${weight == 400 ? 'regular' : weight}');
      loader.addFont(File('artifacts/phase1a-visual/font-$weight.ttf')
          .readAsBytes()
          .then(ByteData.sublistView));
      await loader.load();
    }
  });

  testWidgets('role1 filters search paginated assigned options and reset query',
      (tester) async {
    final requests = <http.Request>[];
    final session = await adminSession((request) async {
      final page = int.parse(request.url.queryParameters['page']!);
      return jsonResponse(pageEnvelope([
        {'guid': 'd$page', 'name': page == 1 ? 'Pantai Aman' : 'Gunung Aman'}
      ], page: page, last: 2));
    }, role: 1, log: requests);
    Map<String, String>? result;
    await openSheet(tester, (context) async {
      result = await showOperationsFilters(context,
          repository: repositoryFor(session),
          session: session,
          initial: const {});
    });
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.tap(find.text('Semua destinasi saya'));
    await tester.pumpAndSettle();
    expect(requests.map((r) => r.url.path).toSet(),
        {'/api/v1/admin/destinations'});
    expect(requests.map((r) => r.url.queryParameters['page']), ['1', '2']);
    await tester.enterText(
        find.byKey(const ValueKey('operations-destination-search')), 'GUNUNG');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(find.text('Pantai Aman'), findsNothing);
    expect(tester.takeException(), isNull);
    await tapVisible(
        tester, find.byKey(const ValueKey('operations-destination-d2')));
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    expect(find.text('Gunung Aman'), findsOneWidget);
    await tapVisible(
        tester, find.byKey(const ValueKey('operations-apply-filters')));
    expect(result, {'destination_guid': 'd2'});

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tapVisible(
        tester, find.byKey(const ValueKey('operations-reset-filters')));
    await tapVisible(
        tester, find.byKey(const ValueKey('operations-apply-filters')));
    expect(result, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final role in [1, 2]) {
    testWidgets('role$role date picker follows its own UI branch',
        (tester) async {
      final session = await adminSession(
          (_) async => jsonResponse(pageEnvelope([])),
          role: role);
      await openSheet(tester, (context) async {
        await showOperationsFilters(context,
            repository: repositoryFor(session),
            session: session,
            initial: const {});
      });
      expect(tester.takeException(), isNull, reason: 'Filter sheet layout');
      await tapVisible(tester,
          find.text(role == 1 ? 'Pilih rentang tanggal' : 'Pilih periode'));
      if (role == 1) {
        expect(find.byType(DateRangePickerDialog), findsNothing);
        await tapVisible(
            tester, find.byKey(const ValueKey('operations-preset-7')));
        await tapVisible(
            tester, find.byKey(const ValueKey('operations-apply-period')));
        final apply = tester.widget<FilledButton>(
            find.byKey(const ValueKey('operations-apply-filters')));
        expect(apply.onPressed, isNotNull);
      } else {
        expect(find.byType(DateRangePickerDialog), findsOneWidget);
        expect(find.byKey(const ValueKey('operations-apply-period')),
            findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final days in [7, 30, 0]) {
    testWidgets('custom calendar preset $days returns calendar dates',
        (tester) async {
      DateTimeRange? result;
      final before = DateTime.now().toUtc();
      await openSheet(tester, (context) async {
        result = await showOperationsDateRangeCalendar(context, utc: true);
      });
      await tapVisible(
          tester,
          find.byKey(
              ValueKey('operations-preset-${days == 0 ? 'month' : days}')));
      await tapVisible(
          tester, find.byKey(const ValueKey('operations-apply-period')));
      final after = DateTime.now().toUtc();
      final end = result!.end;
      expect(end.hour, 0);
      expect(
          end,
          anyOf(DateTime(before.year, before.month, before.day),
              DateTime(after.year, after.month, after.day)));
      if (days == 0) {
        expect(result!.start, DateTime(end.year, end.month));
      } else {
        expect(end.difference(result!.start).inDays + 1, days);
      }
    });
  }

  for (final financial in [false, true]) {
    for (final allowed in [true, false]) {
      testWidgets('calendar financial=$financial boundary allowed=$allowed',
          (tester) async {
        final start = DateTime(2024, 1, 1);
        final difference = (financial ? 365 : 366) + (allowed ? 0 : 1);
        final end = start.add(Duration(days: difference));
        DateTimeRange? result;
        await openSheet(tester, (context) async {
          result = await showOperationsDateRangeCalendar(context,
              from: start, financial: financial);
        });
        for (var month = 1;
            month < (end.year - 2024) * 12 + end.month;
            month++) {
          await tapVisible(tester, find.byTooltip('Bulan berikutnya'));
        }
        final day = '${end.year}-${end.month.toString().padLeft(2, '0')}-'
            '${end.day.toString().padLeft(2, '0')}';
        await tapVisible(tester, find.byKey(ValueKey('operations-day-$day')));
        final apply = tester.widget<FilledButton>(
            find.byKey(const ValueKey('operations-apply-period')));
        expect(apply.onPressed != null, allowed);
        if (allowed) {
          await tapVisible(
              tester, find.byKey(const ValueKey('operations-apply-period')));
          expect(result!.start, start);
          expect(result!.end, end);
        } else {
          expect(
              find.textContaining('Periode maksimal 366 hari'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'calendar reverse selection spans leap day and reset disables apply',
      (tester) async {
    DateTimeRange? result;
    await openSheet(tester, (context) async {
      result = await showOperationsDateRangeCalendar(context,
          from: DateTime(2024, 3, 1));
    });
    await tapVisible(tester, find.byTooltip('Bulan sebelumnya'));
    await tapVisible(
        tester, find.byKey(const ValueKey('operations-day-2024-02-29')));
    await tapVisible(
        tester, find.byKey(const ValueKey('operations-apply-period')));
    expect(result!.start, DateTime(2024, 2, 29));
    expect(result!.end, DateTime(2024, 3, 1));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tapVisible(
        tester, find.byKey(const ValueKey('operations-reset-period')));
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('operations-apply-period')))
            .onPressed,
        isNull);
  });

  testWidgets('role1 explicit claim then reject with blank optional reason',
      (tester) async {
    final requests = <http.Request>[];
    String? owner;
    var status = 'pending_approval';
    final session = await adminSession((request) async {
      if (request.method == 'POST') {
        if (request.url.path.endsWith('/claim')) {
          owner = 'admin-1';
          return jsonResponse({'data': operationalClaim(owner)});
        }
        status = 'rejected';
        return jsonResponse({'data': operationalBooking(status)});
      }
      return request.url.path.endsWith('/b1')
          ? jsonResponse({'data': operationalBooking(status)})
          : jsonResponse(pageEnvelope([operationalQueueRow(owner: owner)]));
    }, role: 1, log: requests);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: OperationsBookingScreen(
            bookingGuid: 'b1',
            repository: repositoryFor(session),
            session: session)));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(find.text('Setujui'), findsNothing);
    final dock = find.byKey(const ValueKey('booking-primary-action'));
    expect(tester.getRect(dock).bottom, lessThanOrEqualTo(800));
    await tester.tap(dock);
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    await tester.tap(dock);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('confirm-booking-decision')))
            .onPressed,
        isNull);
    await tapVisible(tester, find.text('Tolak'));
    expect(find.text('Alasan penolakan (opsional)'), findsOneWidget);
    await tapVisible(
        tester, find.byKey(const ValueKey('confirm-booking-decision')));
    final posts = requests.where((r) => r.method == 'POST').toList();
    expect(posts, hasLength(2));
    expect(posts.last.url.path, '/api/v1/admin/bookings/b1/reject');
    expect(posts.last.body, isEmpty);
    expect(find.byKey(const ValueKey('booking-primary-action')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('role1 claim release stays in secondary menu', (tester) async {
    var owner = 'admin-1';
    final requests = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.method == 'POST') {
        owner = '';
        return jsonResponse({'data': operationalClaim(null)});
      }
      return request.url.path.endsWith('/b1')
          ? jsonResponse({'data': operationalBooking()})
          : jsonResponse(pageEnvelope(
              [operationalQueueRow(owner: owner.isEmpty ? null : owner)]));
    }, role: 1, log: requests);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: OperationsBookingScreen(
            bookingGuid: 'b1',
            repository: repositoryFor(session),
            session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Lepas Claim'), findsNothing);
    await tester.tap(find.byTooltip('Pilihan claim'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lepas Claim'));
    await tester.pumpAndSettle();
    expect(requests.singleWhere((r) => r.method == 'POST').url.path,
        '/api/v1/admin/bookings/b1/release');
    expect(find.text('Ambil Claim'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('resume with changed claim owner disables an open decision sheet',
      (tester) async {
    var owner = 'admin-1';
    final requests = <http.Request>[];
    final session = await adminSession((request) async {
      return request.url.path.endsWith('/b1')
          ? jsonResponse({'data': operationalBooking()})
          : jsonResponse(pageEnvelope([operationalQueueRow(owner: owner)]));
    }, role: 1, log: requests);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: OperationsBookingScreen(
            bookingGuid: 'b1',
            repository: repositoryFor(session),
            session: session)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-primary-action')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Setujui'));
    final confirm = find.byKey(const ValueKey('confirm-booking-decision'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    owner = 'other';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    expect(requests.where((request) => request.method == 'POST'), isEmpty);
    expect(find.textContaining('Claim atau akses berubah.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'role1 legacy history scrolls nine statuses and opens guarded detail',
      (tester) async {
    final requests = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/approval-queue')) {
        return jsonResponse(pageEnvelope([operationalQueueRow()]));
      }
      if (request.url.path.endsWith('/b1')) {
        return jsonResponse({'data': operationalBooking()});
      }
      return jsonResponse(pageEnvelope([operationalBooking()]));
    }, role: 1, log: requests);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: DaftarPendaftarScreen(
            repository: repositoryFor(session), session: session)));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(9));
    final last = find.byType(ChoiceChip).last;
    await tapVisible(tester, last);
    expect(requests.last.url.queryParameters['status'], 'cancelled');
    await tapVisible(tester, find.byKey(const ValueKey('b1')));
    expect(find.byType(OperationsBookingScreen), findsOneWidget);
    expect(find.text('Ambil Claim'), findsOneWidget);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('hidden operations pages mute tickers after scanner returns',
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
                    child: const Text('Close scanner fixture'))))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Scan QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close scanner fixture'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Akun operasional Wisata Daerahku'), findsOneWidget);
    final hiddenProgress =
        find.byType(LinearProgressIndicator, skipOffstage: false);
    expect(hiddenProgress, findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    for (final element in hiddenProgress.evaluate()) {
      expect(TickerMode.valuesOf(element).enabled, isFalse,
          reason: 'Inactive operations tab must not animate its loading UI.');
    }
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
