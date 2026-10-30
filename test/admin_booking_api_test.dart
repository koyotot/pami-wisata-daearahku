import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

class _Store implements SessionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

void main() {
  test('admin booking calls send bearer, pagination and server decisions',
      () async {
    final requests = <http.Request>[];
    final session = AuthSession(
        baseUrl: 'https://example.test/api/v1',
        store: _Store(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return http.Response(
                jsonEncode({
                  'data': {
                    'access_token': 'access',
                    'refresh_token': 'refresh',
                    'user': {
                      'guid': 'admin',
                      'name': 'Admin',
                      'email': 'a@example.test'
                    }
                  }
                }),
                200);
          }
          if (request.url.path.endsWith('/auth/me')) {
            return http.Response(
                jsonEncode({
                  'data': {
                    'guid': 'admin',
                    'name': 'Admin',
                    'email': 'a@example.test',
                    'phone': null,
                    'role': 1,
                    'status': 'active'
                  }
                }),
                200);
          }
          requests.add(request);
          final booking = {
            'guid': 'booking-guid',
            'status':
                request.url.path.endsWith('/reject') ? 'rejected' : 'confirmed'
          };
          return http.Response(
              jsonEncode({
                'data': request.method == 'GET' ? [booking] : booking,
                if (request.method == 'GET') 'meta': {'last_page': 2}
              }),
              200);
        }));
    await session.login('a@example.test', 'password');
    final repo = BusinessRepository(ApiClient(session));
    expect(
        (await repo.adminBookings(query: {'page': '2'})).meta!['last_page'], 2);
    expect((await repo.decideBooking('booking-guid', approve: true)).status,
        'confirmed');
    expect((await repo.decideBooking('booking-guid', approve: false)).status,
        'rejected');
    expect(requests.map((r) => r.method), ['GET', 'POST', 'POST']);
    expect(requests.first.url.queryParameters['page'], '2');
    expect(requests.skip(1).map((r) => r.url.path), [
      '/api/v1/admin/bookings/booking-guid/approve',
      '/api/v1/admin/bookings/booking-guid/reject'
    ]);
    expect(requests.every((r) => r.headers['Authorization'] == 'Bearer access'),
        isTrue);
  });
}
