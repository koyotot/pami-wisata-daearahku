import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/data/favorite_state.dart';
import 'package:wisata_daerahku/screens/beranda_user_screen.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'package:wisata_daerahku/theme/app_colors.dart';
import 'package:wisata_daerahku/widgets/api_image.dart';
import 'user_support.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('home chooses payment, pending, then nearest future confirmed booking',
      () {
    final now = DateTime(2027, 3, 1);
    final confirmed = Booking(bookingJson(status: 'confirmed'));
    final pending = Booking(bookingJson(guid: 'pending'));
    final payment =
        Booking(bookingJson(guid: 'payment', status: 'awaiting_payment'));
    expect(
        selectHomeBooking([confirmed, pending, payment], now), same(payment));
    expect(selectHomeBooking([confirmed, pending], now), same(pending));
    final earlier = Booking({
      ...bookingJson(guid: 'earlier', status: 'confirmed'),
      'visit_date': '2027-03-02'
    });
    expect(selectHomeBooking([confirmed, earlier], now), same(earlier));
    expect(
        selectHomeBooking([
          Booking({...confirmed.json, 'checked_in_at': '2027-03-01T01:00:00Z'}),
          Booking({...confirmed.json, 'visit_date': '2027-02-01'}),
          Booking(bookingJson(status: 'cancelled'))
        ], now),
        isNull);
  });

  for (final width in [320.0, 430.0]) {
    testWidgets('dashboard compact $width, real sections and refresh guards',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pending = Completer<void>();
      var bookingCalls = 0;
      var favoriteCalls = 0;
      var destinationCalls = 0;
      var journeyDestinationCalls = 0;
      var fail = false;
      var emptyBookings = false;
      var bookingStatus = 'awaiting_payment';
      var failBookings = false;
      final session = await signedInSession((request) async {
        if (request.url.path.contains('/media/')) {
          return jsonResponse({}, 404);
        }
        if (request.url.path.endsWith('/bookings')) {
          bookingCalls++;
          await pending.future;
          if (failBookings) throw const ApiException('Offline');
          return jsonResponse({
            'data': emptyBookings
                ? []
                : [
                    {
                      ...bookingJson(status: bookingStatus),
                      'visit_date': '2099-11-07'
                    }
                  ]
          });
        }
        if (request.url.path.endsWith('/favorites')) {
          favoriteCalls++;
          return jsonResponse({'data': []});
        }
        if (request.url.path.endsWith('/destinations/dest-1')) {
          journeyDestinationCalls++;
          return jsonResponse({
            'data': {
              'guid': 'dest-1',
              'name': 'Pantai Test',
            }
          });
        }
        destinationCalls++;
        expect(request.url.queryParameters['sort'], '-created_at');
        expect(request.url.queryParameters['per_page'], '4');
        if (fail) throw const ApiException('Offline');
        return jsonResponse({
          'data': List.generate(
              4,
              (i) => {
                    'guid': 'd$i',
                    'name': 'Destinasi $i',
                    'location': 'Daerah tujuan',
                    'is_active': true,
                    if (i == 0)
                      'images': [
                        for (final sequence in [2, 1])
                          {
                            'guid': 'image-$sequence',
                            'sequence': sequence,
                            'urls': {
                              'thumbnail': '/media/thumb-$sequence',
                              'display': '/media/display-$sequence',
                              'fullscreen': '/media/full-$sequence',
                            }
                          },
                      ],
                  })
        });
      });
      final repo = repositoryFor(session);
      final favorites = FavoriteState(repository: repo);
      var explore = 0;
      await tester.pumpWidget(MaterialApp(
          theme: AppColors.visitorTheme,
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 900),
                  padding: const EdgeInsets.only(bottom: 88),
                  textScaler: const TextScaler.linear(1.6)),
              child: BerandaUserScreen(
                  repository: repo,
                  favorites: favorites,
                  onExplore: () => explore++,
                  onHistory: () {}))));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Memuat perjalanan…'), findsOneWidget);
      expect(favoriteCalls, 1);
      expect(bookingCalls, 1);
      final refresh =
          tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      await refresh.onRefresh();
      expect(bookingCalls, 1);
      pending.complete();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Menunggu pembayaran'), findsOneWidget);
      expect(find.text('7 Nov 2099'), findsOneWidget);
      expect(find.text('2 tiket'), findsOneWidget);
      expect(find.text('Lihat Detail Pembayaran'), findsOneWidget);
      for (final state in [
        (
          'pending_approval',
          'Menunggu persetujuan',
          'Pendaftaranmu sedang ditinjau pengelola.',
          'Lihat Status Pendaftaran'
        ),
        (
          'confirmed',
          'Tiket dikonfirmasi',
          'Tiketmu sudah terkonfirmasi. Siap berkunjung!',
          'Lihat Detail Tiket'
        ),
        (
          'payment_review',
          'Peninjauan pembayaran',
          'Pembayaran sedang diproses. Status ini belum berarti pembayaran diterima.',
          'Lihat Status Pendaftaran'
        ),
        (
          'payment_verification',
          'Verifikasi pembayaran',
          'Pembayaran sedang diproses. Status ini belum berarti pembayaran diterima.',
          'Lihat Status Pendaftaran'
        ),
      ]) {
        bookingStatus = state.$1;
        await refresh.onRefresh();
        await tester.pump();
        expect(find.text(state.$2), findsOneWidget);
        expect(find.text(state.$3), findsOneWidget);
        expect(find.text(state.$4), findsOneWidget);
        expect(
            tester
                .widget<ElevatedButton>(find.ancestor(
                    of: find.text(state.$4),
                    matching: find.byType(ElevatedButton)))
                .onPressed,
            isNotNull);
        expect(tester.takeException(), isNull);
      }

      expect(journeyDestinationCalls, 1);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(GridView), findsNothing);
      expect(find.text('Favorit Kamu'), findsNothing);
      expect(find.text('Destinasi 0'), findsOneWidget);
      expect(find.text('Destinasi 1'), findsOneWidget);
      expect(find.text('Destinasi 2'), findsOneWidget);
      expect(find.text('Destinasi pilihan'), findsOneWidget);
      final firstMini = tester.getTopLeft(find.text('Destinasi 1'));
      final secondMini = tester.getTopLeft(find.text('Destinasi 2'));
      expect(firstMini.dy, secondMini.dy);
      expect(secondMini.dx, greaterThan(firstMini.dx));
      expect(find.text('Destinasi 3'), findsNothing);
      expect(
          tester
              .widgetList<ApiImage>(find.byType(ApiImage))
              .where((image) => image.imageUrl == '/media/display-1'),
          hasLength(1));
      await tester.scrollUntilVisible(find.text('Masih ingin eksplorasi?'), 400,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Masih ingin eksplorasi?'));
      expect(explore, 1);
      final scrollable =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      final banner = find.ancestor(
          of: find.text('Masih ingin eksplorasi?'), matching: find.byType(Ink));
      expect(tester.getBottomRight(banner).dy, closeTo(900 - 88 - 16, 1));
      expect(tester.takeException(), isNull);
      emptyBookings = true;
      await refresh.onRefresh();
      await tester.pump();
      expect(find.text('Petualangan pertamamu menanti'), findsOneWidget);
      await favorites.favorites.load(() async => [
            Favorite({
              'guid': 'single',
              'destination': {
                'guid': 'single-destination',
                'name': 'Satu favorit',
                'location': 'Lokasi favorit',
                'is_active': true,
              },
            })
          ]);
      await tester.pump();
      expect(find.text('Satu favorit'), findsOneWidget);
      expect(find.text('Lihat Destinasi \u2192'), findsOneWidget);
      expect(
          find.byWidgetPredicate((widget) =>
              widget is Semantics &&
              widget.properties.label == 'Destinasi favorit'),
          findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(tester.takeException(), isNull);
      await favorites.favorites.load(() async => List.generate(
          6,
          (i) => Favorite({
                'guid': 'f$i',
                'destination': {
                  'guid': 'd$i',
                  'name': 'Favorit $i',
                  'location': 'Lokasi favorit',
                  'is_active': true,
                }
              })));
      await tester.pump();
      final carousels =
          tester.widgetList<ListView>(find.byType(ListView)).toList();
      expect(carousels.first.childrenDelegate.estimatedChildCount, 11);
      expect(find.text('Favorit Kamu'), findsOneWidget);
      failBookings = true;
      fail = true;
      await refresh.onRefresh();
      await tester.pump();
      expect(find.text('Inspirasi belum dapat diperbarui.'), findsOneWidget);
      expect(find.text('Perjalanan belum dapat diperbarui.'), findsOneWidget);
      expect(destinationCalls, greaterThan(1));
      await tester.pumpWidget(const SizedBox.shrink());
      favorites.dispose();
      session.client.close();
    });
  }
}
