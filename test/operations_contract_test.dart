import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'admin_test_support.dart';
import 'operations_test_support.dart';

void main() {
  test('reports preserve null metrics and collection metadata/date bases',
      () async {
    final log = <http.Request>[];
    final session = await adminSession((request) async {
      if (request.url.path.endsWith('overview') ||
          request.url.path.endsWith('approvals') ||
          request.url.path.endsWith('visitors')) {
        return jsonResponse({
          'data': {
            'generated_at': '2026-11-05T00:00:00Z',
            'metrics': {'attendance_rate': null, 'checked_in_tickets': 4},
            'financial': {'availability': 'unavailable', 'gross_revenue': null},
            'staff': [
              {'admin_guid': 'a1', 'decisions': 3}
            ],
            'personal': {'sla_compliance_percent': null}
          }
        });
      }
      return jsonResponse({
        ...pageEnvelope([
          request.url.path.endsWith('destinations')
              ? {
                  'destination_guid': 'd1',
                  'name': 'Pantai',
                  'capacity': 0,
                  'reserved_occupancy_percent': null
                }
              : operationalQueueRow()
        ]),
        'meta': {
          'last_page': 2,
          'generated_at': 'snapshot',
          'period': {'date_basis': 'visit'}
        }
      });
    }, log: log);
    final repo = repositoryFor(session);
    for (final section in ['overview', 'approvals', 'visitors']) {
      final report = await repo.operationalReport(section,
          query: {'from': '2026-11-01', 'to': '2026-11-05'});
      expect(report.financial['gross_revenue'], isNull);
      expect(report.personal['sla_compliance_percent'], isNull);
      expect(report.metrics['attendance_rate'], isNull);
      expect(report.generatedAt, '2026-11-05T00:00:00Z');
    }
    for (final section in ['destinations', 'action-center', 'approval-queue']) {
      final rows = await repo
          .operationalRows(section, query: {'page': '1', 'per_page': '30'});
      expect(rows.meta!['generated_at'], 'snapshot');
      expect(rows.meta!['last_page'], 2);
      expect(rows.links!['next'], isNull);
      expect(rows.items, hasLength(1));
    }
    expect(
        log.any(
            (request) => request.url.queryParameters.containsKey('date_basis')),
        isFalse);
  });

  test(
      'claim release and reassign use exact authenticated routes, body and key',
      () async {
    final log = <http.Request>[];
    final session = await adminSession(
        (_) async => jsonResponse({'data': operationalClaim('admin-1')}),
        log: log);
    final repo = repositoryFor(session);
    await repo.mutateApprovalClaim('b1', 'claim', 'claim-key');
    await repo.mutateApprovalClaim('b1', 'release', 'release-key');
    await repo.mutateApprovalClaim('b1', 'reassign', 'reassign-key',
        body: {'admin_guid': 'a2', 'reason': 'Giliran tugas'});
    expect(log.map((request) => request.url.path), [
      '/api/v1/admin/bookings/b1/claim',
      '/api/v1/admin/bookings/b1/release',
      '/api/v1/superadmin/bookings/b1/reassign'
    ]);
    expect(
        log.map((request) =>
            request.headers['Idempotency-Key'] ??
            request.headers['idempotency-key']),
        ['claim-key', 'release-key', 'reassign-key']);
    expect(jsonDecode(log.last.body),
        {'admin_guid': 'a2', 'reason': 'Giliran tugas'});
    expect(
        log.every(
            (request) => request.headers['authorization'] == 'Bearer access'),
        isTrue);
  });
}
