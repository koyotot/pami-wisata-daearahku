import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/approval_queue_state.dart';
import 'admin_test_support.dart';
import 'operations_test_support.dart';

void main() {
  test('malformed mutation response remains unknown and retains its key',
      () async {
    final session = await adminSession((request) async {
      if (request.method == 'POST') return jsonResponse({'data': {}});
      return request.url.path.endsWith('/b1')
          ? jsonResponse({'data': operationalBooking()})
          : jsonResponse(pageEnvelope([operationalQueueRow()]));
    }, role: 1);
    final state = ApprovalDetailState(repositoryFor(session), 'b1');
    addTearDown(state.dispose);
    await state.refresh();
    await state.mutate('claim');
    expect(state.uncertain, isTrue);
    expect(state.pendingKey, isNotNull);
    expect(state.canDecide, isFalse);
    expect(state.canClaim, isFalse);
  });
  for (final action in ['release', 'reassign']) {
    test('$action timeout recovers original payload and idempotency key',
        () async {
      String? owner = 'admin-1';
      final log = <http.Request>[];
      var writes = 0;
      final session = await adminSession((request) async {
        if (request.method == 'POST') {
          writes++;
          owner = action == 'release' ? null : 'target';
          if (writes == 1) throw TimeoutException('unknown');
          return jsonResponse({'data': operationalClaim(owner)});
        }
        return request.url.path.endsWith('/b1')
            ? jsonResponse({'data': operationalBooking()})
            : jsonResponse(pageEnvelope([operationalQueueRow(owner: owner)]));
      }, log: log);
      final state = ApprovalDetailState(repositoryFor(session), 'b1');
      addTearDown(state.dispose);
      await state.refresh();
      await state.mutate(action,
          adminGuid: action == 'reassign' ? 'target' : null,
          reason: action == 'reassign' ? 'Pergantian shift' : null);
      expect(state.uncertain, isTrue);
      final key = state.pendingKey;
      await state.recoverMutation();
      final posts = log.where((request) => request.method == 'POST').toList();
      expect(posts, hasLength(2));
      expect(posts.first.body, posts.last.body);
      expect(
          posts.first.headers['Idempotency-Key'] ??
              posts.first.headers['idempotency-key'],
          key);
      expect(posts.first.headers, posts.last.headers);
      expect(state.uncertain, isFalse);
      expect(state.claim?.ownerGuid, owner);
    });
  }

  test('unknown mutation followed by revoked access clears uncertainty',
      () async {
    var revoked = false;
    final session = await adminSession((request) async {
      if (request.method == 'POST') {
        revoked = true;
        throw TimeoutException('unknown');
      }
      if (revoked) return jsonResponse({'message': 'Forbidden'}, 403);
      return request.url.path.endsWith('/b1')
          ? jsonResponse({'data': operationalBooking()})
          : jsonResponse(pageEnvelope([operationalQueueRow()]));
    }, role: 1);
    final state = ApprovalDetailState(repositoryFor(session), 'b1');
    addTearDown(state.dispose);
    await state.refresh();
    await state.mutate('claim');
    expect(state.accessRevoked, isTrue);
    expect(state.uncertain, isFalse);
    expect(state.pendingKey, isNull);
    expect(state.booking, isNull);
  });

  test(
      'expired claim and completed booking disable decision; role1 cannot reassign',
      () async {
    var terminal = false;
    final log = <http.Request>[];
    final session = await adminSession(
        (request) async => request.url.path.endsWith('/b1')
            ? jsonResponse({
                'data': operationalBooking(
                    terminal ? 'confirmed' : 'pending_approval')
              })
            : jsonResponse(pageEnvelope([
                {
                  ...operationalQueueRow(owner: 'admin-1'),
                  'expires_at': DateTime.now()
                      .toUtc()
                      .subtract(const Duration(seconds: 1))
                      .toIso8601String()
                }
              ])),
        role: 1,
        log: log);
    final state = ApprovalDetailState(repositoryFor(session), 'b1');
    addTearDown(state.dispose);
    await state.refresh();
    expect(state.canDecide, isFalse);
    expect(state.canReassign, isFalse);
    await state.mutate('reassign', adminGuid: 'target', reason: 'Shift');
    terminal = true;
    await state.refresh();
    expect(state.canClaim, isFalse);
    expect(state.canDecide, isFalse);
    expect(log.where((request) => request.method == 'POST'), isEmpty);
  });

  test('422 reassignment stays a definite failure and preserves field message',
      () async {
    final session = await adminSession((request) async {
      if (request.method == 'POST') {
        return jsonResponse({
          'message': 'Admin tujuan tidak ditugaskan.',
          'errors': {
            'admin_guid': ['Admin tujuan tidak ditugaskan.']
          }
        }, 422);
      }
      return request.url.path.endsWith('/b1')
          ? jsonResponse({'data': operationalBooking()})
          : jsonResponse(pageEnvelope([operationalQueueRow(owner: 'other')]));
    });
    final state = ApprovalDetailState(repositoryFor(session), 'b1');
    addTearDown(state.dispose);
    await state.refresh();
    await state.mutate('reassign', adminGuid: 'target', reason: 'Shift');
    expect(state.uncertain, isFalse);
    expect(state.message, contains('tidak ditugaskan'));
    expect(state.claim!.ownerGuid, 'other');
  });
  test('explicit claim before decisions, server confirmation then release',
      () async {
    String? owner;
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.method == 'POST') {
        owner = request.url.path.endsWith('/claim') ? 'admin-1' : null;
        return jsonResponse({'data': operationalClaim(owner)});
      }
      return request.url.path.endsWith('/b1')
          ? jsonResponse({'data': operationalBooking()})
          : jsonResponse(pageEnvelope([operationalQueueRow(owner: owner)]));
    }, role: 1, log: log);
    final state = ApprovalDetailState(repositoryFor(session), 'b1');
    addTearDown(state.dispose);
    await state.refresh();
    expect(state.canClaim, isTrue);
    expect(state.canDecide, isFalse);
    await state.decide(approve: true);
    expect(log.where((request) => request.method == 'POST'), isEmpty);
    await state.mutate('claim');
    expect(state.canDecide, isTrue);
    await state.mutate('release');
    expect(state.canDecide, isFalse);
    expect(state.canClaim, isTrue);
  });

  test('claim lookup reads later pages without unsupported booking filter',
      () async {
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('/b1')) {
        return jsonResponse({'data': operationalBooking()});
      }
      final page = int.parse(request.url.queryParameters['page']!);
      return jsonResponse(pageEnvelope([
        operationalQueueRow(owner: 'admin-1', guid: page == 1 ? 'other' : 'b1')
      ], page: page, last: 2));
    }, role: 1, log: log);
    final state = ApprovalDetailState(repositoryFor(session), 'b1');
    addTearDown(state.dispose);
    await state.refresh();
    expect(state.mine, isTrue);
    expect(log.where((request) => request.url.path.endsWith('approval-queue')),
        hasLength(2));
    expect(
        log.any((request) =>
            request.url.queryParameters.containsKey('booking_guid')),
        isFalse);
  });

  test('409 claim_owned rereads state and sends no second mutation', () async {
    String? owner;
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.method == 'POST') {
        owner = 'other';
        return conflict('claim_owned');
      }
      return request.url.path.endsWith('/b1')
          ? jsonResponse({'data': operationalBooking()})
          : jsonResponse(pageEnvelope([operationalQueueRow(owner: owner)]));
    }, role: 1, log: log);
    final state = ApprovalDetailState(repositoryFor(session), 'b1');
    addTearDown(state.dispose);
    await state.refresh();
    await state.mutate('claim');
    expect(state.claim!.ownerGuid, 'other');
    expect(state.canDecide, isFalse);
    expect(log.where((request) => request.method == 'POST'), hasLength(1));
    expect(state.message, contains('Admin lain'));
  });

  test(
      'unknown claim keeps key and payload across refresh and explicit recovery',
      () async {
    String? owner;
    final log = <http.Request>[];
    var mutations = 0;
    final session = await adminSession((request) async {
      if (request.method == 'POST') {
        owner = 'admin-1';
        mutations++;
        if (mutations == 1) throw TimeoutException('timeout');
        return jsonResponse({'data': operationalClaim(owner)});
      }
      return request.url.path.endsWith('/b1')
          ? jsonResponse({'data': operationalBooking()})
          : jsonResponse(pageEnvelope([operationalQueueRow(owner: owner)]));
    }, role: 1, log: log);
    final state = ApprovalDetailState(repositoryFor(session), 'b1');
    addTearDown(state.dispose);
    await state.refresh();
    await state.mutate('claim');
    final key = state.pendingKey;
    expect(key, isNotNull);
    expect(state.uncertain, isTrue);
    expect(state.canDecide, isFalse);
    await state.refresh();
    expect(state.pendingKey, key);
    await state.mutate('release');
    expect(mutations, 1);
    await state.recoverMutation();
    final posts = log.where((request) => request.method == 'POST').toList();
    expect(posts, hasLength(2));
    expect(posts.first.headers, posts.last.headers);
    expect(posts.first.body, posts.last.body);
    expect(state.uncertain, isFalse);
    expect(state.canDecide, isTrue);
  });

  test('confirmed write followed by failed read stays refreshable', () async {
    var written = false;
    var failRead = true;
    final session = await adminSession((request) async {
      if (request.method == 'POST') {
        written = true;
        return jsonResponse({'data': operationalClaim('admin-1')});
      }
      if (written && failRead) throw TimeoutException('read timeout');
      return request.url.path.endsWith('/b1')
          ? jsonResponse({'data': operationalBooking()})
          : jsonResponse(pageEnvelope(
              [operationalQueueRow(owner: written ? 'admin-1' : null)]));
    }, role: 1);
    final state = ApprovalDetailState(repositoryFor(session), 'b1');
    addTearDown(state.dispose);
    await state.refresh();
    await state.mutate('claim');
    expect(state.uncertain, isFalse);
    expect(state.fresh, isFalse);
    failRead = false;
    await state.refresh();
    expect(state.canDecide, isTrue);
  });

  test('assignment revoke purges private booking and prevents new writes',
      () async {
    var revoked = false;
    final session = await adminSession((request) async {
      if (revoked) return jsonResponse({'message': 'Forbidden'}, 403);
      return request.url.path.endsWith('/b1')
          ? jsonResponse({'data': operationalBooking()})
          : jsonResponse(pageEnvelope([operationalQueueRow(owner: 'admin-1')]));
    }, role: 1);
    final state = ApprovalDetailState(repositoryFor(session), 'b1');
    addTearDown(state.dispose);
    await state.refresh();
    revoked = true;
    await state.refresh();
    expect(state.accessRevoked, isTrue);
    expect(state.booking, isNull);
    expect(state.claim, isNull);
    expect(state.canDecide, isFalse);
    expect(state.canClaim, isFalse);
  });

  test('role change with same generation drops in-flight private response',
      () async {
    final pending = Completer<http.Response>();
    final session = await adminSession((_) => pending.future);
    final state = ApprovalDetailState(repositoryFor(session), 'b1');
    addTearDown(state.dispose);
    final loading = state.refresh();
    session.role = 1;
    session.sessionChanges.value++;
    pending.complete(jsonResponse({'data': operationalBooking()}));
    await loading;
    expect(state.booking, isNull);
    expect(state.valid, isFalse);
  });

  test('decision rereads ownership before POST and blocks changed owner',
      () async {
    var owner = 'admin-1';
    final log = <http.Request>[];
    final session = await adminSession(
        (request) async => request.url.path.endsWith('/b1')
            ? jsonResponse({'data': operationalBooking()})
            : jsonResponse(pageEnvelope([operationalQueueRow(owner: owner)])),
        role: 1,
        log: log);
    final state = ApprovalDetailState(repositoryFor(session), 'b1');
    addTearDown(state.dispose);
    await state.refresh();
    expect(state.canDecide, isTrue);
    owner = 'other';
    await state.decide(approve: true);
    expect(state.canDecide, isFalse);
    expect(log.where((request) => request.method == 'POST'), isEmpty);
  });
}
