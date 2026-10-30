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
  String get description => json['description'] as String? ?? '';
  int get ticketPrice => (json['ticket_price'] as num?)?.toInt() ?? 0;
  String get currency => json['currency'] as String? ?? 'IDR';
  String get openingHours => json['opening_hours'] as String? ?? '';
  String get timezone => json['timezone'] as String? ?? 'Asia/Jakarta';
  bool get isActive => json['is_active'] as bool? ?? true;

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
  String get currency => json['currency'] as String? ?? 'IDR';
  String? get notes => json['notes'] as String?;
  String get status => json['status'] as String;

  /// Server-computed: true only while the owner may still cancel (pending approval).
  bool get cancellable => json['cancellable'] == true;
  DateTime? get createdAt => DateTime.tryParse(json['created_at'] as String? ?? '');
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
  DateTime? get opensAt => DateTime.tryParse(json['booking_opens_at'] as String? ?? '');
  DateTime? get closesAt => DateTime.tryParse(json['booking_closes_at'] as String? ?? '');
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
  DateTime? get opensAt => DateTime.tryParse(json['booking_opens_at'] as String? ?? '');
  DateTime? get closesAt => DateTime.tryParse(json['booking_closes_at'] as String? ?? '');
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
  Json? get ticket => json['ticket'] is Json ? json['ticket'] as Json : null;
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

  /// Image bytes for a destination's `image_url` (public, active destinations).
  Future<BinaryResponse> imageBytes(String imageUrl) =>
      api.session.publicBytes(imageUrl);

  /// Image bytes for any destination, including inactive ones (role >= 1).
  Future<BinaryResponse> adminImageBytes(String guid, String imageUrl) {
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
  Future<Booking> createBooking(Json fields, String idempotencyKey) async =>
      Booking(await api.object('POST', 'bookings',
          authenticated: true,
          body: fields,
          headers: {'Idempotency-Key': idempotencyKey}));

  /// Only a booking still awaiting approval can be cancelled (owner only).
  Future<Booking> cancelBooking(String guid) async => Booking(await api.object(
      'POST', 'bookings/${_id(guid)}/cancel',
      authenticated: true));

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

  // ── Booking reconciliation ─────────────────────────────────
  Future<BookingIntentState> bookingIntent(String key) async =>
      BookingIntentState(await api.object(
          'GET', 'booking-intents/${_id(key)}',
          authenticated: true));

  /// Safe exit for an intent that cannot be reconciled: the server refuses any later
  /// create with this key, so the original request can never produce a surprise booking.
  Future<BookingIntentState> abandonBookingIntent(String key) async =>
      BookingIntentState(await api.object(
          'POST', 'booking-intents/${_id(key)}/abandon',
          authenticated: true));

  // ── Documents ──────────────────────────────────────────────
  Future<BookingDocuments> bookingDocuments(String guid) async =>
      BookingDocuments(await api.object(
          'GET', 'bookings/${_id(guid)}/documents',
          authenticated: true));

  /// [type] is `invoice` or `ticket`; returns the PDF issued by the backend.
  Future<BinaryResponse> downloadDocument(String guid, String type) =>
      api.session.requestBytes('bookings/${_id(guid)}/documents/$type');

  // ── Admin: bookings ────────────────────────────────────────
  /// [query] supports `status`, `search`, `per_page` and `page`.
  Future<ApiPage<Booking>> adminBookings({Map<String, String>? query}) =>
      api.collection(_path('admin/bookings', query), Booking.new,
          authenticated: true);
  Future<Booking> adminBooking(String guid) async => Booking(await api.object(
      'GET', 'admin/bookings/${_id(guid)}',
      authenticated: true));
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

  /// Creates a destination; with [image] the request is multipart (field `image`).
  Future<Destination> createDestination(Json fields,
      {UploadFile? image}) async {
    if (image == null) {
      return Destination(await api.object('POST', 'destinations',
          authenticated: true, body: fields));
    }
    return Destination(await api.session.requestMultipart('POST', 'destinations',
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
  Future<QuotaEntry> saveQuota(String guid, Json fields) async => QuotaEntry(
      await api.object('PUT', 'destinations/${_id(guid)}/quotas',
          authenticated: true, body: fields));
  Future<Json> putQuota(String guid, Json fields) =>
      api.object('PUT', 'destinations/${_id(guid)}/quotas',
          authenticated: true, body: fields);

  // ── Admin: accounts (role 2) ───────────────────────────────
  /// [query] supports `role`, `status`, `search`, `per_page`, `page`.
  Future<ApiPage<AdminAccount>> adminAccounts({Map<String, String>? query}) =>
      api.collection(_path('admin/accounts', query), AdminAccount.new,
          authenticated: true);
  Future<AdminAccount> createAdminAccount(Json fields) async => AdminAccount(
      await api.object('POST', 'admin/accounts',
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
