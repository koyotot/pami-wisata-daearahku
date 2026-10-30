import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

class MemoryStore implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async => value = data;
  @override
  Future<void> clear() async => value = null;
}

typedef Handler = Future<http.Response> Function(http.Request request);

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

http.Response conflict(String code, {Map<String, dynamic>? context}) =>
    jsonResponse({
      'message': 'Konflik',
      'code': code,
      if (context != null) 'context': context,
    }, 409);

/// Logged-in session over a mocked HTTP client. Every request except login/me is
/// recorded in [log] and answered by [handler].
Future<AuthSession> adminSession(
  Handler handler, {
  int role = 2,
  String guid = 'admin-1',
  List<http.Request>? log,
}) async {
  final session = AuthSession(
      baseUrl: 'https://example.test/api/v1',
      store: MemoryStore(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return jsonResponse({
            'data': {
              'access_token': 'access',
              'refresh_token': 'refresh',
              'user': {'guid': guid, 'name': 'Admin', 'email': 'a@example.test'}
            }
          });
        }
        if (request.url.path.endsWith('/auth/me')) {
          return jsonResponse({
            'data': {
              'guid': guid,
              'name': 'Admin',
              'email': 'a@example.test',
              'phone': null,
              'role': role,
              'status': 'active'
            }
          });
        }
        log?.add(request);
        return handler(request);
      }));
  await session.login('a@example.test', 'password');
  return session;
}

BusinessRepository repositoryFor(AuthSession session) =>
    BusinessRepository(ApiClient(session));

Map<String, dynamic> bookingJson(String guid, String status,
        {String name = 'Budi'}) =>
    {
      'guid': guid,
      'booking_number': 'BK-$guid',
      'destination_guid': 'dest-1',
      'visit_date': '2026-12-01',
      'destination_name': 'Pantai Indah',
      'quantity': 2,
      'visitor_name': name,
      'visitor_email': 'budi@example.test',
      'visitor_phone': '0812345',
      'unit_price': 10000,
      'total_amount': 20000,
      'currency': 'IDR',
      'notes': null,
      'status': status,
      'created_at': '2026-10-30T01:00:00.000000Z',
    };

Map<String, dynamic> pageEnvelope(List<Map<String, dynamic>> items,
        {int page = 1, int last = 1, int? total}) =>
    {
      'data': items,
      'links': {'next': page < last ? 'next-url' : null},
      'meta': {
        'current_page': page,
        'last_page': last,
        'total': total ?? items.length,
        'per_page': 15
      },
    };
