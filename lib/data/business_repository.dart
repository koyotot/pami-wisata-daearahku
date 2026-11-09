import 'dart:convert';
import 'ticket_models.dart';
import 'operational_models.dart';
import 'payment_models.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';

/// Resource data retains Laravel GUIDs and fields without inventing legacy IDs.
class Category {
  final Json json;
  Category(this.json) {
    guid;
    name;
  }
  String get guid => json['guid'] as String;
  String get name => json['name'] as String;
  String get slug => json['slug'] as String? ?? '';
  bool get isActive => json['is_active'] as bool? ?? true;
}

class Facility {
  final Json json;
  Facility(this.json) {
    guid;
    name;
  }
  String get guid => json['guid'] as String;
  String get name => json['name'] as String;
  String get slug => json['slug'] as String? ?? '';
  String? get iconKey => json['icon_key'] as String?;
  bool get isActive => json['is_active'] as bool? ?? true;
}

class DestinationImage {
  final Json json;
  DestinationImage(this.json);
  String get guid => json['guid'] as String;
  int get sequence => (json['sequence'] as num).toInt();
  String url(String variant) => (json['urls'] as Map)[variant] as String;
}

class Destination {
  final Json json;
  Destination(this.json) {
    guid;
    name;
  }
  String get guid => json['guid'] as String;
  String get name => json['name'] as String;
  String get categoryGuid => json['destination_category_guid'] as String? ?? '';
  Category? get category =>
      json['category'] is Json ? Category(json['category'] as Json) : null;
  String get location => json['location'] as String? ?? '';
  double? get latitude => _coordinate(json['latitude'], 90);
  double? get longitude => _coordinate(json['longitude'], 180);
  bool get hasCoordinates => latitude != null && longitude != null;

  static double? _coordinate(dynamic value, double limit) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number != null && number.isFinite && number.abs() <= limit
        ? number
        : null;
  }

  String get description => json['description'] as String? ?? '';
  int get ticketPrice => (json['ticket_price'] as num?)?.toInt() ?? 0;
  String get currency => json['currency'] as String? ?? 'IDR';
  String get openingHours => json['opening_hours'] as String? ?? '';
  String get timezone => json['timezone'] as String? ?? 'Asia/Jakarta';
  bool get isActive => json['is_active'] as bool? ?? true;
  double? get ratingAverage => (json['rating_average'] as num?)?.toDouble();
  int get ratingCount => (json['rating_count'] as num?)?.toInt() ?? 0;
  List<Facility> get facilities => (json['facilities'] as List? ?? const [])
      .map((item) => Facility(item as Json))
      .toList();

  int get galleryVersion => (json['gallery_version'] as num?)?.toInt() ?? 0;
  List<DestinationImage> get images {
    final items = (json['images'] as List? ?? [])
        .map((e) => DestinationImage(e as Json))
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    if (items.isNotEmpty ||
        (json.containsKey('images') && galleryVersion > 0)) {
      return items;
    }
    final url = imageUrl;
    return url == null
        ? []
        : [
            DestinationImage({
              'guid': 'legacy-$guid',
              'sequence': 1,
              'urls': {'thumbnail': url, 'display': url, 'fullscreen': url}
            })
          ];
  }

  /// Path relative to the API base URL (versioned by Laravel), or null without a picture.
  /// `image_path` is never used: it is an internal storage path, not a URL.
  String? get imageUrl {
    final url = json['image_url'];
    return url is String && url.isNotEmpty ? url : null;
  }
}

class Favorite {
  final Json json;
  Favorite(this.json) {
    guid;
    destination;
  }
  String get guid => json['guid'] as String;
  Destination get destination => Destination(json['destination'] as Json);
}

/// Booking is also the API representation of a legacy Pendaftar.
class Booking {
  final Json json;
  Booking(this.json) {
    guid;
  }
  String get guid => json['guid'] as String;
  String get bookingNumber => json['booking_number'] as String? ?? '';
  String get destinationGuid => json['destination_guid'] as String? ?? '';
  String get visitorName => json['visitor_name'] as String;
  String get visitorEmail => json['visitor_email'] as String? ?? '';
  String get visitorPhone => json['visitor_phone'] as String? ?? '';
  String get destinationName => json['destination_name'] as String;
  String get visitDate => json['visit_date'] as String? ?? '';
  int get quantity => (json['quantity'] as num?)?.toInt() ?? 0;
  int get totalAmount => (json['total_amount'] as num?)?.toInt() ?? 0;

  /// An explicit Rp0 total. A missing amount is never read as free.
  bool get isFree => json['total_amount'] is num && totalAmount == 0;
  String get currency => json['currency'] as String? ?? 'IDR';
  String? get notes => json['notes'] as String?;
  String get status => json['status'] as String;

  String get paymentStatus => json['payment_status'] as String? ?? 'unverified';
  DateTime? get paymentExpiresAt =>
      DateTime.tryParse(json['payment_expires_at'] as String? ?? '');
  String? get paymentProvider => json['payment_provider'] as String?;
  String? get paymentEnvironment => json['payment_environment'] as String?;
  bool get paymentTestOnly => json['payment_test_only'] == true;
  String? get paymentLabel => json['payment_label'] as String?;

  /// Server-computed: true only while the owner may still cancel (pending approval).
  bool get cancellable => json['cancellable'] == true;
  int get checkedInCount =>
      (json['checked_in_count'] as num?)?.toInt() ??
      (checkedInAt == null ? 0 : quantity);
  bool get canReview => json['can_review'] == true;
  DateTime? get checkedInAt =>
      DateTime.tryParse(json['checked_in_at'] as String? ?? '');
  Review? get review =>
      json['review'] is Json ? Review(json['review'] as Json) : null;
  DateTime? get createdAt =>
      DateTime.tryParse(json['created_at'] as String? ?? '');
}

class Review {
  final Json json;
  Review(this.json) {
    guid;
  }
  String get guid => json['guid'] as String;
  String get bookingGuid => json['booking_guid'] as String? ?? '';
  String get destinationGuid => json['destination_guid'] as String;
  String get destinationName => json['destination_name'] as String? ?? '';
  int get rating => (json['rating'] as num).toInt();
  String get comment => json['comment'] as String;
  DateTime? get createdAt =>
      DateTime.tryParse(json['created_at'] as String? ?? '');
}

class ProfileStatistics {
  final Json json;
  ProfileStatistics(this.json);
  int get bookings => (json['bookings'] as num).toInt();
  int get reviews => (json['reviews'] as num).toInt();
  int get visits => (json['visits'] as num).toInt();
}

/// Server-computed availability for one destination and visit date.
/// [status]: open, full, closed, not_open_yet, too_close, unavailable.
class Availability {
  final Json json;
  Availability(this.json) {
    visitDate;
    status;
  }
  String get visitDate => json['visit_date'] as String;
  int get capacity => (json['capacity'] as num?)?.toInt() ?? 0;
  int get allocated => (json['allocated'] as num?)?.toInt() ?? 0;
  int get remaining => (json['remaining'] as num?)?.toInt() ?? 0;
  String get status => json['status'] as String;
  bool get isOpen => status == 'open';
  DateTime? get opensAt =>
      DateTime.tryParse(json['booking_opens_at'] as String? ?? '');
  DateTime? get closesAt =>
      DateTime.tryParse(json['booking_closes_at'] as String? ?? '');
}

/// Calendar-only destination date; nullable quota values remain unknown.
class AvailabilityDay {
  final Json json;
  AvailabilityDay(this.json);
  String get date => json['date'] as String;
  int? get capacity => (json['capacity'] as num?)?.toInt();
  int? get remaining => (json['remaining'] as num?)?.toInt();
  double? get remainingPercent =>
      (json['remaining_percent'] as num?)?.toDouble();
  String get level => json['level'] as String? ?? 'none';
  String get status => json['status'] as String? ?? 'unavailable';
  bool get bookable => json['bookable'] == true && status == 'available';
}

class MonthlyAvailability {
  final Json json;
  MonthlyAvailability(this.json);
  String get destinationGuid => json['destination_guid'] as String;
  String get month => json['month'] as String;
  String get timezone => json['timezone'] as String;
  int get requestedQuantity => (json['requested_quantity'] as num).toInt();
  List<AvailabilityDay> get dates => (json['dates'] as List)
      .map((item) => AvailabilityDay(item as Json))
      .toList();
  AvailabilityDay? onDate(String date) {
    for (final day in dates) {
      if (day.date == date) return day;
    }
    return null;
  }
}

/// Administrative quota row: total capacity, allocated and remaining are distinct values.
class QuotaEntry {
  final Json json;
  QuotaEntry(this.json) {
    visitDate;
  }
  String get guid => json['guid'] as String;
  String get visitDate => json['visit_date'] as String;
  int get capacity => (json['capacity'] as num?)?.toInt() ?? 0;
  int get allocated => (json['allocated'] as num?)?.toInt() ?? 0;
  int get remaining => (json['remaining'] as num?)?.toInt() ?? 0;
  DateTime? get opensAt =>
      DateTime.tryParse(json['booking_opens_at'] as String? ?? '');
  DateTime? get closesAt =>
      DateTime.tryParse(json['booking_closes_at'] as String? ?? '');
}

/// Result of reconciling a create attempt by its Idempotency-Key.
/// [state]: completed, not_found or abandoned.
class BookingIntentState {
  final Json json;
  BookingIntentState(this.json) {
    state;
  }
  String get state => json['state'] as String;
  bool get replaySafe => json['replay_safe'] == true;
  bool get keyExpired => json['key_expired'] == true;
  Booking? get booking =>
      json['booking'] is Json ? Booking(json['booking'] as Json) : null;
}

/// Issued documents; an entry is null until the backend has issued it.
/// An invoice is a booking confirmation, not proof of payment.
class BookingDocuments {
  final Json json;
  BookingDocuments(this.json);
  Json? get invoice => json['invoice'] is Json ? json['invoice'] as Json : null;

  /// Booking confirmation PDF for the group. It is NOT an admission ticket and carries no token;
  /// entry tickets are described only by [entryTickets].
  Json? get ticket => json['ticket'] is Json ? json['ticket'] as Json : null;

  /// Always false on current servers; kept so a stray `true` could never be mistaken for an entry ticket.
  bool get ticketLegacy => ticket?['legacy'] == true;
  bool get ticketAdmission => ticket?['admission'] == true;

  /// The confirmation PDF may be downloaded only when the server says so. An older server that sends
  /// no `download_available` flag keeps the previous behavior: a present `ticket` is downloadable.
  bool get ticketDownloadAvailable {
    final t = ticket;
    if (t == null) return false;
    return t.containsKey('download_available')
        ? t['download_available'] == true
        : true;
  }

  /// Per-visitor entry QR tickets. Null on an older server or when the object is malformed.
  EntryTicketsInfo? get entryTickets {
    final value = json['entry_tickets'];
    if (value is! Json || value['state'] is! String) return null;
    return EntryTicketsInfo(value);
  }

  /// Whether entry QR tickets exist (scheduled, available or used). With `entry_tickets` only its
  /// state decides; the legacy `ticket` document never does. Without it (older server) the previous
  /// rule applies, except that a document the server marks as not admission is not an entry ticket.
  bool get entryTicketsIssued {
    final entry = entryTickets;
    if (entry != null) return entry.issued;
    final t = ticket;
    return t != null && t['admission'] != false && t['legacy'] != true;
  }

  /// Paid receipt entry; absent on older servers, which means unavailable.
  Json? get receipt => json['receipt'] is Json ? json['receipt'] as Json : null;
  bool get receiptAvailable => receipt?['download_available'] == true;
}

/// `entry_tickets` of the documents response. Only [state] says whether QR tickets are available,
/// scheduled or revoked.
class EntryTicketsInfo {
  final Json json;
  EntryTicketsInfo(this.json);
  String get state => json['state'] as String;
  int? get quantity {
    final value = json['quantity'];
    return value is num ? value.toInt() : null;
  }

  /// Calendar date (YYYY-MM-DD) the QR becomes visible.
  String? get qrAvailableFrom {
    final value = json['qr_available_from'];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// `paid`, `free`, `unverified`, ...
  String? get entitlement => json['entitlement'] as String?;
  bool get isFree => entitlement == 'free';
  bool get issued => const {
        'scheduled',
        'available',
        'partially_checked_in',
        'fully_checked_in',
      }.contains(state);
}

class AdminAccount {
  final Json json;
  AdminAccount(this.json) {
    guid;
  }
  String get guid => json['guid'] as String;
  String get name => json['name'] as String? ?? '';
  String get email => json['email'] as String? ?? '';
  int get role => (json['role'] as num?)?.toInt() ?? 0;
  String get status => json['status'] as String? ?? 'active';
  bool get isActive => status == 'active';
}

class BusinessRepository {
  final ApiClient api;
  BusinessRepository([ApiClient? api]) : api = api ?? ApiClient();
  String _path(String path, Map<String, String>? query) => Uri(
          path: path,
          queryParameters: query == null || query.isEmpty ? null : query)
      .toString();
  String _id(String guid) => Uri.encodeComponent(guid);

  // ── Catalog (public) ───────────────────────────────────────
  Future<ApiPage<Category>> categories({Map<String, String>? query}) =>
      api.collection(_path('categories', query), Category.new);
  Future<ApiPage<Destination>> destinations({Map<String, String>? query}) =>
      api.collection(_path('destinations', query), Destination.new);
  Future<Destination> destination(String guid) async =>
      Destination(await api.object('GET', 'destinations/${_id(guid)}'));

  Future<ApiPage<Facility>> superadminFacilities(
          {String status = 'all', int page = 1, int perPage = 50}) =>
      api.collection(
          _path('superadmin/facilities', {
            'status': status,
            'page': '$page',
            'per_page': '$perPage',
          }),
          Facility.new,
          authenticated: true);

  Future<ApiPage<Facility>> activeFacilities(
          {int page = 1, int perPage = 50}) =>
      api.collection(
          _path('facilities', {
            'page': '$page',
            'per_page': '$perPage',
          }),
          Facility.new,
          authenticated: true);

  Future<Facility> createFacility(Json fields) async =>
      Facility(await api.object('POST', 'superadmin/facilities',
          authenticated: true, body: {...fields, 'icon_key': null}));

  Future<Facility> updateFacility(String guid, Json fields) async =>
      Facility(await api.object('PATCH', 'superadmin/facilities/${_id(guid)}',
          authenticated: true,
          body: {...fields, 'icon_key': null}..remove('slug')));

  Future<void> deactivateFacility(String guid) async {
    await api.object('DELETE', 'superadmin/facilities/${_id(guid)}',
        authenticated: true);
  }

  Future<Destination> assignDestinationFacilities(
          String guid, List<String> facilityGuids) async =>
      Destination(await api.object(
          'PUT', 'admin/destinations/${_id(guid)}/facilities',
          authenticated: true,
          body: {'facility_guids': facilityGuids.toSet().toList()}));

  /// Image bytes for a destination's `image_url` (public, active destinations).
  Future<BinaryResponse> imageBytes(String imageUrl) =>
      api.session.publicBytes(imageUrl);

  /// Image bytes for any destination, including inactive ones (role >= 1).
  Future<BinaryResponse> adminImageBytes(String guid, String imageUrl) {
    if (imageUrl.contains('/images/')) {
      final path = imageUrl.replaceFirst(
          RegExp(r'^/?(?:api/v1/)?(?:admin/)?destinations/'),
          'admin/destinations/');
      return api.session.requestBytes(path);
    }
    final version = Uri.tryParse(imageUrl)?.queryParameters['v'];
    return api.session.requestBytes(
        'admin/destinations/${_id(guid)}/image${version == null ? '' : '?v=$version'}');
  }

  // ── Favorites ──────────────────────────────────────────────
  Future<ApiPage<Favorite>> favorites({Map<String, String>? query}) => api
      .collection(_path('favorites', query), Favorite.new, authenticated: true);
  Future<Favorite> addFavorite(String guid) async => Favorite(
      await api.object('PUT', 'favorites/${_id(guid)}', authenticated: true));
  Future<void> removeFavorite(String guid) async {
    await api.object('DELETE', 'favorites/${_id(guid)}', authenticated: true);
  }

  // ── Bookings (owner) ───────────────────────────────────────
  /// [query] supports `status`, `per_page` and `page`.
  Future<ApiPage<Booking>> bookings({Map<String, String>? query}) => api
      .collection(_path('bookings', query), Booking.new, authenticated: true);
  Future<Booking> booking(String guid) async => Booking(
      await api.object('GET', 'bookings/${_id(guid)}', authenticated: true));
  Future<PaymentSnapshot> paymentMethods(String guid) async => PaymentSnapshot(
      await api.object('GET', _path('payments/methods', {'booking_guid': guid}),
          authenticated: true));
  Future<PaymentSnapshot> paymentIntent(String guid) async => PaymentSnapshot(
      await api.object('GET', 'bookings/${_id(guid)}/payment-intent',
          authenticated: true));

  /// Refund requests of a booking, newest first (owner only).
  Future<List<RefundRequest>> refundRequests(String guid) async {
    final data = await api.object(
        'GET', 'bookings/${_id(guid)}/refund-requests',
        authenticated: true);
    final list = data['refund_requests'];
    if (list is! List) {
      throw const ApiException(
          'Respons pengembalian dana tidak valid.', null, 'invalid_response');
    }
    return [
      for (final item in list)
        RefundRequest(item is Json
            ? item
            : throw const ApiException('Respons pengembalian dana tidak valid.',
                null, 'invalid_response'))
    ];
  }

  /// Files a refund request. The body is only the reason: amount, currency and status belong to
  /// Laravel. [key] is the Idempotency-Key reused until the outcome is known.
  Future<RefundRequest> requestRefund(
      String guid, String key, String reason) async {
    final data = await api.object(
        'POST', 'bookings/${_id(guid)}/refund-requests',
        authenticated: true,
        body: {'reason': reason},
        headers: {'Idempotency-Key': key});
    final nested = data['refund_request'];
    return RefundRequest(nested is Json ? nested : data);
  }

  Future<Json> initiateDemoPayment(String guid, String key) =>
      api.object('POST', 'bookings/${_id(guid)}/demo-payment',
          authenticated: true, body: {}, headers: {'Idempotency-Key': key});
  Future<Json> initiateEwalletPayment(
          String guid, String key, String channel) =>
      api.object('POST', 'bookings/${_id(guid)}/payment-attempts',
          authenticated: true,
          body: {'method_code': 'ewallet', 'channel': channel},
          headers: {'Idempotency-Key': key});


  /// Starts a BNI virtual account or QRIS payment. The body is only `method_code` and `channel`:
  /// amount, currency, provider, environment, status and time fields belong to Laravel.
  Future<Json> initiatePayment(String guid, String key,
          {required String methodCode, required String channel}) =>
      api.object('POST', 'bookings/${_id(guid)}/payment-attempts',
          authenticated: true,
          body: {'method_code': methodCode, 'channel': channel},
          headers: {'Idempotency-Key': key});

  /// Private no-store SVG of the provider QRIS payload for an unfinished attempt (owner only).
  Future<BinaryResponse> paymentQr(String guid, String attemptGuid) =>
      api.session.requestBytes(
          'bookings/${_id(guid)}/payment-attempts/${_id(attemptGuid)}/qr');

  /// Asks the server to run its authenticated provider status inquiry for [attemptGuid].
  /// Never proves payment on its own: read the returned snapshot.
  Future<PaymentSnapshot> refreshPaymentAttempt(
          String guid, String attemptGuid) async =>
      PaymentSnapshot(await api.object('POST',
          'bookings/${_id(guid)}/payment-attempts/${_id(attemptGuid)}/refresh',
          authenticated: true));
  Future<Json> simulateDemoPayment(
          String guid, String key, String attemptGuid, String outcome) =>
      api.object('POST', 'bookings/${_id(guid)}/demo-payment/simulate',
          authenticated: true,
          body: {'attempt_guid': attemptGuid, 'outcome': outcome},
          headers: {'Idempotency-Key': key});
  Future<Booking> createBooking(Json fields, String idempotencyKey) async =>
      Booking(await api.object('POST', 'bookings',
          authenticated: true,
          body: fields,
          headers: {'Idempotency-Key': idempotencyKey}));

  /// Only a booking still awaiting approval can be cancelled (owner only).
  Future<Booking> cancelBooking(String guid) async => Booking(await api
      .object('POST', 'bookings/${_id(guid)}/cancel', authenticated: true));

  /// Server-side availability. Pass [visitDate] (`YYYY-MM-DD`) for one day, otherwise
  /// [from]/[to] bound a range (default: next 60 days).
  Future<List<Availability>> availability(String destinationGuid,
      {String? visitDate, String? from, String? to}) async {
    final page = await api.collection(
        _path('destinations/${_id(destinationGuid)}/availability', {
          if (visitDate != null) 'visit_date': visitDate,
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        }),
        Availability.new,
        authenticated: true);
    return page.items;
  }

  Future<MonthlyAvailability> monthlyAvailability(
          String destinationGuid, String month, int quantity) async =>
      MonthlyAvailability(await api.object(
          'GET',
          _path('destinations/${_id(destinationGuid)}/availability', {
            'month': month,
            'quantity': '$quantity',
          }),
          authenticated: true));

  // ── Booking reconciliation ─────────────────────────────────
  Future<BookingIntentState> bookingIntent(String key) async =>
      BookingIntentState(await api.object('GET', 'booking-intents/${_id(key)}',
          authenticated: true));

  /// Safe exit for an intent that cannot be reconciled: the server refuses any later
  /// create with this key, so the original request can never produce a surprise booking.
  Future<BookingIntentState> abandonBookingIntent(String key) async =>
      BookingIntentState(await api.object(
          'POST', 'booking-intents/${_id(key)}/abandon',
          authenticated: true));

  // ── Documents ──────────────────────────────────────────────
  Future<ProfileStatistics> profileStatistics() async => ProfileStatistics(
      await api.object('GET', 'profile/statistics', authenticated: true));

  Future<ApiPage<Review>> reviews({Map<String, String>? query}) =>
      api.collection(_path('reviews', query), Review.new, authenticated: true);

  Future<ApiPage<Review>> destinationReviews(String guid,
          {Map<String, String>? query}) =>
      api.collection(
          _path('destinations/${_id(guid)}/reviews', query), Review.new);

  Future<Review> createReview(
          String bookingGuid, int rating, String comment) async =>
      Review(await api.object('POST', 'bookings/${_id(bookingGuid)}/review',
          authenticated: true, body: {'rating': rating, 'comment': comment}));

  Future<BookingTickets> bookingTickets(String bookingGuid) async =>
      BookingTickets(await api.object(
          'GET', 'bookings/${_id(bookingGuid)}/tickets',
          authenticated: true));

  Future<BinaryResponse> ticketQr(String bookingGuid, String ticketGuid) =>
      api.session.requestBytes(
          'bookings/${_id(bookingGuid)}/tickets/${_id(ticketGuid)}/qr');

  Future<Json> ticketScanScope() =>
      api.object('GET', 'admin/ticket-check-ins/scope', authenticated: true);

  Future<Json> previewTicket(String payload) =>
      api.object('POST', 'admin/ticket-check-ins/preview',
          authenticated: true, body: {'qr_payload': payload});

  Future<Json> confirmTicket(String payload, String key) =>
      api.object('POST', 'admin/ticket-check-ins/confirm',
          authenticated: true,
          body: {'qr_payload': payload},
          headers: {'Idempotency-Key': key});

  Future<List<String>> destinationAdmins(String guid) async =>
      ((await api.object('GET', 'admin/destinations/${_id(guid)}/admins',
              authenticated: true))['user_guids'] as List)
          .cast<String>();

  Future<void> assignDestinationAdmins(
      String guid, List<String> userGuids) async {
    await api.object('PUT', 'admin/destinations/${_id(guid)}/admins',
        authenticated: true, body: {'user_guids': userGuids});
  }

  Future<BookingDocuments> bookingDocuments(String guid) async =>
      BookingDocuments(await api.object(
          'GET', 'bookings/${_id(guid)}/documents',
          authenticated: true));

  /// [type] is `invoice`, `ticket` or `receipt`; returns the PDF issued by the backend.
  Future<BinaryResponse> downloadDocument(String guid, String type) =>
      api.session.requestBytes('bookings/${_id(guid)}/documents/$type');

  // ── Admin: bookings ────────────────────────────────────────
  /// [query] supports `status`, `search`, `per_page` and `page`.
  Future<ApiPage<Booking>> adminBookings({Map<String, String>? query}) =>
      api.collection(_path('admin/bookings', query), Booking.new,
          authenticated: true);
  Future<Booking> adminBooking(String guid) async => Booking(await api
      .object('GET', 'admin/bookings/${_id(guid)}', authenticated: true));
  Future<OperationalReport> operationalReport(String section,
          {Map<String, String>? query}) async =>
      OperationalReport(await api.object(
          'GET', _path('admin/dashboard/${_id(section)}', query),
          authenticated: true));

  Future<ApiPage<OperationalRow>> operationalRows(String section,
          {Map<String, String>? query}) =>
      api.collection(
          _path(
              section == 'approval-queue'
                  ? 'admin/approval-queue'
                  : 'admin/dashboard/${_id(section)}',
              query),
          OperationalRow.new,
          authenticated: true);

  Future<ApiPage<OperationalRow>> approvalQueue({Map<String, String>? query}) =>
      operationalRows('approval-queue', query: query);

  Future<ApprovalClaim> mutateApprovalClaim(
      String guid, String action, String key,
      {Json body = const {}}) async {
    if (!const ['claim', 'release', 'reassign'].contains(action)) {
      throw ArgumentError.value(action, 'action');
    }
    final result = ApprovalClaim(await api.object('POST',
        '${action == 'reassign' ? 'superadmin' : 'admin'}/bookings/${_id(guid)}/$action',
        authenticated: true, body: body, headers: {'Idempotency-Key': key}));
    if (result.raw['booking_guid'] != guid) {
      throw const ApiException(
          'Respons claim tidak cocok.', null, 'invalid_response');
    }
    return result;
  }

  Future<Booking> decideBooking(String guid,
          {required bool approve, String? reason}) async =>
      Booking(await api.object('POST',
          'admin/bookings/${_id(guid)}/${approve ? 'approve' : 'reject'}',
          authenticated: true,
          body: reason == null || reason.trim().isEmpty
              ? null
              : {'reason': reason.trim()}));

  // ── Admin: destinations ────────────────────────────────────
  /// [query] supports `status` (active|inactive|all), `search`, `category`, `per_page`, `page`.
  Future<ApiPage<Destination>> adminDestinations(
          {Map<String, String>? query}) =>
      api.collection(_path('admin/destinations', query), Destination.new,
          authenticated: true);
  Future<Destination> adminDestination(String guid) async =>
      Destination(await api.object('GET', 'admin/destinations/${_id(guid)}',
          authenticated: true));

  Future<String?> reverseGeocode(double latitude, double longitude) async {
    final data = await api.object(
        'GET',
        _path('admin/geocoding/reverse', {
          'latitude': latitude.toStringAsFixed(7),
          'longitude': longitude.toStringAsFixed(7),
        }),
        authenticated: true);
    return data['formatted_address'] as String?;
  }

  Future<Destination> saveDestinationGallery(
      {String? guid,
      required Json fields,
      required int galleryVersion,
      required List<Json> manifest,
      required List<UploadFile> files,
      required String idempotencyKey}) async {
    return Destination(await api.session
        .requestMultipart(
            'POST', guid == null ? 'destinations' : 'destinations/${_id(guid)}',
            headers: {'Idempotency-Key': idempotencyKey},
            fields: {
              ..._formFields(fields),
              if (guid != null) '_method': 'PATCH',
              if (guid != null) 'gallery_version': '$galleryVersion',
              if (guid != null) 'gallery_manifest': jsonEncode(manifest)
            },
            files: files)
        .then(_data));
  }

  /// Creates a destination; with [image] the request is multipart (field `image`).
  Future<Destination> createDestination(Json fields,
      {UploadFile? image}) async {
    if (image == null) {
      return Destination(await api.object('POST', 'destinations',
          authenticated: true, body: fields));
    }
    return Destination(await api.session.requestMultipart(
        'POST', 'destinations',
        fields: _formFields(fields), files: [image]).then(_data));
  }

  /// Updates a destination; with [image] the request is multipart via `_method: PATCH`.
  Future<Destination> updateDestination(String guid, Json fields,
      {UploadFile? image}) async {
    if (image == null) {
      return Destination(await api.object('PATCH', 'destinations/${_id(guid)}',
          authenticated: true, body: fields));
    }
    return Destination(await api.session.requestMultipart(
        'POST', 'destinations/${_id(guid)}',
        fields: {..._formFields(fields), '_method': 'PATCH'},
        files: [image]).then(_data));
  }

  /// Replaces only the picture (JPEG, PNG or WebP, up to 5 MB).
  Future<Destination> uploadDestinationImage(
          String guid, UploadFile image) async =>
      Destination(await api.session.requestMultipart(
          'POST', 'destinations/${_id(guid)}/image',
          files: [image]).then(_data));

  Future<void> deactivateDestination(String guid) async {
    await api.object('DELETE', 'destinations/${_id(guid)}',
        authenticated: true);
  }

  Future<Destination> reactivateDestination(String guid) =>
      updateDestination(guid, {'is_active': true});

  // ── Admin: categories (role 2) ─────────────────────────────
  /// [query] supports `status` (active|inactive|all), `per_page`, `page`.
  Future<ApiPage<Category>> adminCategories({Map<String, String>? query}) =>
      api.collection(_path('admin/categories', query), Category.new,
          authenticated: true);
  Future<Category> createCategory(Json fields) async => Category(await api
      .object('POST', 'categories', authenticated: true, body: fields));
  Future<Category> updateCategory(String guid, Json fields) async =>
      Category(await api.object('PATCH', 'categories/${_id(guid)}',
          authenticated: true, body: fields));
  Future<void> deactivateCategory(String guid) async {
    await api.object('DELETE', 'categories/${_id(guid)}', authenticated: true);
  }

  Future<Category> reactivateCategory(String guid) =>
      updateCategory(guid, {'is_active': true});

  // ── Admin: quotas ──────────────────────────────────────────
  Future<ApiPage<Json>> quotas(String guid, {int page = 1}) => api.collection(
      'destinations/${_id(guid)}/quotas?page=$page', (json) => json,
      authenticated: true);
  Future<ApiPage<QuotaEntry>> quotaEntries(String guid,
          {int page = 1, int perPage = 100}) =>
      api.collection(
          'destinations/${_id(guid)}/quotas?page=$page&per_page=$perPage',
          QuotaEntry.new,
          authenticated: true);

  /// Fields: `visit_date`, `capacity`, `booking_opens_at`, `booking_closes_at`
  /// (timestamps with an explicit offset, e.g. UTC `...Z`).
  Future<QuotaEntry> saveQuota(String guid, Json fields) async =>
      QuotaEntry(await api.object('PUT', 'destinations/${_id(guid)}/quotas',
          authenticated: true, body: fields));
  Future<Json> putQuota(String guid, Json fields) =>
      api.object('PUT', 'destinations/${_id(guid)}/quotas',
          authenticated: true, body: fields);

  // ── Admin: accounts (role 2) ───────────────────────────────
  /// [query] supports `role`, `status`, `search`, `per_page`, `page`.
  Future<ApiPage<AdminAccount>> adminAccounts({Map<String, String>? query}) =>
      api.collection(_path('admin/accounts', query), AdminAccount.new,
          authenticated: true);
  Future<AdminAccount> createAdminAccount(Json fields) async =>
      AdminAccount(await api.object('POST', 'admin/accounts',
          authenticated: true, body: fields));
  Future<AdminAccount> updateAdminAccount(String guid, Json fields) async =>
      AdminAccount(await api.object('PATCH', 'admin/accounts/${_id(guid)}',
          authenticated: true, body: fields));

  Map<String, String> _formFields(Json fields) => {
        for (final entry in fields.entries)
          if (entry.value != null)
            entry.key: entry.value is bool
                ? (entry.value as bool ? '1' : '0')
                : '${entry.value}',
      };

  Json _data(Json envelope) {
    final data = envelope['data'];
    if (data is! Json) throw const ApiException('Respons layanan tidak valid.');
    return data;
  }
}
