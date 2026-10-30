import 'dart:io';

import 'package:flutter/foundation.dart';

import '../services/auth_session.dart';
import 'booking_errors.dart';
import 'business_repository.dart';

/// App-wide signal that the account's bookings changed (created or cancelled), so counters
/// on the home/profile screens and the history list can reload.
class BookingEvents {
  static final ValueNotifier<int> changed = ValueNotifier(0);
  static void notify() => changed.value++;
}

// ── Labels ──────────────────────────────────────────────────

/// Indonesian label for a server booking status. Unknown statuses are shown as received.
String bookingStatusLabel(String status) => switch (status) {
      'pending_approval' => 'Menunggu persetujuan',
      'awaiting_payment' => 'Menunggu pembayaran',
      'payment_verification' => 'Verifikasi pembayaran',
      'payment_review' => 'Peninjauan pembayaran',
      'confirmed' => 'Disetujui',
      'rejected' => 'Ditolak',
      'expired' => 'Kedaluwarsa',
      'cancelled' => 'Dibatalkan',
      _ => status,
    };

/// Short explanation for statuses that are easy to misread. Never claims a payment.
String? bookingStatusNote(String status) => switch (status) {
      'awaiting_payment' =>
        'Pendaftaran disetujui dan menunggu pembayaran. Status ini belum berarti pembayaran diterima.',
      'payment_verification' ||
      'payment_review' =>
        'Pembayaran sedang diproses. Status ini belum berarti pembayaran diterima.',
      'pending_approval' => 'Menunggu persetujuan pengelola.',
      _ => null,
    };

/// Indonesian text for an availability status.
String availabilityStatusLabel(String status) => switch (status) {
      'open' => 'Tersedia',
      'full' => 'Kuota penuh',
      'closed' => 'Pendaftaran ditutup',
      'not_open_yet' => 'Pendaftaran belum dibuka',
      'too_close' => 'Terlalu dekat dengan tanggal kunjungan',
      'unavailable' => 'Tidak tersedia',
      _ => status,
    };

String formatVisitDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Picks the availability row for [visitDate] (the server returns one row per requested day).
/// An empty or mismatched answer means no quota is published for that day.
Availability? availabilityFor(List<Availability> rows, String visitDate) {
  for (final row in rows) {
    if (row.visitDate == visitDate) return row;
  }
  return null;
}

/// Submit is allowed only for a day the server reports as open with enough remaining
/// capacity. Purely a UI gate: the POST is still authoritative.
bool canBookAvailability(Availability? availability, int quantity) =>
    availability != null &&
    availability.isOpen &&
    quantity >= 1 &&
    quantity <= availability.remaining;

// ── History ─────────────────────────────────────────────────

/// Loads every page of the owner's bookings, de-duplicated by `guid` (a booking can shift
/// between pages while paging). [status] is the optional server-side filter.
Future<List<Booking>> loadAllBookings(BusinessRepository repository,
    {String? status, int perPage = 50, int maxPages = 200}) async {
  final session = repository.api.session;
  final generation = session.sessionGeneration;
  final seen = <String>{};
  final items = <Booking>[];
  var page = 1;
  while (true) {
    final result = await repository.bookings(query: {
      'page': '$page',
      'per_page': '$perPage',
      if (status != null && status.isNotEmpty) 'status': status,
    });
    if (generation != session.sessionGeneration) {
      throw const ApiException('Sesi telah berakhir.', 401);
    }
    for (final booking in result.items) {
      if (seen.add(booking.guid)) items.add(booking);
    }
    final lastPage = result.meta?['last_page'];
    if (lastPage is! int || page >= lastPage || page >= maxPages) break;
    page++;
  }
  return items;
}

/// Total number of the owner's bookings from the pagination meta (one cheap request).
Future<int?> loadBookingTotal(BusinessRepository repository) async {
  final session = repository.api.session;
  final generation = session.sessionGeneration;
  final page = await repository.bookings(query: {'per_page': '1'});
  if (generation != session.sessionGeneration) {
    throw const ApiException('Sesi telah berakhir.', 401);
  }
  final total = page.meta?['total'];
  return total is int ? total : null;
}

/// The owner's booking list. A response is applied only when it belongs to the newest
/// request AND the session it was started in, so a slow older request or a response that
/// arrives after logout/account switch never overwrites newer or foreign data.
class UserBookingsState extends ChangeNotifier {
  final BusinessRepository repository;
  List<Booking> items = const [];
  Object? error;
  bool loading = false;
  String? status;
  int _request = 0;
  bool _disposed = false;

  UserBookingsState([BusinessRepository? repository])
      : repository = repository ?? BusinessRepository() {
    this.repository.api.session.sessionChanges.addListener(reset);
  }

  Future<void> load({String? status}) async {
    final session = repository.api.session;
    final request = ++_request;
    final generation = session.sessionGeneration;
    this.status = status;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await loadAllBookings(repository, status: status);
      if (_current(request, generation)) items = result;
    } catch (e) {
      if (_current(request, generation)) error = e;
    } finally {
      if (_current(request, generation)) {
        loading = false;
        _notify();
      }
    }
  }

  /// Replaces one booking with a fresher server copy (detail refresh, cancel result).
  void replace(Booking booking) {
    final index = items.indexWhere((b) => b.guid == booking.guid);
    if (index < 0) return;
    items = [...items]..[index] = booking;
    _notify();
  }

  /// Drops everything: used on logout and account switch.
  void reset() {
    _request++;
    items = const [];
    error = null;
    loading = false;
    _notify();
  }

  bool _current(int request, int generation) =>
      !_disposed &&
      request == _request &&
      generation == repository.api.session.sessionGeneration;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    repository.api.session.sessionChanges.removeListener(reset);
    super.dispose();
  }
}

// ── Detail, cancel and documents ────────────────────────────

/// A downloaded PDF written to disk.
class SavedDocument {
  final String path;
  final int size;
  const SavedDocument(this.path, this.size);
}

/// Fetches an issued document, verifies it is a PDF (`%PDF` header) and writes it to
/// [directory] (default: the app's temp directory).
///
/// Limitation: no viewer/share/open package is available, so the file is only saved; the
/// caller shows the path. The temp directory may be cleared by the OS.
Future<SavedDocument> saveBookingDocument(
    BusinessRepository repository, String bookingGuid, String type,
    {String? bookingNumber, Directory? directory}) async {
  if (type != 'invoice' && type != 'ticket') {
    throw const ApiException('Jenis dokumen tidak dikenal.');
  }
  final response = await repository.downloadDocument(bookingGuid, type);
  final bytes = response.bytes;
  const magic = [0x25, 0x50, 0x44, 0x46]; // %PDF
  final isPdf = bytes.length > 4 &&
      List.generate(4, (i) => bytes[i] == magic[i]).every((ok) => ok);
  if (!isPdf) {
    throw const ApiException('Dokumen yang diterima bukan PDF yang valid.');
  }
  final label = (bookingNumber == null || bookingNumber.isEmpty
          ? bookingGuid
          : bookingNumber)
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final dir = directory ?? Directory.systemTemp;
  final file = File('${dir.path}${Platform.pathSeparator}$type-$label.pdf');
  await file.writeAsBytes(bytes, flush: true);
  return SavedDocument(file.path, bytes.length);
}

/// State for one booking's detail: refresh, cancel (no optimistic update) and documents.
class BookingDetailController extends ChangeNotifier {
  final BusinessRepository repository;
  Booking booking;
  bool refreshing = false;
  bool cancelling = false;
  bool checkingIn = false;
  bool reviewing = false;
  String? message;
  BookingDocuments? documents;
  bool loadingDocuments = false;
  String? documentsError;
  String? downloading;
  final int _generation;
  int _refreshRequest = 0;
  int _documentsRequest = 0;
  bool _disposed = false;

  BookingDetailController(this.repository, this.booking)
      : _generation = repository.api.session.sessionGeneration;

  bool get _sessionValid =>
      !_disposed && repository.api.session.isCurrentGeneration(_generation);

  /// Takes a copy from the list when nothing is in flight. Silent (no notification), so it
  /// is safe to call while the owner widget is rebuilding.
  void adopt(Booking fresh) {
    if (fresh.guid != booking.guid ||
        cancelling ||
        refreshing ||
        checkingIn ||
        reviewing) return;
    booking = fresh;
  }

  /// Reads the current server copy of the booking.
  Future<void> refresh() async {
    final request = ++_refreshRequest;
    refreshing = true;
    _notify();
    try {
      final fresh = await repository.booking(booking.guid);
      if (_sessionValid && request == _refreshRequest) booking = fresh;
    } catch (e) {
      if (_sessionValid && request == _refreshRequest) {
        message = bookingErrorMessage(e);
      }
    } finally {
      if (_sessionValid && request == _refreshRequest) {
        refreshing = false;
        _notify();
      }
    }
  }

  /// Cancels once; the booking shown afterwards is the one the server returned. Returns true
  /// only when the server confirmed the cancellation. A conflict or unknown outcome shows
  /// a precise message and re-reads the booking; the call is never repeated automatically.
  Future<bool> cancel() async {
    if (cancelling || !booking.cancellable) return false;
    cancelling = true;
    message = null;
    _notify();
    var confirmed = false;
    try {
      final result = await repository.cancelBooking(booking.guid);
      if (!_sessionValid) return false;
      if (result.guid != booking.guid) {
        throw const ApiException(
            'Respons layanan tidak valid.', null, 'invalid_response');
      }
      booking = result;
      confirmed = true;
      BookingEvents.notify();
    } catch (e) {
      if (!_sessionValid) return false;
      message = bookingErrorMessage(e, mutation: true);
      cancelling = false;
      _notify();
      // Server state is authoritative after a conflict or an unknown outcome.
      if (e is ApiException && (e.status == 409 || e.outcomeUnknown)) {
        await refresh();
        if (_sessionValid && booking.status == 'cancelled') {
          BookingEvents.notify();
        }
      }
      return false;
    } finally {
      if (_sessionValid) {
        cancelling = false;
        _notify();
      }
    }
    return confirmed;
  }

  Future<bool> checkIn() async {
    if (!_sessionValid || checkingIn || !booking.canCheckIn) return false;
    checkingIn = true;
    message = null;
    _notify();
    try {
      final fresh = await repository.checkIn(booking.guid);
      if (!_sessionValid) return false;
      if (fresh.guid != booking.guid || fresh.checkedInAt == null) {
        throw const ApiException(
            'Respons layanan tidak valid.', null, 'invalid_response');
      }
      booking = fresh;
      BookingEvents.notify();
      return true;
    } catch (e) {
      if (!_sessionValid) return false;
      message = bookingErrorMessage(e, mutation: true);
      if (e is ApiException && (e.status == 409 || e.outcomeUnknown)) {
        await refresh();
        if (_sessionValid && booking.checkedInAt != null)
          BookingEvents.notify();
      }
      return false;
    } finally {
      if (_sessionValid) {
        checkingIn = false;
        _notify();
      }
    }
  }

  Future<bool> submitReview(int rating, String comment) async {
    if (!_sessionValid || reviewing || !booking.canReview) return false;
    reviewing = true;
    message = null;
    _notify();
    try {
      final review =
          await repository.createReview(booking.guid, rating, comment);
      if (!_sessionValid) return false;
      if (review.bookingGuid != booking.guid) {
        throw const ApiException(
            'Respons layanan tidak valid.', null, 'invalid_response');
      }
      booking = Booking(
          {...booking.json, 'can_review': false, 'review': review.json});
      BookingEvents.notify();
      return true;
    } catch (e) {
      if (!_sessionValid) return false;
      message = bookingErrorMessage(e, mutation: true);
      if (e is ApiException && (e.status == 409 || e.outcomeUnknown)) {
        await refresh();
        if (_sessionValid && booking.review != null) BookingEvents.notify();
      }
      return false;
    } finally {
      if (_sessionValid) {
        reviewing = false;
        _notify();
      }
    }
  }

  Future<void> loadDocuments() async {
    final request = ++_documentsRequest;
    loadingDocuments = true;
    documentsError = null;
    _notify();
    try {
      final result = await repository.bookingDocuments(booking.guid);
      if (_sessionValid && request == _documentsRequest) documents = result;
    } catch (e) {
      if (_sessionValid && request == _documentsRequest) {
        documentsError = bookingErrorMessage(e);
      }
    } finally {
      if (_sessionValid && request == _documentsRequest) {
        loadingDocuments = false;
        _notify();
      }
    }
  }

  /// Downloads [type] (`invoice` or `ticket`). Returns the saved file, or null on failure
  /// (then [message] explains why). One download at a time.
  Future<SavedDocument?> download(String type, {Directory? directory}) async {
    if (downloading != null) return null;
    downloading = type;
    message = null;
    _notify();
    try {
      final saved = await saveBookingDocument(repository, booking.guid, type,
          bookingNumber: booking.bookingNumber, directory: directory);
      return _sessionValid ? saved : null;
    } catch (e) {
      if (_sessionValid) {
        message = e is ApiException && e.status == 404
            ? 'Dokumen belum siap diunduh.'
            : bookingErrorMessage(e);
      }
      return null;
    } finally {
      if (_sessionValid) {
        downloading = null;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
