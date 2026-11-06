import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/screens/daftar_kunjungan_screen.dart';
import 'package:wisata_daerahku/screens/daftar_wisata_screen.dart';
import 'package:wisata_daerahku/screens/detail_wisata_screen.dart';
import 'package:wisata_daerahku/screens/kelola_kuota_screen.dart';
import 'package:wisata_daerahku/screens/operations_dashboard.dart';
import 'package:wisata_daerahku/screens/tambah_wisata_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'package:wisata_daerahku/theme/app_colors.dart';
import 'package:wisata_daerahku/widgets/api_image.dart';
import 'package:wisata_daerahku/widgets/destination_hero_gallery.dart';
import 'package:wisata_daerahku/widgets/destination_location_map_preview.dart';
import 'admin_test_support.dart';
import 'gallery_test_support.dart' show galleryPng;

Map<String, dynamic> destinationFixture(
        {String guid = 'd1', bool active = true, bool gallery = false}) =>
    {
      'guid': guid,
      'name': 'Pantai dari server $guid',
      'location': 'Lokasi server dengan nama panjang untuk layar kecil',
      'description': 'Deskripsi asli dari API yang dipilih.',
      'ticket_price': 25000,
      'currency': 'IDR',
      'is_active': active,
      'gallery_version': 4,
      'rating_count': 1,
      'rating_average': 4.0,
      'facilities': [
        {'guid': 'f1', 'name': 'Parkir', 'icon_key': 'parking'}
      ],
      'images': [
        if (gallery)
          for (final sequence in [2, 1])
            {
              'guid': '$guid-photo-$sequence',
              'sequence': sequence,
              'urls': {
                for (final variant in ['thumbnail', 'display', 'fullscreen'])
                  variant: 'destinations/$guid/images/$sequence/$variant'
              },
            }
      ],
    };

Widget app(Widget child, {double scale = 1.3}) => MaterialApp(
      theme: AppColors.operationsTheme,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale), disableAnimations: true),
          child: RepaintBoundary(
              key: const ValueKey('v3-fixture-frame'), child: child!)),
      home: child is DaftarWisataScreen && child.embedded
          ? Scaffold(
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16), child: child))
          : child,
    );

void surface(WidgetTester tester, [Size size = const Size(393, 852)]) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 250,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder keyed(String key) => find.byKey(ValueKey(key));

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('V3_CAPTURE')) return;
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(keyed('v3-fixture-frame'));
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('qa/admin-role1-kelola-preview-v3/screenshots');
    await directory.create(recursive: true);
    await File('${directory.path}/fixture-$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<AuthSession> fixtureSession(List<http.Request> log,
        {bool Function()? isActive}) =>
    adminSession((request) async {
      final path = request.url.path;
      if (path.endsWith('/categories') ||
          path.endsWith('/facilities') ||
          path.endsWith('/quotas') ||
          path.endsWith('/reviews')) {
        return jsonResponse(pageEnvelope([]));
      }
      if (path.endsWith('/admin/destinations')) {
        return jsonResponse(pageEnvelope([
          destinationFixture(active: isActive?.call() ?? true),
        ]));
      }
      if (request.method == 'GET' && path.endsWith('/d1')) {
        return jsonResponse({'data': destinationFixture()});
      }
      return jsonResponse(pageEnvelope([]));
    }, role: 1, log: log);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final weight in [400, 500, 600, 700, 800]) {
      final loader =
          FontLoader('PlusJakartaSans_${weight == 400 ? 'regular' : weight}');
      loader.addFont(File('artifacts/phase1a-visual/font-$weight.ttf')
          .readAsBytes()
          .then(ByteData.sublistView));
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons');
    final config =
        jsonDecode(await File('.dart_tool/package_config.json').readAsString());
    final sdk = Directory.fromUri(Uri.parse(config['flutterRoot'] as String));
    icons.addFont(File.fromUri(sdk.uri.resolve(
            'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'))
        .readAsBytes()
        .then(ByteData.sublistView));
    await icons.load();
  });
  setUp(ApiImage.clearCache);

  testWidgets(
      'hub loads every page and refetches server after existing editor success',
      (tester) async {
    surface(tester);
    final log = <http.Request>[];
    var edited = false;
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/admin/destinations')) {
        final page = int.parse(request.url.queryParameters['page']!);
        return jsonResponse(pageEnvelope([
          {
            ...destinationFixture(guid: 'd$page'),
            if (page == 2 && edited) 'name': 'Nama terbaru dari server'
          }
        ], page: page, last: 2, total: 2));
      }
      if (request.url.path.endsWith('/d2')) {
        return jsonResponse({'data': destinationFixture(guid: 'd2')});
      }
      return jsonResponse(pageEnvelope([]));
    }, role: 1, log: log);
    await tester.pumpWidget(app(DaftarWisataScreen(
        mode: 'manage',
        embedded: true,
        repository: repositoryFor(session),
        session: session)));
    await tester.pumpAndSettle();
    expect(keyed('v3-card-d1'), findsOneWidget);
    expect(keyed('v3-card-d2'), findsOneWidget);
    await tap(tester, keyed('v3-manage-d2'));
    await tap(tester, keyed('v3-action-edit'));
    expect(
        tester
            .widget<TambahWisataScreen>(find.byType(TambahWisataScreen))
            .wisataEdit!
            .id,
        'd2');
    edited = true;
    Navigator.of(tester.element(find.byType(TambahWisataScreen))).pop(true);
    await tester.pumpAndSettle();
    expect(find.text('Nama terbaru dari server'), findsOneWidget);
    expect(
        log
            .where((r) => r.url.path.endsWith('/admin/destinations'))
            .map((r) => r.url.queryParameters['page']),
        ['1', '2', '1', '2']);
    expect(log.where((r) => r.method != 'GET'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty assigned hub shows no dummy card or preview',
      (tester) async {
    surface(tester);
    final session = await adminSession(
        (_) async => jsonResponse(pageEnvelope([])),
        role: 1);
    await tester.pumpWidget(app(DaftarWisataScreen(
        mode: 'manage',
        embedded: true,
        repository: repositoryFor(session),
        session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada destinasi untuk pencarian atau status ini.'),
        findsOneWidget);
    expect(find.text('Preview'), findsNothing);
    expect(find.byType(DetailWisataScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'integrated Kinerja Kelola preserves query across segment switches',
      (tester) async {
    surface(tester, const Size(360, 800));
    final log = <http.Request>[];
    final session = await fixtureSession(log);
    await tester.pumpWidget(app(OperationsReportScreen(
        section: 'destinations',
        repository: repositoryFor(session),
        session: session)));
    await tester.pumpAndSettle();
    await tap(tester, find.widgetWithText(TextButton, 'Kelola'));
    await tester.enterText(keyed('v3-search'), 'Pantai');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await capture(tester, 'integrated-kelola-360-scale13');
    await tap(tester, find.widgetWithText(TextButton, 'Kinerja'));
    expect(keyed('v3-search'), findsNothing);
    expect(
        TickerMode.valuesOf(tester
                .element(find.byType(DaftarWisataScreen, skipOffstage: false)))
            .enabled,
        isFalse);
    await tap(tester, find.widgetWithText(TextButton, 'Kelola'));
    expect(
        TickerMode.valuesOf(tester.element(find.byType(DaftarWisataScreen)))
            .enabled,
        isTrue);
    expect(tester.widget<TextField>(keyed('v3-search')).controller!.text,
        'Pantai');
    expect(keyed('v3-preview-d1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview fits 360x800 at text scale 1.3', (tester) async {
    surface(tester, const Size(360, 800));
    final log = <http.Request>[];
    final session = await fixtureSession(log);
    await tester.pumpWidget(app(DetailWisataScreen(
        wisata: Wisata.fromDestination(Destination(destinationFixture())),
        adminPreview: true,
        session: session,
        repository: repositoryFor(session))));
    await tester.pumpAndSettle();
    await capture(tester, 'preview-360-scale13');
    await tap(tester, find.text('Lihat Semua'));
    expect(find.text('Belum ada ulasan.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(log.where((r) => r.method != 'GET'), isEmpty);
  });

  testWidgets('Kelola reference keeps compact footer at default text scale',
      (tester) async {
    surface(tester, const Size(360, 800));
    final session = await fixtureSession(<http.Request>[]);
    await tester.pumpWidget(app(
        DaftarWisataScreen(
            mode: 'manage',
            embedded: true,
            repository: repositoryFor(session),
            session: session),
        scale: 1));
    await tester.pumpAndSettle();
    expect(find.text('Kelola lokasi dalam penugasan Anda'), findsOneWidget);
    expect(find.text('Cari nama destinasi...'), findsOneWidget);
    final status =
        find.descendant(of: keyed('v3-card-d1'), matching: find.text('Aktif'));
    expect(tester.getCenter(status).dy,
        closeTo(tester.getCenter(keyed('v3-preview-d1')).dy, 1));
    expect(find.text('Rp25.000'), findsOneWidget);
    await capture(tester, 'reference-kelola-360-scale10');
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets('compact hub explicit actions fit $size at text scale 1.3',
        (tester) async {
      surface(tester, size);
      final log = <http.Request>[];
      final session = await fixtureSession(log);
      await tester.pumpWidget(app(DaftarWisataScreen(
          mode: 'manage',
          embedded: true,
          repository: repositoryFor(session),
          session: session)));
      await tester.pumpAndSettle();
      expect(log.first.url.queryParameters['status'], 'all');
      expect(find.byType(FloatingActionButton), findsNothing);
      await tap(tester, find.text('Pantai dari server d1'));
      expect(find.byType(DetailWisataScreen), findsNothing);
      expect(keyed('v3-preview-d1'), findsOneWidget);
      expect(keyed('v3-manage-d1'), findsOneWidget);
      final status = find.descendant(
          of: keyed('v3-card-d1'), matching: find.text('Aktif'));
      expect(tester.getCenter(status).dy,
          closeTo(tester.getCenter(keyed('v3-preview-d1')).dy, 1));
      expect(tester.getCenter(keyed('v3-preview-d1')).dy,
          closeTo(tester.getCenter(keyed('v3-manage-d1')).dy, 1));
      expect(find.text('Rp25.000'), findsOneWidget);
      await capture(tester, 'hub-${size.width.toInt()}-scale13');
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
      await tap(tester, keyed('v3-manage-d1'));
      expect(find.text('Kelola Pantai dari server d1'), findsOneWidget);
      expect(keyed('v3-action-preview'), findsOneWidget);
      expect(keyed('v3-action-gallery'), findsOneWidget);
      await capture(tester, 'sheet-${size.width.toInt()}-scale13');
      expect(tester.takeException(), isNull);
      expect(log.where((r) => r.method != 'GET'), isEmpty);
    });
  }

  testWidgets('preview and back preserve search and status without writes',
      (tester) async {
    surface(tester);
    final log = <http.Request>[];
    final session = await fixtureSession(log);
    await tester.pumpWidget(app(DaftarWisataScreen(
        mode: 'manage',
        embedded: true,
        repository: repositoryFor(session),
        session: session)));
    await tester.pumpAndSettle();
    await tester.enterText(keyed('v3-search'), 'Pantai');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tap(tester, keyed('v3-status-active'));
    await tap(tester, keyed('v3-preview-d1'));
    expect(
        tester
            .widget<DetailWisataScreen>(find.byType(DetailWisataScreen))
            .adminPreview,
        isTrue);
    expect(
        log.any((r) => r.url.path == '/api/v1/admin/destinations/d1'), isTrue);
    expect(find.byType(DaftarKunjunganScreen), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(keyed('v3-search')).controller!.text,
        'Pantai');
    expect(
        tester
            .widget<Semantics>(find
                .ancestor(
                    of: keyed('v3-status-active'),
                    matching: find.byType(Semantics))
                .first)
            .properties
            .selected,
        isTrue);
    expect(log.where((r) => r.method != 'GET'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final action in ['edit', 'gallery', 'quota']) {
    testWidgets('sheet $action reuses existing screen for selected GUID',
        (tester) async {
      surface(tester);
      final log = <http.Request>[];
      final session = await fixtureSession(log);
      await tester.pumpWidget(app(DaftarWisataScreen(
          mode: 'manage',
          embedded: true,
          repository: repositoryFor(session),
          session: session)));
      await tester.pumpAndSettle();
      await tap(tester, keyed('v3-manage-d1'));
      await tap(tester, keyed('v3-action-$action'));
      if (action == 'quota') {
        expect(
            tester
                .widget<KelolaKuotaScreen>(find.byType(KelolaKuotaScreen))
                .destinationGuid,
            'd1');
      } else {
        expect(
            tester
                .widget<TambahWisataScreen>(find.byType(TambahWisataScreen))
                .wisataEdit!
                .id,
            'd1');
      }
      expect(log.where((r) => r.method != 'GET'), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Tambah reuses existing create screen', (tester) async {
    surface(tester);
    final log = <http.Request>[];
    final session = await fixtureSession(log);
    await tester.pumpWidget(app(DaftarWisataScreen(
        mode: 'manage',
        embedded: true,
        repository: repositoryFor(session),
        session: session)));
    await tester.pumpAndSettle();
    await tap(tester, keyed('v3-add'));
    expect(
        tester
            .widget<TambahWisataScreen>(find.byType(TambahWisataScreen))
            .wisataEdit,
        isNull);
    expect(log.where((r) => r.method != 'GET'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final initiallyActive in [true, false]) {
    testWidgets('status $initiallyActive requires confirmation and refetches',
        (tester) async {
      surface(tester);
      final log = <http.Request>[];
      var active = initiallyActive;
      final session = await adminSession((request) async {
        if (request.method != 'GET') {
          active = !active;
          return jsonResponse({'data': destinationFixture(active: active)});
        }
        return jsonResponse(pageEnvelope([destinationFixture(active: active)]));
      }, role: 1, log: log);
      await tester.pumpWidget(app(DaftarWisataScreen(
          mode: 'manage',
          embedded: true,
          repository: repositoryFor(session),
          session: session)));
      await tester.pumpAndSettle();
      await tap(tester, keyed('v3-manage-d1'));
      await tap(tester, keyed('v3-action-status'));
      expect(log.where((r) => r.method != 'GET'), isEmpty);
      await tap(tester, find.text('Batal'));
      expect(log.where((r) => r.method != 'GET'), isEmpty);
      await tap(tester, keyed('v3-manage-d1'));
      await tap(tester, keyed('v3-action-status'));
      await tap(
          tester,
          find.widgetWithText(
              ElevatedButton, initiallyActive ? 'Nonaktifkan' : 'Aktifkan'));
      final writes = log.where((r) => r.method != 'GET').toList();
      expect(writes, hasLength(1));
      expect(writes.single.method, initiallyActive ? 'DELETE' : 'PATCH');
      expect(writes.single.url.path, '/api/v1/destinations/d1');
      expect(log.last.method, 'GET');
      expect(active, !initiallyActive);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('read-only preview keeps carousel and disables all write routes',
      (tester) async {
    surface(tester);
    late Directory tileCache;
    late BuiltInMapCachingProvider caching;
    await tester.runAsync(() async {
      tileCache = await Directory.systemTemp.createTemp('v3-map-widget-test-');
      caching = BuiltInMapCachingProvider.getOrCreateInstance(
          cacheDirectory: tileCache.path, readOnly: true);
    });
    addTearDown(() async {
      await caching.destroy();
      await tileCache.delete(recursive: true);
    });
    final log = <http.Request>[];
    final external = <MethodCall>[];
    const maps = MethodChannel('id.wisatadaerahku.app/maps');
    const launcher = MethodChannel('plugins.flutter.io/url_launcher');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [maps, launcher]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        external.add(call);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    final data = {
      ...destinationFixture(gallery: true),
      'latitude': -5.14,
      'longitude': 119.41
    };
    final session = await adminSession((request) async {
      if (request.url.path.contains('/images/')) {
        return http.Response.bytes(galleryPng, 200,
            headers: {'content-type': 'image/png'});
      }
      if (request.url.path.endsWith('/reviews')) {
        return jsonResponse(pageEnvelope([]));
      }
      return jsonResponse({'data': data});
    }, role: 1, log: log);
    await tester.pumpWidget(app(DetailWisataScreen(
        wisata: Wisata.fromDestination(Destination(data)),
        adminPreview: true,
        session: session,
        repository: repositoryFor(session))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mode Pratinjau'), findsWidgets);
    expect(find.byTooltip('Simpan favorit'), findsNothing);
    expect(find.byTooltip('Periksa favorit'), findsNothing);
    final button = find.widgetWithText(FilledButton, 'Daftar Kunjungan');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(
        tester
            .widget<DestinationHeroGallery>(find.byType(DestinationHeroGallery))
            .images
            .first
            .sequence,
        1);
    await capture(tester, 'preview-393-scale13');
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(
        tester
            .widget<DestinationHeroGallery>(find.byType(DestinationHeroGallery))
            .allowFullscreen,
        isFalse);
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenDestinationGallery), findsNothing);
    await tap(tester, find.text('Buka Google Maps'));
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Buka Google Maps'))
            .onPressed,
        isNull);
    final mapTap = tester.widget<InkWell>(find
        .ancestor(
            of: find.byType(DestinationLocationMap),
            matching: find.byType(InkWell))
        .first);
    expect(mapTap.onTap, isNull);
    await tap(tester, find.text('Lihat Semua'));
    expect(find.text('Belum ada ulasan.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(log.where((r) => r.method != 'GET'), isEmpty);
    expect(external, isEmpty);
    expect(find.byType(DaftarKunjunganScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review modal purges private rows on same-generation revoke',
      (tester) async {
    surface(tester);
    var revoked = false;
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      if (revoked) return jsonResponse({'message': 'Forbidden'}, 403);
      if (request.url.path.endsWith('/reviews')) {
        return jsonResponse(pageEnvelope([
          {
            'guid': 'r1',
            'destination_guid': 'd1',
            'destination_name': 'Pantai dari server d1',
            'rating': 4,
            'comment': 'Ulasan privat dari API'
          }
        ]));
      }
      return jsonResponse({'data': destinationFixture()});
    }, role: 1, log: log);
    await tester.pumpWidget(app(DetailWisataScreen(
        wisata: Wisata.fromDestination(Destination(destinationFixture())),
        adminPreview: true,
        session: session,
        repository: repositoryFor(session))));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Lihat Semua'));
    expect(find.text('Ulasan privat dari API'), findsOneWidget);
    final generation = session.sessionGeneration;
    revoked = true;
    session.sessionChanges.value++;
    await tester.pumpAndSettle();
    expect(session.sessionGeneration, generation);
    expect(find.text('Ulasan privat dari API'), findsNothing);
    expect(find.byType(DestinationHeroGallery), findsNothing);
    expect(log.where((r) => r.method != 'GET'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final status in [403, 404, 409]) {
    testWidgets('preview $status never falls back to stale card data',
        (tester) async {
      surface(tester);
      final log = <http.Request>[];
      final session = await adminSession(
          (_) async => jsonResponse({'message': 'Tidak tersedia'}, status),
          role: 1,
          log: log);
      await tester.pumpWidget(app(DetailWisataScreen(
          wisata: Wisata.fromDestination(Destination(destinationFixture())),
          adminPreview: true,
          session: session,
          repository: repositoryFor(session))));
      await tester.pumpAndSettle();
      expect(find.byType(DestinationHeroGallery), findsNothing);
      expect(find.text('Daftar Kunjungan'), findsNothing);
      expect(find.text('Deskripsi asli dari API yang dipilih.'), findsNothing);
      expect(log.where((r) => r.method != 'GET'), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('preview rejects response with another destination GUID',
      (tester) async {
    surface(tester);
    final session = await adminSession(
        (_) async => jsonResponse({'data': destinationFixture(guid: 'other')}),
        role: 1);
    await tester.pumpWidget(app(DetailWisataScreen(
        wisata: Wisata.fromDestination(Destination(destinationFixture())),
        adminPreview: true,
        session: session,
        repository: repositoryFor(session))));
    await tester.pumpAndSettle();
    expect(find.byType(DestinationHeroGallery), findsNothing);
    expect(
        find.textContaining('Identitas wisata tidak sesuai'), findsOneWidget);
  });

  testWidgets(
      'same-generation revoke removes private detail and ignores late response',
      (tester) async {
    surface(tester);
    final response = Completer<http.Response>();
    var requests = 0;
    var revoked = false;
    final session = await adminSession((_) async {
      requests++;
      if (requests == 1) return jsonResponse({'data': destinationFixture()});
      if (requests == 2) return response.future;
      return jsonResponse({'message': 'Forbidden'}, revoked ? 403 : 200);
    }, role: 1);
    await tester.pumpWidget(app(DetailWisataScreen(
        wisata: Wisata.fromDestination(Destination(destinationFixture())),
        adminPreview: true,
        session: session,
        repository: repositoryFor(session))));
    await tester.pumpAndSettle();
    expect(find.byType(DestinationHeroGallery), findsOneWidget);
    final generation = session.sessionGeneration;
    session.sessionChanges.value++;
    await tester.pump();
    revoked = true;
    session.sessionChanges.value++;
    await tester.pumpAndSettle();
    expect(session.sessionGeneration, generation);
    expect(find.byType(DestinationHeroGallery), findsNothing);
    response.complete(jsonResponse({'data': destinationFixture()}));
    await tester.pumpAndSettle();
    expect(find.byType(DestinationHeroGallery), findsNothing);
    expect(find.text('Deskripsi asli dari API yang dipilih.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visitor default mode retains booking route and favorite action',
      (tester) async {
    surface(tester);
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/d1')) {
        return jsonResponse({'data': destinationFixture()});
      }
      return jsonResponse(pageEnvelope([]));
    }, role: 1, log: log);
    session.role = 0;
    await tester.pumpWidget(app(DetailWisataScreen(
        wisata: Wisata.fromDestination(Destination(destinationFixture())),
        repository: repositoryFor(session))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mode Pratinjau'), findsNothing);
    final favorite = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.favorite_border_rounded));
    expect(favorite.onPressed, isNotNull);
    await tap(tester, find.text('Daftar Kunjungan'));
    expect(find.byType(DaftarKunjunganScreen), findsOneWidget);
    expect(log.where((r) => r.method != 'GET'), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
