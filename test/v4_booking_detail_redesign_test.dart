import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/screens/user/bukti_pendaftaran_screen.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'user_support.dart';

class _DetailRepository extends BusinessRepository {
  _DetailRepository(
    AuthSession session, {
    required this.value,
    required this.issuedTicket,
    this.issuedInvoice = false,
    this.documentsFailure = false,
  }) : super(ApiClient(session));

  final Booking value;
  final bool issuedTicket;
  final bool issuedInvoice;
  final bool documentsFailure;

  @override
  Future<Booking> booking(String guid) async => value;

  @override
  Future<BookingDocuments> bookingDocuments(String guid) async {
    if (documentsFailure) {
      throw const ApiException('Koneksi belum tersedia.');
    }
    return BookingDocuments({
      'invoice': issuedInvoice ? {'url': '/documents/invoice'} : null,
      'ticket': issuedTicket ? {'url': '/documents/ticket'} : null,
    });
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('entry tickets only load after server verifies payment as paid',
      (tester) async {
    for (final paymentStatus in [
      null,
      'unverified',
      'pending',
      'refunded',
      'paid'
    ]) {
      var ticketRequests = 0;
      final session = await signedInSession((request) async {
        expect(request.url.path, endsWith('/bookings/booking-1/tickets'));
        ticketRequests++;
        return jsonResponse({
          'data': {
            'booking_guid': 'booking-1',
            'ticket_state': 'scheduled',
            'quantity': 2,
            'checked_in_count': 0,
            'tickets': [],
          },
        });
      });
      final resource = bookingJson(status: 'confirmed');
      if (paymentStatus != null) resource['payment_status'] = paymentStatus;
      final repository = _DetailRepository(
        session,
        value: Booking(resource),
        issuedTicket: true,
      );
      await tester.pumpWidget(MaterialApp(
        home: BookingTicketScreen(
          key: ValueKey(paymentStatus),
          bookingGuid: 'booking-1',
          repository: repository,
        ),
      ));
      await tester.pumpAndSettle();

      final paid = paymentStatus == 'paid';
      expect(find.text('Tiket masuk'), paid ? findsOneWidget : findsNothing,
          reason: '$paymentStatus');
      expect(ticketRequests, paid ? 1 : 0, reason: '$paymentStatus');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('detail maps server statuses and titles from issued ticket only',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const widths = [320.0, 390.0, 430.0];

    const scenarios = <(String, String, String, bool, bool)>[
      (
        'pending_approval',
        'Menunggu persetujuan',
        'Pendaftaran menunggu persetujuan pengelola.',
        false,
        false,
      ),
      (
        'awaiting_payment',
        'Menunggu pembayaran',
        'Selesaikan pembayaran hanya melalui instruksi resmi yang tersedia. Pembayaran belum dikonfirmasi.',
        false,
        false,
      ),
      (
        'payment_verification',
        'Verifikasi pembayaran',
        'Pembayaran sedang diverifikasi dan belum dipastikan diterima.',
        false,
        false,
      ),
      (
        'payment_review',
        'Peninjauan pembayaran',
        'Pembayaran sedang diverifikasi dan belum dipastikan diterima.',
        false,
        false,
      ),
      (
        'confirmed',
        'Disetujui',
        'Pendaftaran telah dikonfirmasi. Dokumen tiket belum tersedia.',
        false,
        false,
      ),
      (
        'confirmed',
        'Disetujui',
        'Pendaftaran telah dikonfirmasi. Dokumen tiket belum tersedia.',
        false,
        true,
      ),
      (
        'confirmed',
        'Disetujui',
        'Tiket telah diterbitkan dan tersedia pada bagian Dokumen.',
        true,
        false,
      ),
      ('rejected', 'Ditolak', 'Pendaftaran tidak disetujui.', false, false),
      (
        'expired',
        'Kedaluwarsa',
        'Pendaftaran telah kedaluwarsa.',
        false,
        false
      ),
      (
        'cancelled',
        'Dibatalkan',
        'Pendaftaran telah dibatalkan.',
        false,
        false
      ),
      (
        'future_status',
        'future_status',
        'Informasi lanjutan belum tersedia untuk status ini.',
        false,
        false,
      ),
    ];

    for (var i = 0; i < scenarios.length; i++) {
      final (status, label, nextStep, ticket, invoice) = scenarios[i];
      final width = widths[i % widths.length];
      tester.view.physicalSize = Size(width, 740);
      final bookingNumber = status == 'future_status'
          ? 'BK-000000000000000000000000000000000000'
          : 'BK-0001';
      final session = await signedInSession(
          (_) async => jsonResponse({'data': <String, dynamic>{}}));
      final resource = bookingJson(status: status, number: bookingNumber)
        ..['visitor_name'] =
            'Nama pengunjung dengan keterangan panjang untuk menguji layout';
      final repository = _DetailRepository(
        session,
        value: Booking(resource),
        issuedTicket: ticket,
        issuedInvoice: invoice,
      );
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 740),
            textScaler: TextScaler.linear(width == 320 ? 1.8 : 1),
            disableAnimations: true,
          ),
          child: BookingTicketScreen(
            key: ValueKey('detail-$i'),
            bookingGuid: 'booking-1',
            repository: repository,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text(label), findsWidgets, reason: status);
      expect(find.text(nextStep), findsOneWidget, reason: status);
      expect(find.text('10 Maret 2027'), findsOneWidget, reason: status);
      expect(find.text('Rp20.000'), findsOneWidget, reason: status);
      expect(find.text(bookingNumber), findsOneWidget, reason: status);
      expect(find.text('Bayar sekarang'), findsNothing);
      expect(find.text(ticket ? 'Detail Tiket' : 'Detail Pendaftaran'),
          findsOneWidget,
          reason: status);
      expect(tester.takeException(), isNull, reason: status);
    }
  });

  testWidgets('failed document lookup does not imply ticket absence',
      (tester) async {
    final session = await signedInSession(
        (_) async => jsonResponse({'data': <String, dynamic>{}}));
    final repository = _DetailRepository(
      session,
      value: Booking(bookingJson(status: 'confirmed')),
      issuedTicket: false,
      documentsFailure: true,
    );
    await tester.pumpWidget(MaterialApp(
        home: BookingTicketScreen(
            bookingGuid: 'booking-1', repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('Detail Pendaftaran'), findsOneWidget);
    expect(
        find.text(
            'Pendaftaran telah dikonfirmasi. Ketersediaan dokumen tiket belum dapat diperiksa.'),
        findsOneWidget);
    expect(find.text('Dokumen belum diterbitkan.'), findsNothing);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
