import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

class Store implements SessionStore {
  String? value;
  Future<String?> read() async => value;
  Future<void> write(String data) async {
    value = data;
  }

  Future<void> clear() async {
    value = null;
  }
}

void main() {
  test('admin catalog requests use bearer, GUID and quota payload', () async {
    final requests = <http.Request>[];
    final session = AuthSession(
        baseUrl: 'https://example.test/api/v1',
        store: Store(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/login')) {
            return http.Response(
                jsonEncode({
                  'data': {
                    'access_token': 'a',
                    'refresh_token': 'r',
                    'user': {
                      'guid': 'u',
                      'name': 'N',
                      'email': 'n@example.test'
                    }
                  }
                }),
                200);
          }
          if (request.url.path.endsWith('/auth/me')) {
            return http.Response(
                jsonEncode({
                  'data': {
                    'guid': 'u',
                    'name': 'N',
                    'email': 'n@example.test',
                    'phone': null,
                    'role': 2,
                    'status': 'active'
                  }
                }),
                200);
          }
          requests.add(request);
          if (request.method == 'GET')
            return http.Response(
                jsonEncode({
                  'data': [
                    {'capacity': 20}
                  ],
                  'links': {'next': null},
                  'meta': {'current_page': 2}
                }),
                200);
          return http.Response(
              jsonEncode({
                'data': {'guid': 'id', 'name': 'Name', 'capacity': 20}
              }),
              200);
        }));
    await session.login('n@example.test', 'pw');
    final repository = BusinessRepository(ApiClient(session));
    await repository.createDestination({'name': 'Name'});
    await repository.updateDestination('dest-1', {'name': 'New'});
    await repository.deactivateDestination('dest-1');
    await repository.createCategory({'name': 'Name', 'slug': 'name'});
    await repository.updateCategory('cat-1', {'name': 'New'});
    await repository.deactivateCategory('cat-1');
    final quota = await repository.quotas('dest-1', page: 2);
    final payload = {
      'visit_date': '2026-11-01',
      'capacity': 20,
      'booking_opens_at': '2026-10-30T00:00:00Z',
      'booking_closes_at': '2026-10-31T00:00:00Z'
    };
    await repository.putQuota('dest-1', payload);
    expect(quota.items.single['capacity'], 20);
    expect(requests.map((r) => r.method),
        ['POST', 'PATCH', 'DELETE', 'POST', 'PATCH', 'DELETE', 'GET', 'PUT']);
    expect(requests[1].url.path, '/api/v1/destinations/dest-1');
    expect(requests[4].url.path, '/api/v1/categories/cat-1');
    expect(requests[6].url.queryParameters['page'], '2');
    expect(jsonDecode(requests.last.body), payload);
    for (final request in requests) {
      expect(request.headers['Authorization'], 'Bearer a');
    }
  });
}
