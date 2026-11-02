import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/services/auth_session.dart';

import 'admin_test_support.dart';
import 'user_support.dart' as user;

const _facility = {
  'guid': 'facility-1',
  'name': 'Parkir',
  'slug': 'parkir',
  'icon_key': null,
  'is_active': true,
};

void main() {
  test('master list keeps status, page, per_page and nullable icon', () async {
    final requests = <http.Request>[];
    final repository = repositoryFor(await adminSession((request) async {
      return jsonResponse(pageEnvelope([
        {..._facility, 'is_active': false}
      ], page: 2, last: 3, total: 102));
    }, log: requests));

    final page = await repository.superadminFacilities(
        status: 'inactive', page: 2, perPage: 50);
    expect(requests.single.url.path, '/api/v1/superadmin/facilities');
    expect(requests.single.url.queryParameters,
        {'status': 'inactive', 'page': '2', 'per_page': '50'});
    expect(requests.single.headers['Authorization'], 'Bearer access');
    expect(page.meta!['last_page'], 3);
    expect(page.items.single.iconKey, isNull);
    expect(page.items.single.isActive, isFalse);
  });

  test('master CRUD uses exact methods and PATCH cannot mutate slug', () async {
    final requests = <http.Request>[];
    final repository = repositoryFor(await adminSession(
        (_) async => jsonResponse({'data': _facility}),
        log: requests));
    await repository.createFacility({
      'name': 'Parkir',
      'slug': 'parkir',
      'icon_key': 'untrusted-icon',
      'is_active': true,
    });
    await repository.updateFacility('facility-1', {
      'name': 'Parkir Baru',
      'slug': 'should-not-be-sent',
      'is_active': false,
    });
    await repository.deactivateFacility('facility-1');
    await repository.updateFacility('facility-1', {'is_active': true});

    expect(requests.map((r) => '${r.method} ${r.url.path}'), [
      'POST /api/v1/superadmin/facilities',
      'PATCH /api/v1/superadmin/facilities/facility-1',
      'DELETE /api/v1/superadmin/facilities/facility-1',
      'PATCH /api/v1/superadmin/facilities/facility-1',
    ]);
    expect(jsonDecode(requests[0].body), {
      'name': 'Parkir',
      'slug': 'parkir',
      'icon_key': null,
      'is_active': true,
    });
    expect(jsonDecode(requests[1].body), {
      'name': 'Parkir Baru',
      'is_active': false,
      'icon_key': null,
    });
    expect(jsonDecode(requests[3].body), {'is_active': true, 'icon_key': null});
  });

  test('active selector uses paginated authenticated role1 endpoint', () async {
    final requests = <http.Request>[];
    final repository = repositoryFor(await adminSession(
        (_) async => jsonResponse(pageEnvelope([_facility])),
        role: 1,
        log: requests));
    expect((await repository.activeFacilities(page: 2)).items.single.guid,
        'facility-1');
    expect(requests.single.url.path, '/api/v1/facilities');
    expect(
        requests.single.url.queryParameters, {'page': '2', 'per_page': '50'});
    expect(requests.single.headers['Authorization'], 'Bearer access');
  });

  test('assignment sends unique GUID array and explicit empty replacement',
      () async {
    final requests = <http.Request>[];
    final repository = repositoryFor(await adminSession(
        (_) async => jsonResponse({
              'data': {'guid': 'dest-1', 'name': 'Pantai', 'facilities': []}
            }),
        role: 1,
        log: requests));
    await repository.assignDestinationFacilities(
        'dest-1', ['facility-1', 'facility-1', 'facility-2']);
    final empty = await repository.assignDestinationFacilities('dest-1', []);
    expect(requests.every((r) => r.method == 'PUT'), isTrue);
    expect(requests.first.url.path,
        '/api/v1/admin/destinations/dest-1/facilities');
    expect(jsonDecode(requests.first.body), {
      'facility_guids': ['facility-1', 'facility-2']
    });
    expect(jsonDecode(requests.last.body), {'facility_guids': []});
    expect(empty.facilities, isEmpty);
  });

  test('ordinary destination update does not emit assignment request',
      () async {
    final requests = <http.Request>[];
    final repository = repositoryFor(await adminSession(
        (_) async => jsonResponse({
              'data': {'guid': 'dest-1', 'name': 'Pantai Baru'}
            }),
        log: requests));
    await repository.updateDestination('dest-1', {'name': 'Pantai Baru'});
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/v1/destinations/dest-1');
    expect(requests.single.method, 'PATCH');
    expect(jsonDecode(requests.single.body), {'name': 'Pantai Baru'});
  });

  test('facility validation errors preserve server field messages', () async {
    final repository =
        repositoryFor(await adminSession((_) async => jsonResponse({
              'message': 'Validasi gagal',
              'errors': {
                'name': ['Nama fasilitas sudah digunakan.']
              }
            }, 422)));
    await expectLater(
        repository.createFacility({'name': 'Parkir'}),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 422)
            .having((e) => e.fieldErrors['name'], 'name error',
                'Nama fasilitas sudah digunakan.')));
  });

  test('403 from master remains an access error without fallback', () async {
    final requests = <http.Request>[];
    final repository = repositoryFor(await adminSession(
        (_) async => jsonResponse({'message': 'Forbidden'}, 403),
        role: 1,
        log: requests));
    await expectLater(repository.superadminFacilities(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)));
    expect(requests, hasLength(1));
  });

  test('facility response arriving after logout is rejected', () async {
    final reply = Completer<http.Response>();
    final requested = Completer<void>();
    final session = await adminSession((_) {
      requested.complete();
      return reply.future;
    });
    final future = repositoryFor(session).activeFacilities();
    final assertion = expectLater(future,
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    await requested.future;
    await session.clear();
    reply.complete(jsonResponse(pageEnvelope([_facility])));
    await assertion;
  });

  test('monthly query is an authenticated object request without legacy params',
      () async {
    final requests = <http.Request>[];
    final repository =
        repositoryFor(await user.signedInSession((request) async {
      requests.add(request);
      return jsonResponse({
        'data': {
          'destination_guid': 'dest-1',
          'month': '2028-02',
          'timezone': 'Asia/Makassar',
          'requested_quantity': 4,
          'dates': []
        }
      });
    }));
    final month = await repository.monthlyAvailability('dest-1', '2028-02', 4);
    expect(requests.single.method, 'GET');
    expect(
        requests.single.url.path, '/api/v1/destinations/dest-1/availability');
    expect(requests.single.url.queryParameters,
        {'month': '2028-02', 'quantity': '4'});
    expect(requests.single.headers['Authorization'], 'Bearer access');
    expect(month.destinationGuid, 'dest-1');
    expect(month.month, '2028-02');
    expect(month.timezone, 'Asia/Makassar');
    expect(month.requestedQuantity, 4);
    expect(month.dates, isEmpty);
  });

  test('monthly endpoint refuses legacy list envelope', () async {
    final repository = repositoryFor(
        await user.signedInSession((_) async => jsonResponse({'data': []})));
    await expectLater(repository.monthlyAvailability('dest-1', '2028-02', 1),
        throwsA(isA<ApiException>()));
  });
}
