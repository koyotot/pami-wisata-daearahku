import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_scanner/src/method_channel/mobile_scanner_method_channel.dart';
import 'package:wisata_daerahku/data/admin_state.dart';
import 'package:wisata_daerahku/data/notification_state.dart';
import 'package:wisata_daerahku/screens/admin/admin_ticket_scanner_screen.dart';
import 'package:wisata_daerahku/screens/superadmin/kelola_admin_screen.dart';
import 'package:wisata_daerahku/screens/superadmin/kelola_fasilitas_screen.dart';
import 'package:wisata_daerahku/screens/user/bukti_pendaftaran_screen.dart';
import 'package:wisata_daerahku/screens/user/cari_wisata_screen.dart';
import 'package:wisata_daerahku/screens/user/notifikasi_screen.dart';
import 'package:wisata_daerahku/screens/user/profil_user_screen.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/theme/app_colors.dart';
import 'package:wisata_daerahku/widgets/destination_hero_gallery.dart';
import 'package:wisata_daerahku/widgets/scroll_aware_status_bar.dart';
import 'package:wisata_daerahku/widgets/visit_format.dart';
import 'admin_test_support.dart';
import 'destination_gallery_test.dart' show pictures;
import 'gallery_test_support.dart';
import 'user_support.dart' as users;

/// The two viewports from the audit: standard and compact with large text.
const viewports = <(String, Size, double)>[
  ('393x852 font 1.0', Size(393, 852), 1.0),
  ('320x712 font 1.6', Size(320, 712), 1.6),
];

/// Plus Jakarta Sans is fetched at runtime by google_fonts and is not bundled,
/// so the default test font (every glyph 1 em wide) would make any width check
/// meaningless. Set PAMI_FONT_DIR to a folder with the real
/// `PlusJakartaSans_<weight>.ttf` files to measure with true metrics.
final _fontDir = Platform.environment['PAMI_FONT_DIR'];
bool get realFonts => _fontDir != null;

Future<void> _loadRealFonts() async {
  if (_fontDir == null) return;
  for (final weight in ['regular', '500', '600', '700', '800']) {
    final bytes = File('$_fontDir/PlusJakartaSans_$weight.ttf').readAsBytes();
    // google_fonts names each weight as its own family.
    await (FontLoader('PlusJakartaSans_$weight')
          ..addFont(bytes.then(ByteData.sublistView)))
        .load();
  }
  // Plain TextStyles without a family fall back to the platform default.
  await (FontLoader('Roboto')
        ..addFont(File('$_fontDir/PlusJakartaSans_regular.ttf')
            .readAsBytes()
            .then(ByteData.sublistView)))
      .load();
}

/// Every layout error reported while pumping, with the widget that caused it.
final _reported = <FlutterErrorDetails>[];

void expectNoLayoutErrors(WidgetTester tester) {
  tester.takeException();
  expect(
      _reported.map((d) {
        final text = d.toString();
        final at = text.indexOf('The relevant error-causing widget was');
        return at < 0
            ? d.summary.toString()
            : '${d.summary}\n${text.substring(at, (at + 260).clamp(0, text.length))}';
      }).toList(),
      isEmpty);
}

Future<void> pumpAt(WidgetTester tester, Size size, double scale, Widget home,
    {EdgeInsets padding = const EdgeInsets.only(top: 24)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _reported.clear();
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    _reported.add(details);
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
  await tester.pumpWidget(MaterialApp(
    // The app's root theme (Phase 0) so text uses the same families.
    theme: AppColors.visitorTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
          padding: padding,
          textScaler: TextScaler.linear(scale),
          disableAnimations: true),
      child: child!,
    ),
    home: home,
  ));
}

class _CameraPlatform extends MethodChannelMobileScanner {
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Stream<DeviceOrientation> get deviceOrientationChangedStream =>
      const Stream.empty();
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async =>
      const MobileScannerViewAttributes(
          cameraDirection: CameraFacing.back,
          currentTorchMode: TorchState.off,
          size: Size(640, 480));
  @override
  Future<void> stop({bool force = false}) async {}
  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<void> dispose() async {}
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadRealFonts();
  });

  group('F07/F12 formatting', () {
    test('operational money uses Rp like catalog and detail', () {
      expect(formatMoney(50000, 'IDR'), 'Rp50.000');
      expect(formatMoney(50000, 'IDR'), visitMoney(50000, 'IDR'));
      expect(formatMoney(-1500, 'IDR'), '-Rp1.500');
      expect(formatMoney(0, 'IDR'), 'Gratis');
      expect(formatMoney(5, 'USD'), 'USD 5', reason: 'other currencies named');
    });

    test('deadline keeps the instant and names the zone', () {
      final instant = DateTime.parse('2026-11-12T15:14:48+00:00');
      expect(formatInstantAt(instant, const Duration(hours: 7)),
          '12 Nov 2026, 22.14 WIB');
      expect(formatInstantAt(instant, const Duration(hours: 8)),
          '12 Nov 2026, 23.14 WITA');
      expect(formatInstantAt(instant, const Duration(hours: 9)),
          '13 Nov 2026, 00.14 WIT');
      expect(
          formatInstantAt(instant, Duration.zero), '12 Nov 2026, 15.14 UTC+0');
      expect(zoneLabel(const Duration(hours: 5, minutes: 30)), 'UTC+5:30');
      expect(formatDeadline(null), '—');
      expect(formatDeadline('bukan tanggal'), 'bukan tanggal');
      final local = formatDeadline('2026-11-12T15:14:48+00:00');
      expect(local, isNot(contains('T15')));
      expect(local, isNot(contains('+00:00')));
    });

    test('visit day reads as a calendar date without conversion', () {
      expect(visitDayLabel('2026-11-13'), '13 Nov 2026');
      expect(visitDayLabel('2026-11-13T00:00:00.000000Z'), '13 Nov 2026');
      expect(visitDayLabel('besok'), 'besok');
    });
  });

  for (final (name, size, scale) in viewports) {
    testWidgets('F01 history filter tiles do not overflow · $name',
        skip: !realFonts, (tester) async {
      await pumpAt(tester, size, scale, const BuktiPendaftaranScreen());
      await tester.pumpAndSettle();
      expectNoLayoutErrors(tester);
      for (final label in ['Menunggu', 'Disetujui', 'Ditolak']) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.maxLines, 1, reason: '$label stays on one line');
      }
    });

    testWidgets('F02 about dialog title stays inside the dialog · $name',
        skip: !realFonts, (tester) async {
      await pumpAt(tester, size, scale, const ProfilUserScreen(active: false));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Tentang Aplikasi'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Tentang Aplikasi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tentang Aplikasi'));
      await tester.pumpAndSettle();
      expectNoLayoutErrors(tester);
      final dialog = tester.getRect(find.byType(AlertDialog));
      final title = tester.getRect(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Wisata Daerahku')));
      expect(title.right, lessThanOrEqualTo(dialog.right));
    });

    testWidgets(
        'F03/SR01/SR02 explore header, clear search, categories · $name',
        skip: !realFonts, (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpAt(tester, size, scale, const CariWisataScreen(active: false));
      await tester.pumpAndSettle();
      expectNoLayoutErrors(tester);
      final subtitle =
          tester.getRect(find.text('Temukan tujuan, pilih pengalamanmu.'));
      final field = tester.getRect(find.byType(TextField));
      expect(subtitle.bottom, lessThanOrEqualTo(field.top),
          reason: 'subtitle must not sit under the search field');
      final title = tester.getRect(find.text('Jelajah'));
      final pill = tester.getRect(find.textContaining('destinasi tersedia'));
      expect(title.top, greaterThanOrEqualTo(pill.bottom),
          reason: 'title must not collide with the toolbar pill');

      // SR02: the category chip is a selectable button with a 48 dp target.
      final chip = find.ancestor(
          of: find.text('Semua'), matching: find.byType(GestureDetector));
      expect(tester.getSize(chip.first).height, greaterThanOrEqualTo(48));
      expect(
          tester.getSemantics(find.text('Semua')),
          matchesSemantics(
              label: 'Semua',
              isButton: true,
              isSelected: true,
              hasSelectedState: true,
              hasTapAction: true));

      // SR01: clear button announces its action.
      await tester.enterText(find.byType(TextField), 'pantai');
      await tester.pump();
      expect(find.byTooltip('Hapus pencarian'), findsOneWidget);
      await tester.tap(find.byTooltip('Hapus pencarian'));
      await tester.pump();
      expect(find.byTooltip('Hapus pencarian'), findsNothing);
      await tester.pumpAndSettle();
      semantics.dispose();
    });

    testWidgets('F04 facility empty state stays clear of the FAB · $name',
        skip: !realFonts, (tester) async {
      final session = await adminSession(
          (_) async => jsonResponse(pageEnvelope([])),
          role: 2);
      await pumpAt(
          tester,
          size,
          scale,
          KelolaFasilitasScreen(
              repository: repositoryFor(session), session: session));
      await tester.pumpAndSettle();
      expectNoLayoutErrors(tester);
      final scrollable = find.byType(Scrollable).first;
      // Large text may push the message below the fold; it must scroll into
      // view above the button rather than stay hidden behind it.
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final message = tester.getRect(find
          .text('Tambahkan fasilitas pertama untuk dipilih pada destinasi.'));
      final fab = tester.getRect(find.byKey(const ValueKey('add-facility')));
      expect(message.bottom, lessThanOrEqualTo(fab.top));
    });

    testWidgets('SR04 long admin accounts stay readable · $name',
        skip: !realFonts, (tester) async {
      Map<String, dynamic> account(String guid, String place) => {
            'guid': guid,
            'name': 'Administrator Destinasi Wisata $place Kabupaten',
            'email':
                'administrator.destinasi.wisata.$place@dinas-pariwisata.example.test',
            'role': 1,
            'status': 'active',
          };
      final session = await adminSession(
          (_) async => jsonResponse(pageEnvelope([
                account('a', 'pantai'),
                account('b', 'gunung'),
              ])),
          role: 2,
          guid: 'me');
      await pumpAt(
          tester,
          size,
          scale,
          KelolaAdminScreen(
              repository: repositoryFor(session),
              session: session,
              ownGuid: 'me'));
      await tester.pumpAndSettle();
      expectNoLayoutErrors(tester);
      // Both actions remain reachable and labelled on the compact card.
      for (final key in ['role-a', 'status-a']) {
        final button = find.byKey(ValueKey(key));
        await tester.ensureVisible(button);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(40));
      }
      // The part that tells the two accounts apart must be visible.
      for (final place in ['pantai', 'gunung']) {
        final email = find.textContaining('wisata.$place@');
        await tester.ensureVisible(email);
        final text = tester.widget<Text>(email);
        final painter = TextPainter(
            text: TextSpan(
                text: text.data,
                style: DefaultTextStyle.of(tester.element(email))
                    .style
                    .merge(text.style)),
            maxLines: text.maxLines,
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.linear(scale))
          ..layout(maxWidth: tester.getSize(email).width);
        expect(painter.didExceedMaxLines, isFalse,
            reason:
                '$place email must not be cut before the distinguishing part');
        painter.dispose();
      }
    });
  }

  testWidgets('F06 status bar icons follow the surface behind them',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
            size: Size(393, 852), padding: EdgeInsets.only(top: 24)),
        child: ScrollAwareStatusBar(
          builder: (context, key) => ListView(children: [
            SizedBox(
                key: key,
                height: 300,
                child: const ColoredBox(color: Colors.indigo)),
            const SizedBox(height: 2000),
          ]),
        ),
      ),
    ));
    Brightness? icons() => tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find.byType(AnnotatedRegion<SystemUiOverlayStyle>))
        .value
        .statusBarIconBrightness;
    expect(icons(), Brightness.light, reason: 'dark header at the top');
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(icons(), Brightness.light, reason: 'header still under the bar');
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(icons(), Brightness.dark, reason: 'light page under the bar');
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(icons(), Brightness.light);
  });

  testWidgets('F09 long notification is clamped and fully readable on demand',
      (tester) async {
    final longBody = List.generate(
            12, (i) => 'Ketentuan $i: tunjukkan QR saat masuk destinasi.')
        .join(' ');
    final session = await users.signedInSession((request) async {
      if (request.url.path.endsWith('unread-count')) {
        return jsonResponse({
          'data': {'unread_count': 2}
        });
      }
      return jsonResponse({
        'data': [
          {
            'guid': 'long',
            'title': 'QR tiket tersedia',
            'body': longBody,
            'read_at': null,
            'created_at': '2026-11-02T00:00:00Z',
          },
          {
            'guid': 'short',
            'title': 'Pendaftaran diperbarui',
            'body': 'Status diperbarui.',
            'read_at': null,
            'created_at': '2026-11-02T00:00:00Z',
          },
        ],
        'meta': {'last_page': 1},
      });
    });
    final state = NotificationState(ApiClient(session));
    addTearDown(state.dispose);
    await state.refresh();
    await pumpAt(tester, const Size(393, 852), 1.0,
        NotifikasiScreen(state: state, active: false));
    await tester.pumpAndSettle();
    final body = find.text(longBody);
    expect(tester.widget<Text>(body).maxLines, 3);
    expect(find.text('Lihat selengkapnya'), findsOneWidget,
        reason: 'only the long notification gets a toggle');
    expect(find.text('Status diperbarui.'), findsOneWidget);
    await tester.tap(find.text('Lihat selengkapnya'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(body).maxLines, isNull);
    expect(find.text('Ringkas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('F10 camera button reflects the running camera', (tester) async {
    final original = MobileScannerPlatform.instance;
    MobileScannerPlatform.instance = _CameraPlatform();
    addTearDown(() => MobileScannerPlatform.instance = original);
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/scope')) {
        return jsonResponse({
          'data': {
            'global': false,
            'destinations': [
              {'guid': 'd1'}
            ]
          }
        });
      }
      return jsonResponse({'message': 'tidak dipakai'}, 422);
    }, role: 1);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                AdminTicketScannerScreen(repository: repositoryFor(session)))));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('scanner-camera-button'));
    await tester.ensureVisible(button);
    expect(find.descendant(of: button, matching: find.text('Kamera aktif')),
        findsOneWidget);
    expect(find.text('Aktifkan kamera'), findsNothing);
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('SR03 hero gallery photo announces fullscreen action',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final session = await adminSession((_) async => http.Response.bytes(
        galleryPng, 200,
        headers: {'content-type': 'image/png'}));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                height: 320,
                child: DestinationHeroGallery(
                    images: pictures(), repository: repositoryFor(session))))));
    await tester.pumpAndSettle();
    expect(
        find.bySemanticsLabel(
            RegExp(r'^Foto 1 dari 3\. Buka galeri layar penuh')),
        findsOneWidget);
    semantics.dispose();
  });
}
