import '../services/auth_session.dart';
import '../services/api_error_messages.dart';

/// Codes for which the server provably did NOT create a booking for a create request.
/// A fresh local intent is discarded on these (the attempt can never succeed as-is).
const definitiveCreateRejections = {
  'quota_unavailable',
  'insufficient_capacity',
  'booking_window_closed',
  'visit_date_too_close',
  'idempotency_conflict',
};

/// Indonesian message for a booking-related [error].
///
/// Maps the stable Laravel `code` (never only the HTTP status, so 409s are not all alike).
/// [mutation] marks a create/cancel call: an unknown outcome (timeout, network, 5xx or an
/// unreadable response) is then reported as "result unknown" and never as success or failure.
String bookingErrorMessage(Object error, {bool mutation = false}) {
  if (error is! ApiException) {
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
  return apiDomainMessage(error.code, error.context) ??
      (mutation && error.outcomeUnknown
          ? unknownMutationMessage
          : error.message);
}
