import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/admin_state.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'admin_test_support.dart';

const _destination = {
  'guid': 'dest-1',
  'name': 'Pantai Indah',
  'destination_category_guid': 'cat-1',
  'ticket_price': 25000,
  'timezone': 'Asia/Makassar',
  'is_active': true,
  'image_url': 'destinations/dest-1/image?v=1',
};

final _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3];

void main() {
  late List<http.Request> log;
  setUp(() => log = []);

  Future<http.Response> ok(http.Request request) async =>
      jsonResponse({'data': _destination});

  test('create destination sends multipart with fields, image and Bearer',
      () async {
    final repo = repositoryFor(await adminSession(ok, log: log));
    final created = await repo.createDestination({
      'destination_category_guid': 'cat-1',
      'name': 'Pantai Indah',
      'location': 'Makassar',
      'description': 'Pantai',
      'ticket_price': 25000,
      'opening_hours': '08.00 - 17.00',
      'timezone': 'Asia/Makassar',
    }, image: UploadFile('image', _png, 'foto.png'));

    expect(created.guid, 'dest-1');
    final request = log.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/destinations');
    expect(request.headers['Authorization'], 'Bearer access');
    expect(request.headers['content-type'], startsWith('multipart/form-data'));
    final body = latin1.decode(request.bodyBytes);
    for (final field in [
      'destination_category_guid',
      'name',
      'location',
      'description',
      'ticket_price',
      'opening_hours',
      'timezone'
    ]) {
      expect(body, contains('name="$field"'), reason: field);
    }
    expect(body, contains('Asia/Makassar'));
    expect(body, contains('name="image"; filename="foto.png"'));
  });

  test('create without image is a JSON POST', () async {
    final repo = repositoryFor(await adminSession(ok, log: log));
    await repo.createDestination({'name': 'X', 'timezone': 'Asia/Jakarta'});
    expect(log.single.headers['Content-Type'], contains('application/json'));
    expect(jsonDecode(log.single.body)['timezone'], 'Asia/Jakarta');
  });

  test('edit with image is POST plus _method=PATCH', () async {
    final repo = repositoryFor(await adminSession(ok, log: log));
    await repo.updateDestination('dest-1', {'name': 'Baru', 'ticket_price': 0},
        image: UploadFile('image', _png, 'baru.png'));
    final request = log.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/destinations/dest-1');
    final body = latin1.decode(request.bodyBytes);
    expect(body, contains('name="_method"'));
    expect(body, contains('PATCH'));
    expect(body, contains('name="image"; filename="baru.png"'));
  });

  test('image-only upload posts to destinations/{guid}/image', () async {
    final repo = repositoryFor(await adminSession(ok, log: log));
    await repo.uploadDestinationImage(
        'dest-1', UploadFile('image', _png, 'gambar.png'));
    expect(log.single.method, 'POST');
    expect(log.single.url.path, '/api/v1/destinations/dest-1/image');
    expect(latin1.decode(log.single.bodyBytes),
        contains('name="image"; filename="gambar.png"'));
    expect(log.single.headers['Authorization'], 'Bearer access');
  });

  test('admin destinations pass the status query; deactivate and reactivate',
      () async {
    final repo = repositoryFor(await adminSession((request) async {
      if (request.method == 'GET') {
        return jsonResponse(pageEnvelope([_destination]));
      }
      return jsonResponse({'data': _destination});
    }, log: log));
    final page = await repo.adminDestinations(
        query: {'status': 'inactive', 'page': '2', 'category': 'cat-1'});
    expect(page.items.single.guid, 'dest-1');
    await repo.deactivateDestination('dest-1');
    await repo.reactivateDestination('dest-1');

    expect(log[0].url.path, '/api/v1/admin/destinations');
    expect(log[0].url.queryParameters,
        {'status': 'inactive', 'page': '2', 'category': 'cat-1'});
    expect(log[1].method, 'DELETE');
    expect(log[2].method, 'PATCH');
    expect(jsonDecode(log[2].body), {'is_active': true});
  });

  test('categories CRUD and admin list use the contract paths', () async {
    final repo = repositoryFor(await adminSession((request) async {
      if (request.method == 'GET') {
        return jsonResponse(pageEnvelope([
          {'guid': 'cat-1', 'name': 'Pantai', 'slug': 'pantai', 'is_active': false}
        ]));
      }
      return jsonResponse({
        'data': {'guid': 'cat-1', 'name': 'Pantai', 'slug': 'pantai'}
      });
    }, log: log));
    final list = await repo.adminCategories(query: {'status': 'all'});
    expect(list.items.single.isActive, isFalse);
    await repo.createCategory({'name': 'Pantai', 'slug': 'pantai'});
    await repo.updateCategory('cat-1', {'name': 'Pantai Baru'});
    await repo.deactivateCategory('cat-1');
    await repo.reactivateCategory('cat-1');

    expect(log.map((r) => '${r.method} ${r.url.path}'), [
      'GET /api/v1/admin/categories',
      'POST /api/v1/categories',
      'PATCH /api/v1/categories/cat-1',
      'DELETE /api/v1/categories/cat-1',
      'PATCH /api/v1/categories/cat-1',
    ]);
    expect(log[0].url.queryParameters['status'], 'all');
    expect(jsonDecode(log[1].body), {'name': 'Pantai', 'slug': 'pantai'});
    expect(jsonDecode(log[4].body), {'is_active': true});
  });

  test('quota PUT body carries visit_date, capacity and UTC Z timestamps',
      () async {
    final repo = repositoryFor(await adminSession((request) async {
      if (request.method == 'GET') {
        return jsonResponse(pageEnvelope([
          {
            'guid': 'q1',
            'visit_date': '2026-12-01',
            'capacity': 20,
            'allocated': 7,
            'remaining': 13,
            'booking_opens_at': '2026-10-01T00:00:00+00:00',
            'booking_closes_at': '2026-11-30T00:00:00+00:00',
          }
        ]));
      }
      return jsonResponse({
        'data': {
          'guid': 'q1',
          'visit_date': '2026-12-01',
          'capacity': 20,
          'allocated': 7,
          'remaining': 13
        }
      });
    }, log: log));
    final opens = DateTime(2026, 10, 1, 8, 30);
    final closes = DateTime(2026, 11, 30, 17);
    final payload = buildQuotaPayload(
        visitDate: DateTime(2026, 12, 1),
        capacity: 20,
        opensAt: opens,
        closesAt: closes);
    final saved = await repo.saveQuota('dest-1', payload);
    expect(saved.remaining, 13);
    final entries = await repo.quotaEntries('dest-1', page: 1);
    final entry = entries.items.single;
    expect([entry.capacity, entry.allocated, entry.remaining], [20, 7, 13]);

    final put = log[0];
    expect(put.method, 'PUT');
    expect(put.url.path, '/api/v1/destinations/dest-1/quotas');
    final body = jsonDecode(put.body) as Map<String, dynamic>;
    expect(body['visit_date'], '2026-12-01');
    expect(body['capacity'], 20);
    expect(body['booking_opens_at'], endsWith('Z'));
    expect(body['booking_closes_at'], endsWith('Z'));
    expect(DateTime.parse(body['booking_opens_at']).isAtSameMomentAs(opens),
        isTrue);
    expect(DateTime.parse(body['booking_closes_at']).isAtSameMomentAs(closes),
        isTrue);
    expect(log[1].url.queryParameters['page'], '1');
  });

  test('admin accounts: list with filters, create and update', () async {
    final repo = repositoryFor(await adminSession((request) async {
      if (request.method == 'GET') {
        return jsonResponse(pageEnvelope([
          {
            'guid': 'u1',
            'name': 'Sari',
            'email': 's@example.test',
            'role': 1,
            'status': 'suspended'
          }
        ]));
      }
      return jsonResponse({
        'data': {
          'guid': 'u2',
          'name': 'Baru',
          'email': 'b@example.test',
          'role': 1,
          'status': 'active'
        }
      });
    }, log: log));
    final page = await repo.adminAccounts(query: {'role': '1', 'status': 'suspended'});
    expect(page.items.single.isActive, isFalse);
    final created = await repo.createAdminAccount({
      'name': 'Baru',
      'email': 'b@example.test',
      'password': 'rahasia123',
      'password_confirmation': 'rahasia123',
    });
    expect(created.role, 1);
    await repo.updateAdminAccount('u1', {'role': 0, 'status': 'active'});

    expect(log[0].url.path, '/api/v1/admin/accounts');
    expect(log[0].url.queryParameters, {'role': '1', 'status': 'suspended'});
    expect(log[1].method, 'POST');
    expect(jsonDecode(log[1].body)['password_confirmation'], 'rahasia123');
    expect(log[2].method, 'PATCH');
    expect(log[2].url.path, '/api/v1/admin/accounts/u1');
    expect(jsonDecode(log[2].body), {'role': 0, 'status': 'active'});
  });

  test('booking decision sends the reason only when given', () async {
    final repo = repositoryFor(await adminSession(
        (request) async =>
            jsonResponse({'data': bookingJson('b1', 'rejected')}),
        log: log));
    await repo.decideBooking('b1', approve: false, reason: '  Penuh  ');
    await repo.decideBooking('b1', approve: true);
    expect(log[0].url.path, '/api/v1/admin/bookings/b1/reject');
    expect(jsonDecode(log[0].body), {'reason': 'Penuh'});
    expect(log[1].url.path, '/api/v1/admin/bookings/b1/approve');
    expect(log[1].body, isEmpty);
  });

  test('admin booking list sends the status filter to the server', () async {
    final repo = repositoryFor(await adminSession(
        (request) async => jsonResponse(pageEnvelope([bookingJson('b1', 'confirmed')])),
        log: log));
    await repo.adminBookings(query: {'status': 'confirmed', 'page': '1'});
    expect(log.single.url.path, '/api/v1/admin/bookings');
    expect(log.single.url.queryParameters['status'], 'confirmed');
  });
}
