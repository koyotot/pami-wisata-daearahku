// ============================================================
// lib/data/admin_state.dart
// State & logic for the Laravel-backed admin screens (no UI here).
// - PagedListController: all pages, dedupe by GUID, stale-response safe
// - AdminBookingDecider: approve/reject with in-flight guard & reconciliation
// - Role gating, error mapping, image/quota/slug helpers
// ============================================================
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/auth_session.dart';
import 'business_repository.dart';

// -- Role gating (UX only; the backend is authoritative) ----------------

/// Categories and admin accounts need the superadmin role.
bool canManageCategories(int? role) => role == 2;
bool canManageAdmins(int? role) => role == 2;

/// Bookings, destinations and quotas need role >= 1.
bool canManageQuota(int? role) => role == 1 || role == 2;
bool canAccessAdmin(int? role) => role == 1 || role == 2;

// -- Labels -------------------------------------------------------------

const List<String> kBookingStatuses = [
  'pending_approval',
  'awaiting_payment',
  'payment_verification',
  'payment_review',
  'confirmed',
  'rejected',
  'expired',
  'cancelled',
];

String bookingStatusLabel(String status) => switch (status) {
      'pending_approval' => 'Menunggu',
      'awaiting_payment' => 'Menunggu pembayaran',
      'payment_verification' => 'Verifikasi pembayaran',
      'payment_review' => 'Peninjauan pembayaran',
      'confirmed' => 'Disetujui',
      'rejected' => 'Ditolak',
      'expired' => 'Kedaluwarsa',
      'cancelled' => 'Dibatalkan',
      _ => status,
    };

String adminRoleLabel(int role) => switch (role) {
      2 => 'Superadmin',
      1 => 'Admin',
      0 => 'Pengguna',
      _ => 'Role $role',
    };

/// Valid IANA zones accepted for a destination (WIB, WITA, WIT).
const List<String> kAdminTimezones = [
  'Asia/Jakarta',
  'Asia/Makassar',
  'Asia/Jayapura',
];

String timezoneLabel(String zone) => switch (zone) {
      'Asia/Jakarta' => 'Asia/Jakarta (WIB)',
      'Asia/Makassar' => 'Asia/Makassar (WITA)',
      'Asia/Jayapura' => 'Asia/Jayapura (WIT)',
      _ => zone,
    };

/// `visit_date` can arrive as a date or as a longer timestamp; show the day only.
String visitDay(String value) =>
    value.length >= 10 && value.contains('T') ? value.substring(0, 10) : value;

String formatMoney(int amount, String currency) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  final sign = amount < 0 ? '-' : '';
  return amount == 0 ? 'Gratis' : '$currency $sign$buffer';
}

String _two(int v) => v.toString().padLeft(2, '0');

/// `dd/MM/yyyy HH:mm` in the device time zone.
String formatDateTime(DateTime value) {
  final d = value.toLocal();
  return '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
}

/// `dd/MM/yyyy` without any time-zone conversion.
String formatDate(DateTime value) =>
    '${_two(value.day)}/${_two(value.month)}/${value.year}';

/// `yyyy-MM-dd` from the calendar fields of [value].
String isoDay(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${_two(value.month)}-${_two(value.day)}';

// -- Error mapping ------------------------------------------------------

/// Precise Indonesian message for an API failure, keyed on `ApiException.code`.
String adminErrorMessage(Object error) {
  if (error is! ApiException) {
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
  switch (error.code) {
    case 'booking_not_pending':
      return 'Pendaftaran ini sudah diproses sebelumnya.';
    case 'approval_deadline_passed':
      return 'Batas waktu persetujuan sudah lewat. Pendaftaran tidak dapat '
          'disetujui atau ditolak lagi.';
    case 'visit_date_too_close':
      return 'Tanggal kunjungan terlalu dekat sehingga pendaftaran tidak dapat '
          'disetujui.';
    case 'quota_unavailable':
      return 'Kuota tidak tersedia untuk tanggal ini, atau destinasi/kategori '
          'sedang nonaktif.';
    case 'insufficient_capacity':
      final remaining = error.context?['remaining'];
      return remaining == null
          ? 'Sisa kapasitas tidak mencukupi.'
          : 'Sisa kapasitas tidak mencukupi (tersisa $remaining).';
    case 'booking_window_closed':
      return 'Di luar jendela buka/tutup booking.';
    case 'category_in_use':
      return 'Kategori tidak dapat dinonaktifkan karena masih dipakai oleh '
          'destinasi aktif. Nonaktifkan atau pindahkan destinasi tersebut '
          'terlebih dahulu.';
    case 'category_inactive':
      return 'Destinasi tidak dapat diaktifkan karena kategorinya nonaktif. '
          'Aktifkan kembali kategorinya lebih dulu (Kelola Kategori).';
    case 'invalid_price':
      return 'Harga tiket tidak valid.';
    case 'timeout':
    case 'network':
      return error.message;
  }
  switch (error.status) {
    case 401:
      return 'Sesi berakhir. Silakan masuk kembali.';
    case 403:
      return 'Anda tidak memiliki hak akses untuk tindakan ini.';
    case 404:
      return 'Data tidak ditemukan atau sudah tidak tersedia.';
    case 422:
      return _friendlyValidation(error.message);
  }
  return error.message;
}

String _friendlyValidation(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('last active superadmin')) {
    return 'Superadmin aktif terakhir tidak dapat dinonaktifkan atau '
        'diturunkan perannya.';
  }
  if (lower.contains('cannot change your own')) {
    return 'Anda tidak dapat mengubah peran atau status akun sendiri.';
  }
  return message;
}

// -- Paged list ---------------------------------------------------------

typedef PageFetcher<T> = Future<ApiPage<T>> Function(
    int page, Map<String, String> filters);

/// Loads every page of a collection, de-duplicating by key (rows shift while
/// paging a newest-first list). A newer [load], a session change or [dispose]
/// invalidates any request still in flight, so late replies are dropped.
class PagedListController<T> extends ChangeNotifier {
  PagedListController({
    required this.fetchPage,
    required this.keyOf,
    AuthSession? session,
    this.maxPages = 200,
  }) : session = session ?? AuthSession.instance {
    this.session.sessionChanges.addListener(_onSessionChanged);
  }

  final PageFetcher<T> fetchPage;
  final String Function(T item) keyOf;
  final AuthSession session;
  final int maxPages;

  List<T> _items = const [];
  Map<String, String> _filters = {};
  Object? error;
  bool loading = false;
  bool hasLoaded = false;
  int? total;
  int _request = 0;
  bool _disposed = false;

  List<T> get items => _items;
  Map<String, String> get filters => Map.unmodifiable(_filters);

  bool _current(int request, int generation) =>
      !_disposed &&
      request == _request &&
      session.isCurrentGeneration(generation);

  bool _hasNext(ApiPage<T> page, int number) {
    final links = page.links;
    if (links != null && links.containsKey('next')) return links['next'] != null;
    final last = page.meta?['last_page'];
    return last is num && number < last.toInt();
  }

  /// Fetches all pages for [filters] (kept from the previous call when omitted).
  Future<void> load({Map<String, String>? filters}) async {
    if (_disposed) return;
    if (filters != null && !mapEquals(filters, _filters)) {
      // Rows of another filter must not stay on screen while the new one loads.
      _filters = Map.of(filters);
      _items = const [];
      total = null;
      hasLoaded = false;
    }
    final applied = Map<String, String>.of(_filters);
    final request = ++_request;
    final generation = session.sessionGeneration;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final byKey = <String, T>{};
      int? reportedTotal;
      var number = 1;
      while (true) {
        final page = await fetchPage(number, applied);
        if (!_current(request, generation)) return;
        for (final item in page.items) {
          byKey[keyOf(item)] = item;
        }
        final metaTotal = page.meta?['total'];
        if (metaTotal is num) reportedTotal = metaTotal.toInt();
        if (page.items.isEmpty || !_hasNext(page, number) || number >= maxPages) {
          break;
        }
        number++;
      }
      _items = byKey.values.toList();
      total = reportedTotal;
      hasLoaded = true;
    } catch (e) {
      if (!_current(request, generation)) return;
      error = e;
    }
    loading = false;
    notifyListeners();
  }

  /// Swaps one row for the server's latest version of it (no local edits).
  void replaceItem(T item) {
    final key = keyOf(item);
    final index = _items.indexWhere((e) => keyOf(e) == key);
    if (index < 0 || _disposed) return;
    _items = [..._items]..[index] = item;
    notifyListeners();
  }

  void _onSessionChanged() {
    if (_disposed) return;
    _request++;
    _items = const [];
    error = null;
    total = null;
    loading = false;
    hasLoaded = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    session.sessionChanges.removeListener(_onSessionChanged);
    super.dispose();
  }
}

// -- In-flight guard ----------------------------------------------------

/// Lets only one action per key run at a time; a second call returns null
/// without invoking [action].
class InFlightGuard extends ChangeNotifier {
  final Set<String> _keys = {};
  bool _disposed = false;
  bool isBusy(String key) => _keys.contains(key);
  bool get any => _keys.isNotEmpty;

  Future<T?> run<T>(String key, Future<T> Function() action) async {
    if (!_keys.add(key)) return null;
    if (!_disposed) notifyListeners();
    try {
      return await action();
    } finally {
      _keys.remove(key);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

// -- Booking decisions --------------------------------------------------

enum DecisionKind {
  /// The server answered the decision with the new booking.
  applied,

  /// 409 booking_not_pending (or deadline passed): detail was re-read.
  alreadyProcessed,

  /// The outcome was unknown (timeout...), the detail was re-read afterwards.
  reconciled,

  /// The outcome is unknown and the detail could not be re-read either.
  unconfirmed,

  /// A definite failure; nothing changed.
  failed,

  /// A decision for this booking is already running; no request was sent.
  inFlight,

  /// The session changed while waiting; the result must be ignored.
  stale,
}

class BookingDecisionResult {
  final DecisionKind kind;
  final Booking? booking;
  final String message;
  const BookingDecisionResult(this.kind, this.message, [this.booking]);

  /// Whether the UI should react (snack bar, list update).
  bool get actionable =>
      kind != DecisionKind.inFlight && kind != DecisionKind.stale;
}

/// Approve / reject with one request per booking at a time. Never retries a
/// decision automatically: an unknown outcome is reconciled by reading the
/// booking again and only the server's status is ever reported.
class AdminBookingDecider extends InFlightGuard {
  AdminBookingDecider(this.repository, {AuthSession? session})
      : session = session ?? AuthSession.instance;
  final BusinessRepository repository;
  final AuthSession session;

  Future<BookingDecisionResult> decide(String guid,
      {required bool approve, String? reason}) async {
    final generation = session.sessionGeneration;
    final result = await run<BookingDecisionResult>(guid, () async {
      try {
        final booking =
            await repository.decideBooking(guid, approve: approve, reason: reason);
        return BookingDecisionResult(
            DecisionKind.applied,
            _appliedMessage(booking.status),
            booking);
      } on ApiException catch (e) {
        return _reconcile(guid, e);
      } catch (_) {
        // A malformed reply after the request was sent: the outcome is unknown.
        return _reconcile(
            guid,
            const ApiException(
                'Respons layanan tidak valid.', null, 'invalid_response'));
      }
    });
    if (result == null) {
      return const BookingDecisionResult(
          DecisionKind.inFlight, 'Keputusan untuk pendaftaran ini sedang diproses.');
    }
    if (!session.isCurrentGeneration(generation)) {
      return const BookingDecisionResult(DecisionKind.stale, '');
    }
    return result;
  }

  String _appliedMessage(String status) => switch (status) {
        'confirmed' => 'Pendaftaran disetujui. Status: Disetujui.',
        'awaiting_payment' =>
          'Pendaftaran disetujui. Status: Menunggu pembayaran.',
        'rejected' => 'Pendaftaran ditolak. Status: Ditolak.',
        _ => 'Status dari server: ${bookingStatusLabel(status)}.',
      };

  Future<BookingDecisionResult> _reconcile(String guid, ApiException e) async {
    final unknown = e.outcomeUnknown;
    final reread = unknown ||
        e.code == 'booking_not_pending' ||
        e.code == 'approval_deadline_passed';
    if (!reread) {
      return BookingDecisionResult(DecisionKind.failed, adminErrorMessage(e));
    }
    Booking? current;
    try {
      current = await repository.adminBooking(guid);
    } catch (_) {
      current = null;
    }
    if (unknown) {
      if (current == null) {
        return const BookingDecisionResult(
            DecisionKind.unconfirmed,
            'Hasil keputusan belum dapat dipastikan dan status terbaru gagal '
            'dimuat. Periksa daftar sebelum mencoba lagi.');
      }
      final status = current.status;
      return BookingDecisionResult(
          DecisionKind.reconciled,
          status == 'pending_approval'
              ? 'Keputusan belum terkonfirmasi: status di server masih '
                  'Menunggu. Periksa kembali sebelum mengulang.'
              : 'Status terkini dari server: ${bookingStatusLabel(status)}.',
          current);
    }
    final status = current?.status ?? e.context?['status'] as String?;
    final base = adminErrorMessage(e);
    return BookingDecisionResult(
        DecisionKind.alreadyProcessed,
        status == null
            ? base
            : '$base Status terkini: ${bookingStatusLabel(status)}.',
        current);
  }
}

// -- Helpers for forms --------------------------------------------------

/// URL-safe slug suggestion (`alpha_dash`) from a display name.
String slugify(String input) {
  final lower = input.toLowerCase();
  final dashed = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return dashed.replaceAll(RegExp(r'^-+|-+$'), '');
}

const int kMaxImageBytes = 5 * 1024 * 1024;

/// Client-side pre-check for a destination picture (JPEG/PNG/WebP, <= 5 MB).
/// The server stays authoritative and re-validates the real content.
String? validateDestinationImage(List<int> bytes) {
  if (bytes.isEmpty) return 'File gambar kosong.';
  if (bytes.length > kMaxImageBytes) {
    return 'Ukuran gambar maksimal 5 MB.';
  }
  final jpeg = bytes.length > 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
  final png = bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
  final webp = bytes.length > 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
  if (!jpeg && !png && !webp) {
    return 'Format gambar harus JPEG, PNG, atau WebP.';
  }
  return null;
}

/// Local validation for a quota entry; null when acceptable.
String? validateQuotaInput({
  required DateTime? visitDate,
  required int? capacity,
  required DateTime? opensAt,
  required DateTime? closesAt,
}) {
  if (visitDate == null) return 'Tanggal kunjungan wajib dipilih.';
  if (capacity == null || capacity < 0) {
    return 'Kapasitas harus berupa bilangan bulat 0 atau lebih.';
  }
  if (opensAt == null || closesAt == null) {
    return 'Waktu buka dan tutup booking wajib diisi.';
  }
  if (!closesAt.isAfter(opensAt)) {
    return 'Waktu tutup booking harus setelah waktu buka.';
  }
  return null;
}

/// Request body for `PUT destinations/{guid}/quotas`; timestamps are UTC with `Z`.
Json buildQuotaPayload({
  required DateTime visitDate,
  required int capacity,
  required DateTime opensAt,
  required DateTime closesAt,
}) =>
    {
      'visit_date': isoDay(visitDate),
      'capacity': capacity,
      'booking_opens_at': opensAt.toUtc().toIso8601String(),
      'booking_closes_at': closesAt.toUtc().toIso8601String(),
    };

/// Own account must not offer role/status changes (the server forbids it too).
bool canModifyAccount(AdminAccount account, String? ownGuid) =>
    ownGuid != null && account.guid != ownGuid;
