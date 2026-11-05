import 'admin_test_support.dart';

Map<String, dynamic> operationalBooking([String status = 'pending_approval']) =>
    {
      ...bookingJson('b1', status),
      'approval_expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 20))
          .toIso8601String(),
    };

Map<String, dynamic> operationalQueueRow({String? owner, String guid = 'b1'}) =>
    {
      'booking_guid': guid,
      'destination_guid': 'dest-1',
      'destination_name_snapshot': 'Pantai Indah',
      'status': 'pending_approval',
      'approval_expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 20))
          .toIso8601String(),
      'claim_guid': owner == null ? null : 'claim-1',
      'owner_user_guid': owner,
      'expires_at': owner == null
          ? null
          : DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 15))
              .toIso8601String(),
      'claim_state': owner == null ? 'unclaimed' : 'active',
      'action': 'pending_approval',
    };

Map<String, dynamic> operationalClaim(String? owner) => {
      ...operationalQueueRow(owner: owner),
      'state': owner == null ? 'unclaimed' : 'active',
    };
