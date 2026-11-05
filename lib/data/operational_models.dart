import '../services/api_client.dart';
import '../services/auth_session.dart';

Json _object(dynamic value) => value is Json ? value : const {};
List<Json> _rows(dynamic value) =>
    value is List ? value.whereType<Json>().toList() : const [];

/// Retains unavailable/null metrics and the server's metric/date bases.
class OperationalReport {
  final Json raw;
  OperationalReport(this.raw);
  Json get metrics => _object(raw['metrics']);
  Json get personal => _object(raw['personal']);
  Json get financial => _object(raw['financial']);
  Json get scope => _object(raw['scope']);
  Json get period => _object(raw['period']);
  Json get assignedWorkload => _object(raw['assigned_workload']);
  Json get visitors => _object(raw['visitors']);
  List<Json> get bookingTrend => _rows(raw['booking_trend']);
  List<Json> get series => _rows(raw['series']);
  List<Json> get staff => _rows(raw['staff']);
  List<Json> get staffWorkload => _rows(raw['staff_workload']);
  String? get generatedAt => raw['generated_at'] as String?;
}

class OperationalRow {
  final Json raw;
  OperationalRow(this.raw);
  String? get bookingGuid => raw['booking_guid'] as String?;
  String? get destinationGuid => raw['destination_guid'] as String?;
  String? get name =>
      (raw['name'] ?? raw['destination_name_snapshot']) as String?;
  String? get action => raw['action'] as String?;
  String? get claimState => raw['claim_state'] as String?;
  ApprovalClaim get claim => ApprovalClaim({...raw, 'state': claimState});
}

class ApprovalClaim {
  final Json raw;
  ApprovalClaim(this.raw) {
    if (raw['booking_guid'] is! String ||
        (raw['booking_guid'] as String).isEmpty ||
        !const ['active', 'unclaimed'].contains(raw['state']) ||
        approvalExpiresAt == null ||
        (raw['state'] == 'active' &&
            (ownerGuid == null || expiresAt == null))) {
      throw const ApiException(
          'Respons claim tidak valid.', null, 'invalid_response');
    }
  }
  String? get ownerGuid => raw['owner_user_guid'] as String?;
  DateTime? get expiresAt =>
      DateTime.tryParse(raw['expires_at'] as String? ?? '');
  DateTime? get approvalExpiresAt =>
      DateTime.tryParse(raw['approval_expires_at'] as String? ?? '');
  bool get active => raw['state'] == 'active' && ownerGuid != null;
  bool activeAt(DateTime now) =>
      active &&
      expiresAt != null &&
      approvalExpiresAt != null &&
      expiresAt!.isAfter(now) &&
      approvalExpiresAt!.isAfter(now);
}

String operationalActionLabel(String? value) => switch (value) {
      'upcoming_visit' => 'Kunjungan mendatang',
      'approval_deadline_passed' => 'Batas persetujuan lewat',
      'expired_claim' => 'Claim kedaluwarsa',
      'approval_deadline_approaching' => 'Mendekati batas persetujuan',
      _ => 'Menunggu persetujuan',
    };
