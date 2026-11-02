import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/facility_state.dart';
import 'admin_test_support.dart';
import 'user_support.dart' as users;

Map<String, dynamic> facility(String guid) => {
      'guid': guid,
      'name': guid,
      'slug': guid,
      'icon_key': null,
      'is_active': true,
    };

void main() {
  test('role matrix only permits master for superadmin', () {
    expect([null, 0, 1, 3].any(canManageFacilities), isFalse);
    expect(canManageFacilities(2), isTrue);
  });

  test('selector loads every page and hydrated detail; unchanged never PUTs',
      () async {
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/facilities')) {
        final page = int.parse(request.url.queryParameters['page']!);
        return jsonResponse(
            pageEnvelope([facility('f$page')], page: page, last: 2));
      }
      return jsonResponse({
        'data': {
          'guid': 'd1',
          'name': 'Destinasi',
          'facilities': [facility('f2')]
        }
      });
    }, role: 1, log: log);
    final state = DestinationFacilitiesState(repositoryFor(session));
    addTearDown(state.dispose);
    await state.load('d1');
    expect(state.ready, isTrue);
    expect(state.items.map((f) => f.guid), ['f1', 'f2']);
    expect(state.selected, {'f2'});
    expect(state.changed, isFalse);
    expect(log.last.url.path, '/api/v1/admin/destinations/d1');
    expect(await state.save('d1'), isNull);
    expect(log.where((r) => r.method == 'PUT'), isEmpty);
  });

  test('explicit clear sends [] and rereads server; duplicate save guarded',
      () async {
    var assigned = [facility('f1')];
    final log = <http.Request>[];
    final committed = Completer<http.Response>();
    final session = await adminSession((request) async {
      if (request.method == 'PUT') {
        expect(jsonDecode(request.body), {'facility_guids': []});
        assigned = [];
        return committed.future;
      }
      if (request.url.path == '/api/v1/facilities') {
        return jsonResponse(pageEnvelope([facility('f1')]));
      }
      return jsonResponse({
        'data': {'guid': 'd1', 'name': 'Destinasi', 'facilities': assigned}
      });
    }, role: 1, log: log);
    final state = DestinationFacilitiesState(repositoryFor(session));
    addTearDown(state.dispose);
    await state.load('d1');
    state.toggle('f1', false);
    final save = state.save('d1');
    expect(await state.save('d1'), contains('belum siap'));
    committed.complete(jsonResponse({
      'data': {'guid': 'd1', 'name': 'Destinasi', 'facilities': []}
    }));
    expect(await save, isNull);
    expect(log.where((r) => r.method == 'PUT'), hasLength(1));
    expect(state.selected, isEmpty);
    expect(state.changed, isFalse);
  });

  test(
      'failed assignment rereads server and preserves desired unsaved selection',
      () async {
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.method == 'PUT') {
        return jsonResponse({
          'message': 'Validation failed',
          'errors': {
            'facility_guids': ['Fasilitas nonaktif']
          }
        }, 422);
      }
      if (request.url.path == '/api/v1/facilities') {
        return jsonResponse(pageEnvelope([facility('f1'), facility('f2')]));
      }
      return jsonResponse({
        'data': {
          'guid': 'd1',
          'name': 'Destinasi',
          'facilities': [facility('f1')]
        }
      });
    }, log: log);
    final state = DestinationFacilitiesState(repositoryFor(session));
    addTearDown(state.dispose);
    await state.load('d1');
    state.toggle('f2', true);
    expect(await state.save('d1'), contains('nonaktif'));
    expect(state.selected, {'f1', 'f2'});
    expect(state.changed, isTrue,
        reason: 'server rejection must preserve editable input for retry');
    expect(log.last.url.path, '/api/v1/admin/destinations/d1');
  });

  test('incomplete pagination blocks all assignment', () async {
    final session = await adminSession(
        (request) async => jsonResponse(pageEnvelope([], last: 2)));
    final state = DestinationFacilitiesState(repositoryFor(session));
    addTearDown(state.dispose);
    await state.load();
    expect(state.ready, isFalse);
    expect(state.error, isNotNull);
    expect(await state.save('d1'), contains('belum siap'));
  });

  test('request replacement and logout cannot publish stale facilities',
      () async {
    final old = Completer<http.Response>();
    var requests = 0;
    final session = await adminSession((request) async {
      if (request.url.path == '/api/v1/facilities') {
        requests++;
        if (requests == 1) return old.future;
        return jsonResponse(pageEnvelope([facility('new')]));
      }
      return jsonResponse({'data': {}});
    });
    final state = DestinationFacilitiesState(repositoryFor(session));
    addTearDown(state.dispose);
    final first = state.load();
    await Future<void>.delayed(Duration.zero);
    await state.load();
    old.complete(jsonResponse(pageEnvelope([facility('old')])));
    await first;
    expect(state.items.single.guid, 'new');
    await session.logout();
    expect(state.items, isEmpty);
    expect(state.selected, isEmpty);
    expect(state.ready, isFalse);
  });

  test('role user cannot load or assign facilities', () async {
    final log = <http.Request>[];
    final session = await users.signedInSession((request) async {
      log.add(request);
      return jsonResponse({'data': {}});
    });
    final state = DestinationFacilitiesState(repositoryFor(session));
    addTearDown(state.dispose);
    await state.load('d1');
    expect(await state.save('d1'), contains('belum siap'));
    expect(log, isEmpty);
  });
}
