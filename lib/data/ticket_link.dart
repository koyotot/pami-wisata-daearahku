/// Parsed `/tickets/{booking_guid}` App Link route name (the e-ticket email link).
///
/// The link carries a booking GUID only: no token, no query. Ownership is decided by the server
/// when the booking is loaded, so a valid-looking link proves nothing by itself.
class TicketLink {
  const TicketLink._(this.bookingGuid);

  /// Lower-case booking GUID.
  final String bookingGuid;

  static final _uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false);

  /// Returns null unless [routeName] is exactly `/tickets/{uuid}` (one optional trailing slash).
  /// A query, a fragment, extra or empty segments, encoded characters and non-UUID values are all rejected.
  /// Any scheme/host in [routeName] is rejected too: Flutter hands over path and query only.
  static TicketLink? parse(String? routeName) {
    if (routeName == null || !routeName.startsWith('/')) return null;
    if (routeName.contains('?') || routeName.contains('#')) return null;
    final Uri uri;
    try {
      uri = Uri.parse(routeName);
    } on FormatException {
      return null;
    }
    if (uri.hasQuery || uri.hasFragment || uri.hasAuthority) return null;
    var segments = uri.pathSegments;
    if (segments.length == 3 && segments[2].isEmpty) {
      segments = segments.sublist(0, 2);
    }
    if (segments.length != 2 ||
        segments[0] != 'tickets' ||
        !_uuid.hasMatch(segments[1])) {
      return null;
    }
    return TicketLink._(segments[1].toLowerCase());
  }
}

/// The ticket link a signed-out visitor opened, kept in memory only until the next sign-in so the
/// app can continue to the ticket. It holds a booking GUID, never a token, and expires.
class PendingTicketLink {
  PendingTicketLink._();

  static const lifetime = Duration(minutes: 30);
  static DateTime Function() clock = DateTime.now;
  static String? _guid;
  static DateTime? _at;

  /// Remembers [bookingGuid] when it is a plain UUID; anything else is ignored.
  static void remember(String bookingGuid) {
    final link = TicketLink.parse('/tickets/$bookingGuid');
    if (link == null) return;
    _guid = link.bookingGuid;
    _at = clock();
  }

  /// Returns the remembered GUID once, or null when none is pending or it is stale.
  static String? take() {
    final guid = _guid;
    final at = _at;
    clear();
    if (guid == null || at == null || clock().difference(at) > lifetime) {
      return null;
    }
    return guid;
  }

  static void clear() {
    _guid = null;
    _at = null;
  }
}
