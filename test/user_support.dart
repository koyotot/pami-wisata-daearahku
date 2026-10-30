import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

class MemoryStore implements SessionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

/// Signed-in user session (role 0) whose non-auth requests go to [handler].
Future<AuthSession> signedInSession(
    Future<http.Response> Function(http.Request request) handler,
    {String guid = 'user-1'}) async {
  final session = AuthSession(
      baseUrl: 'https://example.test/api/v1',
      store: MemoryStore(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(
              jsonEncode({
                'data': {
                  'access_token': 'access',
                  'refresh_token': 'refresh',
                  'user': {'guid': guid, 'name': 'User', 'email': 'u@example.test'}
                }
              }),
              200);
        }
        if (request.url.path.endsWith('/auth/me')) {
          return http.Response(
              jsonEncode({
                'data': {
                  'guid': guid,
                  'name': 'User',
                  'email': 'u@example.test',
                  'phone': '0812345678',
                  'role': 0,
                  'status': 'active'
                }
              }),
              200);
        }
        return handler(request);
      }));
  await session.login('u@example.test', 'password');
  return session;
}

BusinessRepository repositoryFor(AuthSession session) =>
    BusinessRepository(ApiClient(session));

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json'});

/// A complete Laravel booking resource.
Map<String, dynamic> bookingJson(
        {String guid = 'booking-1',
        String status = 'pending_approval',
        bool cancellable = true,
        String number = 'BK-0001'}) =>
    {
      'guid': guid,
      'booking_number': number,
      'destination_guid': 'dest-1',
      'destination_name': 'Pantai Test',
      'visit_date': '2027-03-10',
      'quantity': 2,
      'visitor_name': 'User',
      'visitor_email': 'u@example.test',
      'visitor_phone': '0812345678',
      'unit_price': 10000,
      'total_amount': 20000,
      'currency': 'IDR',
      'notes': null,
      'status': status,
      'cancellable': cancellable,
      'created_at': '2027-01-01T00:00:00Z',
    };

Map<String, dynamic> availabilityJson(
        {String date = '2027-03-10',
        int capacity = 10,
        int allocated = 0,
        String status = 'open'}) =>
    {
      'visit_date': date,
      'capacity': capacity,
      'allocated': allocated,
      'remaining': capacity - allocated,
      'status': status,
      'booking_opens_at': '2027-01-01T00:00:00Z',
      'booking_closes_at': '2027-03-09T00:00:00Z',
      'timezone': 'Asia/Jakarta',
    };
