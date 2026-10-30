import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/booking_state.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'user_support.dart';

void main() {
  test('availability sends visit_date with Bearer and parses server numbers',
      () async {
    final requests = <http.Request>[];
    final session = await signedInSession((request) async {
      requests.add(request);
      return jsonResponse({
        'data': [availabilityJson(capacity: 10, allocated: 7)]
      });
    });
    final rows = await repositoryFor(session)
        .availability('dest-1', visitDate: '2027-03-10');
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/api/v1/destinations/dest-1/availability');
    expect(requests.single.url.queryParameters, {'visit_date': '2027-03-10'});
    expect(requests.single.headers['Authorization'], 'Bearer access');
    expect(rows.single.capacity, 10);
    expect(rows.single.allocated, 7);
    expect(rows.single.remaining, 3);
    expect(rows.single.isOpen, isTrue);
    expect(rows.single.status, 'open');
  });

  test('availability range uses from/to and does not send visit_date',
      () async {
    final requests = <http.Request>[];
    final session = await signedInSession((request) async {
      requests.add(request);
      return jsonResponse({'data': []});
    });
    final rows = await repositoryFor(session)
        .availability('dest-1', from: '2027-03-01', to: '2027-03-31');
    expect(rows, isEmpty);
    expect(requests.single.url.queryParameters,
        {'from': '2027-03-01', 'to': '2027-03-31'});
  });

  test('cancel POSTs to the booking cancel path with Bearer and returns server copy',
      () async {
    final requests = <http.Request>[];
    final session = await signedInSession((request) async {
      requests.add(request);
      return jsonResponse({
        'data': bookingJson(status: 'cancelled', cancellable: false)
      });
    });
    final booking = await repositoryFor(session).cancelBooking('booking-1');
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/bookings/booking-1/cancel');
    expect(requests.single.headers['Authorization'], 'Bearer access');
    expect(booking.status, 'cancelled');
    expect(booking.cancellable, isFalse);
  });

  test('booking-intent reconcile and abandon use the key path with Bearer',
      () async {
    final requests = <http.Request>[];
    final session = await signedInSession((request) async {
      requests.add(request);
      final abandon = request.url.path.endsWith('/abandon');
      return jsonResponse({
        'data': {
          'key': 'key-1',
          'state': abandon ? 'abandoned' : 'completed',
          'replay_safe': !abandon,
          'key_expired': false,
          'expires_at': '2027-01-08T00:00:00Z',
          'booking': abandon ? null : bookingJson(status: 'confirmed'),
        }
      });
    });
    final repository = repositoryFor(session);
    final found = await repository.bookingIntent('key-1');
    final abandoned = await repository.abandonBookingIntent('key-1');
    expect(requests.map((r) => '${r.method} ${r.url.path}'), [
      'GET /api/v1/booking-intents/key-1',
      'POST /api/v1/booking-intents/key-1/abandon',
    ]);
    expect(requests.every((r) => r.headers['Authorization'] == 'Bearer access'),
        isTrue);
    expect(found.state, 'completed');
    expect(found.booking!.status, 'confirmed');
    expect(found.replaySafe, isTrue);
    expect(abandoned.state, 'abandoned');
    expect(abandoned.replaySafe, isFalse);
    expect(abandoned.booking, isNull);
  });

  test('structured 409 keeps code and context for the caller', () async {
    final session = await signedInSession((request) async => jsonResponse({
          'message': 'Insufficient capacity.',
          'code': 'insufficient_capacity',
          'context': {'remaining': 2}
        }, 409));
    await expectLater(
        repositoryFor(session).createBooking({'quantity': 5}, 'key-1'),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.code, 'code', 'insufficient_capacity')
            .having((e) => e.context!['remaining'], 'remaining', 2)));
  });

  test('bookings list sends status, page and per_page', () async {
    final requests = <http.Request>[];
    final session = await signedInSession((request) async {
      requests.add(request);
      return jsonResponse({
        'data': [bookingJson()],
        'meta': {'current_page': 2, 'last_page': 2, 'total': 16, 'per_page': 15}
      });
    });
    final page = await repositoryFor(session).bookings(
        query: {'status': 'confirmed', 'page': '2', 'per_page': '15'});
    expect(requests.single.url.path, '/api/v1/bookings');
    expect(requests.single.url.queryParameters,
        {'status': 'confirmed', 'page': '2', 'per_page': '15'});
    expect(page.items.single.guid, 'booking-1');
  });

  test('documents metadata and PDF bytes use Bearer; null means not issued',
      () async {
    final requests = <http.Request>[];
    final pdf = Uint8List.fromList('%PDF-1.4 test'.codeUnits);
    final session = await signedInSession((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/documents')) {
        return jsonResponse({
          'data': {
            'invoice': {
              'guid': 'inv-1',
              'booking_guid': 'booking-1',
              'invoice_number': 'INV-1',
              'status': 'issued',
              'issued_at': '2027-01-01T00:00:00Z'
            },
            'ticket': null
          }
        });
      }
      return http.Response.bytes(pdf, 200,
          headers: {'content-type': 'application/pdf'});
    });
    final repository = repositoryFor(session);
    final documents = await repository.bookingDocuments('booking-1');
    final file = await repository.downloadDocument('booking-1', 'invoice');
    expect(documents.invoice!['invoice_number'], 'INV-1');
    expect(documents.ticket, isNull);
    expect(file.contentType, 'application/pdf');
    expect(file.bytes, pdf);
    expect(requests.map((r) => r.url.path), [
      '/api/v1/bookings/booking-1/documents',
      '/api/v1/bookings/booking-1/documents/invoice',
    ]);
    expect(requests.every((r) => r.headers['Authorization'] == 'Bearer access'),
        isTrue);
  });

  test('saveBookingDocument writes a verified PDF and rejects other content',
      () async {
    final directory = await Directory.systemTemp.createTemp('user_doc_test');
    addTearDown(() => directory.delete(recursive: true));
    var body = Uint8List.fromList('%PDF-1.7 content'.codeUnits);
    final session = await signedInSession((request) async =>
        http.Response.bytes(body, 200,
            headers: {'content-type': 'application/pdf'}));
    final repository = repositoryFor(session);

    final saved = await saveBookingDocument(repository, 'booking-1', 'invoice',
        bookingNumber: 'BK/001', directory: directory);
    expect(saved.path.endsWith('invoice-BK_001.pdf'), isTrue);
    expect(await File(saved.path).readAsBytes(), body);

    body = Uint8List.fromList('<html>not a pdf</html>'.codeUnits);
    await expectLater(
        saveBookingDocument(repository, 'booking-1', 'ticket',
            directory: directory),
        throwsA(isA<ApiException>()));
    expect(File('${directory.path}/ticket-booking-1.pdf').existsSync(), isFalse);
    await expectLater(
        saveBookingDocument(repository, 'booking-1', 'passport',
            directory: directory),
        throwsA(isA<ApiException>()));
  });
}
