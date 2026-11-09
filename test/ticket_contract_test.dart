import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/data/ticket_link.dart';
import 'package:wisata_daerahku/data/ticket_models.dart';
import 'package:wisata_daerahku/screens/bukti_pendaftaran_screen.dart';
import 'package:wisata_daerahku/screens/ticket_link_screen.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'user_support.dart';

const _uuid = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';

Map<String, dynamic> _entryTickets(
        {String state = 'available',
        String entitlement = 'paid',
        String from = '2027-03-05'}) =>
    {
      'state': state,
      'quantity': 2,
      'qr_available_from': from,
      'entitlement': entitlement,
    };

Map<String, dynamic> _legacyTicket({bool download = false}) => {
      'status': 'issued',
      'legacy': true,
      'admission': false,
      'download_available': download,
    };

/// Booking + documents come from the test; everything else is the supplied session handler.
class _DocsRepository extends BusinessRepository {
  _DocsRepository(AuthSession session,
      {required this.value, required this.documents})
      : super(ApiClient(session));
  final Booking value;
  final Map<String, dynamic> documents;
  int documentReads = 0;

  @override
  Future<Booking> booking(String guid) async => value;

  @override
  Future<BookingDocuments> bookingDocuments(String guid) async {
    documentReads++;
    return BookingDocuments(documents);
  }
}

http.Response _tickets({String entitlement = 'paid', String state = 'available'}) =>
    jsonResponse({
      'data': {
        'booking_guid': 'booking-1',
        'ticket_state': state,
        'qr_available_from': '2027-03-05',
        'timezone': 'Asia/Jakarta',
        'quantity': 2,
        'checked_in_count': 0,
        'entitlement': entitlement,
        'tickets': [],
      },
    });

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('BookingDocuments contract', () {
    test('reads entry_tickets and the legacy ticket flags additively', () {
      final docs = BookingDocuments({
        'invoice': null,
        'ticket': _legacyTicket(),
        'entry_tickets': _entryTickets(state: 'scheduled'),
      });
      expect(docs.entryTickets!.state, 'scheduled');
      expect(docs.entryTickets!.quantity, 2);
      expect(docs.entryTickets!.qrAvailableFrom, '2027-03-05');
      expect(docs.entryTickets!.entitlement, 'paid');
      expect(docs.ticketLegacy, isTrue);
      expect(docs.ticketAdmission, isFalse);
      expect(docs.ticketDownloadAvailable, isFalse);
    });

    test('download is offered only when the server says download_available', () {
      expect(
          BookingDocuments({'ticket': _legacyTicket(download: true)})
              .ticketDownloadAvailable,
          isTrue);
      expect(
          BookingDocuments({'ticket': _legacyTicket(download: false)})
              .ticketDownloadAvailable,
          isFalse);
      expect(BookingDocuments({'ticket': null}).ticketDownloadAvailable, isFalse);
    });

    test('an older backend (no flags, no entry_tickets) keeps the old behavior', () {
      final docs = BookingDocuments({'ticket': {'url': '/documents/ticket'}});
      expect(docs.entryTickets, isNull);
      expect(docs.ticketDownloadAvailable, isTrue);
      expect(docs.entryTicketsIssued, isTrue);
      expect(BookingDocuments({'ticket': null}).entryTicketsIssued, isFalse);
    });

    test('the legacy confirmation document never counts as an entry ticket', () {
      final docs = BookingDocuments({
        'ticket': _legacyTicket(download: true),
      });
      expect(docs.entryTicketsIssued, isFalse);
    });

    test('entry ticket state alone decides issued / scheduled / revoked', () {
      const issued = {
        'scheduled': true,
        'available': true,
        'partially_checked_in': true,
        'fully_checked_in': true,
        'awaiting_payment': false,
        'awaiting_approval': false,
        'expired': false,
        'revoked': false,
        'something_new': false,
      };
      for (final entry in issued.entries) {
        final docs = BookingDocuments({
          // Even a downloadable legacy document must not influence the answer.
          'ticket': _legacyTicket(download: true),
          'entry_tickets': _entryTickets(state: entry.key),
        });
        expect(docs.entryTicketsIssued, entry.value, reason: entry.key);
      }
    });

    test('a malformed entry_tickets object is treated as missing', () {
      expect(BookingDocuments({'entry_tickets': 'x'}).entryTickets, isNull);
      expect(BookingDocuments({'entry_tickets': {'state': 5}}).entryTickets,
          isNull);
    });

    test('tickets response exposes the explicit entitlement', () {
      final free = BookingTickets({
        'booking_guid': 'b',
        'ticket_state': 'available',
        'quantity': 1,
        'checked_in_count': 0,
        'entitlement': 'free',
        'tickets': [],
      });
      expect(free.entitlement, 'free');
      expect(free.isFree, isTrue);
      final old = BookingTickets({
        'booking_guid': 'b',
        'ticket_state': 'available',
        'quantity': 1,
        'checked_in_count': 0,
        'tickets': [],
      });
      expect(old.entitlement, isNull);
      expect(old.isFree, isFalse);
    });

    test('Booking.isFree needs an explicit zero amount, never a missing one', () {
      expect(Booking({...bookingJson(), 'total_amount': 0}).isFree, isTrue);
      expect(Booking(bookingJson()).isFree, isFalse);
      final missing = bookingJson()..remove('total_amount');
      expect(Booking(missing).isFree, isFalse);
    });
  });

  group('booking detail: documents and entry tickets', () {
    Future<_DocsRepository> pump(WidgetTester tester,
        {required Map<String, dynamic> documents,
        Map<String, dynamic>? booking,
        Future<http.Response> Function(http.Request)? handler,
        Size size = const Size(393, 900),
        double textScale = 1}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = await signedInSession(
          handler ?? (_) async => _tickets());
      final repository = _DocsRepository(session,
          value: Booking(booking ?? bookingJson(status: 'confirmed')),
          documents: documents);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: BookingTicketScreen(
              bookingGuid: 'booking-1', repository: repository)));
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets(
        'a legacy document that is not downloadable shows no row, no button and no ticket claim',
        (tester) async {
      await pump(tester, documents: {
        'invoice': null,
        'ticket': _legacyTicket(download: false),
        'entry_tickets': _entryTickets(state: 'scheduled'),
      });
      expect(find.byKey(const ValueKey('download_ticket')), findsNothing);
      expect(find.text('Dokumen tiket grup (PDF)'), findsNothing);
      expect(find.textContaining('Dokumen tiket belum tersedia'), findsNothing);
      expect(find.text('Tiket telah diterbitkan dan tersedia pada bagian Dokumen.'),
          findsNothing);
      expect(find.textContaining('5 Maret 2027'), findsOneWidget);
      expect(find.text('Detail Tiket'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'a downloadable confirmation document is labelled as not being the entry ticket',
        (tester) async {
      await pump(tester, documents: {
        'invoice': null,
        'ticket': _legacyTicket(download: true),
        'entry_tickets': _entryTickets(state: 'available'),
      });
      expect(find.byKey(const ValueKey('download_ticket')), findsOneWidget);
      expect(find.text('Dokumen tiket grup (PDF)'), findsOneWidget);
      expect(find.textContaining('bukan tiket masuk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('revoked entry tickets are reported as unusable, not as issued',
        (tester) async {
      await pump(tester, documents: {
        'invoice': null,
        'ticket': _legacyTicket(download: true),
        'entry_tickets': _entryTickets(state: 'revoked'),
      });
      expect(find.text('Tiket masuk tidak dapat digunakan.'), findsOneWidget);
      expect(find.text('Tiket telah diterbitkan dan tersedia pada bagian Dokumen.'),
          findsNothing);
      expect(find.text('Detail Pendaftaran'), findsOneWidget);
    });

    testWidgets('available entry tickets point to the entry ticket section',
        (tester) async {
      await pump(tester, documents: {
        'invoice': null,
        'ticket': null,
        'entry_tickets': _entryTickets(state: 'available'),
      });
      expect(find.textContaining('bagian Tiket masuk'), findsWidgets);
      expect(find.text('Detail Tiket'), findsOneWidget);
    });

    testWidgets('an older backend without entry_tickets keeps the previous behavior',
        (tester) async {
      await pump(tester, documents: {
        'invoice': null,
        'ticket': {'url': '/documents/ticket'},
      });
      expect(find.byKey(const ValueKey('download_ticket')), findsOneWidget);
      expect(find.text('Tiket telah diterbitkan dan tersedia pada bagian Dokumen.'),
          findsOneWidget);
      expect(find.text('Detail Tiket'), findsOneWidget);
    });

    testWidgets('no ticket anywhere keeps the previous empty copy', (tester) async {
      await pump(tester, documents: {'invoice': null, 'ticket': null});
      expect(
          find.text('Pendaftaran telah dikonfirmasi. Dokumen tiket belum tersedia.'),
          findsOneWidget);
      expect(find.text('Dokumen belum diterbitkan.'), findsOneWidget);
    });

    testWidgets('a non-downloadable legacy document alone reads as nothing issued',
        (tester) async {
      await pump(tester, documents: {
        'invoice': null,
        'ticket': _legacyTicket(download: false),
      });
      expect(find.byKey(const ValueKey('download_ticket')), findsNothing);
      expect(find.text('Dokumen belum diterbitkan.'), findsOneWidget);
    });
  });

  group('free bookings', () {
    final freeBooking = bookingJson(status: 'confirmed')
      ..['total_amount'] = 0
      ..['payment_status'] = 'unverified';

    testWidgets(
        'an approved Rp0 booking shows the entry QR section without being paid, and no payment or refund CTA',
        (tester) async {
      final paths = <String>[];
      await (() async {
        tester.view.physicalSize = const Size(393, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final session = await signedInSession((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/tickets')) {
            return _tickets(entitlement: 'free');
          }
          return jsonResponse({'message': 'unexpected'}, 404);
        });
        final repository = _DocsRepository(session,
            value: Booking(freeBooking),
            documents: {
              'invoice': null,
              'ticket': null,
              'entry_tickets': _entryTickets(entitlement: 'free'),
            });
        await tester.pumpWidget(MaterialApp(
            home: BookingTicketScreen(
                bookingGuid: 'booking-1', repository: repository)));
        await tester.pumpAndSettle();
      })();
      expect(find.text('Tiket masuk'), findsOneWidget);
      expect(paths.where((p) => p.endsWith('/bookings/booking-1/tickets')),
          hasLength(1));
      expect(find.text('Pembayaran'), findsNothing);
      expect(find.byKey(const Key('payment-open-checkout')), findsNothing);
      expect(find.byKey(const Key('refund-section')), findsNothing);
      expect(find.text('Ajukan Pengembalian Dana'), findsNothing);
      expect(paths.any((p) => p.contains('payment')), isFalse);
      expect(paths.any((p) => p.contains('refund')), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the explicit free entitlement is enough even when the amount is unknown',
        (tester) async {
      final session = await signedInSession((_) async => _tickets(entitlement: 'free'));
      final json = bookingJson(status: 'confirmed')..remove('total_amount');
      final repository = _DocsRepository(session,
          value: Booking(json),
          documents: {
            'invoice': null,
            'ticket': null,
            'entry_tickets': _entryTickets(entitlement: 'free'),
          });
      await tester.pumpWidget(MaterialApp(
          home: BookingTicketScreen(
              bookingGuid: 'booking-1', repository: repository)));
      await tester.pumpAndSettle();
      expect(find.text('Tiket masuk'), findsOneWidget);
    });

    testWidgets('a paid-amount booking that is not verified paid still has no QR section',
        (tester) async {
      var ticketRequests = 0;
      final session = await signedInSession((_) async {
        ticketRequests++;
        return _tickets();
      });
      final repository = _DocsRepository(session,
          value: Booking(bookingJson(status: 'confirmed')
            ..['payment_status'] = 'unverified'),
          documents: {
            'invoice': null,
            'ticket': null,
            'entry_tickets': _entryTickets(entitlement: 'unverified'),
          });
      await tester.pumpWidget(MaterialApp(
          home: BookingTicketScreen(
              bookingGuid: 'booking-1', repository: repository)));
      await tester.pumpAndSettle();
      expect(find.text('Tiket masuk'), findsNothing);
      expect(ticketRequests, 0);
    });
  });

  group('TicketLink parser', () {
    test('accepts exactly /tickets/{uuid}', () {
      expect(TicketLink.parse('/tickets/$_uuid')!.bookingGuid, _uuid);
    });

    test('accepts an uppercase uuid and normalises it', () {
      expect(TicketLink.parse('/tickets/${_uuid.toUpperCase()}')!.bookingGuid,
          _uuid);
    });

    test('accepts a single trailing slash', () {
      expect(TicketLink.parse('/tickets/$_uuid/')!.bookingGuid, _uuid);
    });

    test('rejects extra segments, other paths and non-uuid values', () {
      for (final name in [
        null,
        '',
        '/',
        '/tickets',
        '/tickets/',
        '/tickets/$_uuid/extra',
        '/tickets/$_uuid//',
        '/tickets//$_uuid',
        '/tickets/$_uuid/..',
        '/tickets/../$_uuid',
        '/tickets/%2e%2e/$_uuid',
        '/tickets/${_uuid.substring(0, 35)}',
        '/tickets/${_uuid}0',
        '/tickets/not-a-uuid',
        '/tickets/booking-1',
        '/tickets/${_uuid.replaceAll('-', '')}',
        '/tickets/$_uuid%00',
        '/tickets/g47ac10b-58cc-4372-a567-0e02b2c3d479',
        '/ticket/$_uuid',
        '/other/tickets/$_uuid',
        '/payment/return',
        'tickets/$_uuid',
        'https://evil.example/tickets/$_uuid',
      ]) {
        expect(TicketLink.parse(name), isNull, reason: '$name');
      }
    });

    test('rejects any query string or fragment, so no token can ride along', () {
      for (final name in [
        '/tickets/$_uuid?token=abc',
        '/tickets/$_uuid?',
        '/tickets/$_uuid/?t=1',
        '/tickets/$_uuid#frag',
        '/tickets/$_uuid?next=/admin',
      ]) {
        expect(TicketLink.parse(name), isNull, reason: name);
      }
    });
  });

  group('PendingTicketLink', () {
    test('is remembered once, consumed once and expires', () {
      var now = DateTime.utc(2027, 1, 1, 8);
      PendingTicketLink.clock = () => now;
      addTearDown(() => PendingTicketLink.clock = DateTime.now);
      PendingTicketLink.clear();
      expect(PendingTicketLink.take(), isNull);
      PendingTicketLink.remember(_uuid);
      expect(PendingTicketLink.take(), _uuid);
      expect(PendingTicketLink.take(), isNull);

      PendingTicketLink.remember(_uuid);
      now = now.add(const Duration(hours: 1));
      expect(PendingTicketLink.take(), isNull);
    });

    test('only a valid uuid can be remembered', () {
      PendingTicketLink.clear();
      PendingTicketLink.remember('../../x');
      expect(PendingTicketLink.take(), isNull);
    });
  });

  group('ticket link screen', () {
    late List<String> paths;
    int bookingStatusCode = 200;

    setUp(() {
      paths = [];
      bookingStatusCode = 200;
      PendingTicketLink.clear();
    });

    Future<BusinessRepository> signedIn() async {
      final session = await signedInSession((request) async {
        paths.add('${request.method} ${request.url.path}');
        final path = request.url.path;
        if (path.endsWith('/bookings/$_uuid')) {
          if (bookingStatusCode != 200) {
            return jsonResponse(
                {'message': 'Booking hidden detail that must not be shown'},
                bookingStatusCode);
          }
          return jsonResponse({
            'data': bookingJson(guid: _uuid, status: 'confirmed')
              ..['payment_status'] = 'paid'
          });
        }
        if (path.endsWith('/documents')) {
          return jsonResponse({
            'data': {
              'invoice': null,
              'ticket': null,
              'entry_tickets': _entryTickets(),
            }
          });
        }
        if (path.endsWith('/tickets')) {
          return jsonResponse({
            'data': {
              'booking_guid': _uuid,
              'ticket_state': 'available',
              'timezone': 'Asia/Jakarta',
              'quantity': 2,
              'checked_in_count': 0,
              'tickets': [],
            }
          });
        }
        if (path.endsWith('/payment-intent')) {
          return jsonResponse({'message': 'no'}, 404);
        }
        return jsonResponse({'message': 'not found'}, 404);
      });
      return repositoryFor(session);
    }

    Future<void> pumpLink(WidgetTester tester, BusinessRepository repository,
        {Size size = const Size(393, 852), double textScale = 1}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!),
          home: TicketLinkScreen(bookingGuid: _uuid, repository: repository)));
      await tester.pumpAndSettle();
    }

    testWidgets('loads the booking and its ticket screen from the server',
        (tester) async {
      final repository = await signedIn();
      await pumpLink(tester, repository);
      expect(find.byType(BookingTicketScreen), findsOneWidget);
      expect(find.byKey(const Key('ticket-link-not-found')), findsNothing);
      expect(find.text('Tiket masuk'), findsOneWidget);
      // The detail card refreshes the booking once more on its own; the link screen adds one read.
      expect(paths.where((p) => p == 'GET /api/v1/bookings/$_uuid'),
          isNotEmpty);
      expect(paths.where((p) => p.endsWith('/bookings/$_uuid/tickets')),
          hasLength(1));
      expect(tester.takeException(), isNull);
    });

    for (final status in [403, 404]) {
      testWidgets('$status shows a neutral not-found state without server details',
          (tester) async {
        bookingStatusCode = status;
        final repository = await signedIn();
        await pumpLink(tester, repository);
        expect(find.byKey(const Key('ticket-link-not-found')), findsOneWidget);
        expect(find.text('Tiket tidak ditemukan atau bukan milik akun ini'),
            findsOneWidget);
        expect(find.textContaining('hidden detail'), findsNothing);
        expect(find.textContaining('403'), findsNothing);
        expect(find.textContaining('404'), findsNothing);
        expect(find.byType(BookingTicketScreen), findsNothing);
        expect(paths.any((p) => p.endsWith('/tickets')), isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a server error offers a retry instead of claiming the ticket is missing',
        (tester) async {
      bookingStatusCode = 500;
      final repository = await signedIn();
      await pumpLink(tester, repository);
      expect(find.byKey(const Key('ticket-link-not-found')), findsNothing);
      expect(find.byKey(const Key('ticket-link-retry')), findsOneWidget);
      bookingStatusCode = 200;
      await tester.tap(find.byKey(const Key('ticket-link-retry')));
      await tester.pumpAndSettle();
      expect(find.byType(BookingTicketScreen), findsOneWidget);
    });

    testWidgets('a signed-out visitor is asked to log in and the link is remembered',
        (tester) async {
      final signedOut = repositoryFor(AuthSession(
          baseUrl: 'https://example.test/api/v1', store: MemoryStore()));
      await pumpLink(tester, signedOut);
      expect(find.byKey(const Key('ticket-link-needs-login')), findsOneWidget);
      expect(find.byKey(const Key('ticket-link-login')), findsOneWidget);
      expect(find.byType(BookingTicketScreen), findsNothing);
      expect(PendingTicketLink.take(), _uuid);
    });

    testWidgets('the not-found state fits 320 wide at 2.0x text scale',
        (tester) async {
      bookingStatusCode = 404;
      final repository = await signedIn();
      await pumpLink(tester, repository,
          size: const Size(320, 640), textScale: 2);
      expect(find.byKey(const Key('ticket-link-not-found')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the needs-login state fits 320 wide at 2.0x text scale',
        (tester) async {
      final signedOut = repositoryFor(AuthSession(
          baseUrl: 'https://example.test/api/v1', store: MemoryStore()));
      await pumpLink(tester, signedOut,
          size: const Size(320, 640), textScale: 2);
      expect(find.byKey(const Key('ticket-link-needs-login')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ticket link routing', () {
    late BusinessRepository repository;

    setUp(() async {
      PendingTicketLink.clear();
      repository = repositoryFor(await signedInSession((request) async {
        final path = request.url.path;
        if (path.endsWith('/bookings/$_uuid')) {
          return jsonResponse({
            'data': bookingJson(guid: _uuid, status: 'pending_approval')
          });
        }
        if (path.endsWith('/documents')) {
          return jsonResponse({
            'data': {'invoice': null, 'ticket': null}
          });
        }
        return jsonResponse({'message': 'not found'}, 404);
      }));
    });

    Widget app({String? initialRoute}) => MaterialApp(
        initialRoute: initialRoute ?? '/',
        home: const Scaffold(body: Text('HOME')),
        onGenerateRoute: (settings) =>
            ticketLinkRoute(settings, repository: () => repository));

    testWidgets('cold start opens the ticket link screen above home', (tester) async {
      await tester.pumpWidget(app(initialRoute: '/tickets/$_uuid'));
      await tester.pumpAndSettle();
      expect(find.byType(TicketLinkScreen), findsOneWidget);
      expect(find.byType(BookingTicketScreen), findsOneWidget);
    });

    testWidgets('warm start (platform pushRoute) opens the ticket link screen',
        (tester) async {
      await tester.pumpWidget(app());
      expect(find.text('HOME'), findsOneWidget);
      await tester.binding.handlePushRoute('/tickets/$_uuid');
      await tester.pumpAndSettle();
      expect(find.byType(TicketLinkScreen), findsOneWidget);
    });

    test('everything that is not a strict ticket link falls through', () {
      for (final name in [
        '/',
        '/payment/return',
        '/tickets/not-a-uuid',
        '/tickets/$_uuid/extra',
        '/tickets/$_uuid?token=abc',
      ]) {
        expect(ticketLinkRoute(RouteSettings(name: name)), isNull, reason: name);
      }
    });
  });
}
