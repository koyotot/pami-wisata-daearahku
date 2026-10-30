import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/booking_state.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'user_support.dart';

/// Repository whose list/detail/cancel answers are driven by the test.
class GatedRepository extends BusinessRepository {
  GatedRepository(AuthSession session) : super(ApiClient(session));
  final listRequests = <Map<String, String>>[];
  Future<ApiPage<Booking>> Function(Map<String, String> query)? onList;
  Future<Booking> Function(String guid)? onBooking;
  Future<Booking> Function(String guid)? onCancel;
  int cancelCalls = 0;
  int detailCalls = 0;

  @override
  Future<ApiPage<Booking>> bookings({Map<String, String>? query}) {
    listRequests.add(Map.of(query ?? {}));
    return onList!(query ?? {});
  }

  @override
  Future<Booking> booking(String guid) {
    detailCalls++;
    return onBooking!(guid);
  }

  @override
  Future<Booking> cancelBooking(String guid) {
    cancelCalls++;
    return onCancel!(guid);
  }
}

ApiPage<Booking> page(List<String> guids, {required int last, int? total}) =>
    ApiPage(
        guids.map((g) => Booking(bookingJson(guid: g))).toList(),
        {'current_page': 1, 'last_page': last, 'total': total ?? guids.length},
        null);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthSession session;
  late GatedRepository repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    session = AuthSession();
    repository = GatedRepository(session);
  });

  group('loadAllBookings', () {
    test('reads every page, de-duplicates by guid and keeps the first order',
        () async {
      repository.onList = (query) async => switch (query['page']) {
            '1' => page(['a', 'b'], last: 3),
            '2' => page(['b', 'c'], last: 3), // b shifted onto page 2
            _ => page(['c', 'd'], last: 3),
          };
      final items = await loadAllBookings(repository);
      expect(items.map((b) => b.guid), ['a', 'b', 'c', 'd']);
      expect(repository.listRequests.map((q) => q['page']), ['1', '2', '3']);
      expect(repository.listRequests.every((q) => q['per_page'] == '50'),
          isTrue);
      expect(repository.listRequests.any((q) => q.containsKey('status')),
          isFalse);
    });

    test('passes the optional server status filter on every page', () async {
      repository.onList = (query) async => page(['a'], last: 2);
      await loadAllBookings(repository, status: 'confirmed');
      expect(repository.listRequests.map((q) => q['status']),
          ['confirmed', 'confirmed']);
    });

    test('a missing pagination meta stops after the first page', () async {
      repository.onList =
          (query) async => ApiPage([Booking(bookingJson())], null, null);
      expect(await loadAllBookings(repository), hasLength(1));
      expect(repository.listRequests, hasLength(1));
    });

    test('a session change between pages aborts instead of returning old data',
        () async {
      repository.onList = (query) async {
        if (query['page'] == '1') {
          await session.clear();
          return page(['a'], last: 2);
        }
        return page(['b'], last: 2);
      };
      await expectLater(
          loadAllBookings(repository), throwsA(isA<ApiException>()));
      expect(repository.listRequests, hasLength(1));
    });

    test('total comes from the pagination meta', () async {
      repository.onList = (query) async {
        expect(query['per_page'], '1');
        return page(['a'], last: 5, total: 5);
      };
      expect(await loadBookingTotal(repository), 5);
    });
  });

  group('UserBookingsState', () {
    test('an older request finishing later never overwrites the newer one',
        () async {
      final first = Completer<ApiPage<Booking>>();
      final second = Completer<ApiPage<Booking>>();
      final gates = [first, second];
      repository.onList = (query) => gates.removeAt(0).future;
      final state = UserBookingsState(repository);
      addTearDown(state.dispose);

      final olderLoad = state.load();
      final newerLoad = state.load(status: 'confirmed');
      second.complete(page(['new'], last: 1));
      await newerLoad;
      expect(state.items.map((b) => b.guid), ['new']);
      expect(state.status, 'confirmed');

      first.complete(page(['old'], last: 1));
      await olderLoad;
      expect(state.items.map((b) => b.guid), ['new']);
      expect(state.loading, isFalse);
      expect(state.error, isNull);
    });

    test('an older failure after a newer success does not set an error', () async {
      final first = Completer<ApiPage<Booking>>();
      final second = Completer<ApiPage<Booking>>();
      final gates = [first, second];
      repository.onList = (query) => gates.removeAt(0).future;
      final state = UserBookingsState(repository);
      addTearDown(state.dispose);

      final older = state.load();
      final newer = state.load();
      second.complete(page(['new'], last: 1));
      await newer;
      first.completeError(const ApiException('boom', 500));
      await older;
      expect(state.error, isNull);
      expect(state.items.single.guid, 'new');
    });

    test('logout during a load: the late response is dropped and nothing leaks',
        () async {
      final gate = Completer<ApiPage<Booking>>();
      repository.onList = (query) => gate.future;
      final state = UserBookingsState(repository);
      addTearDown(state.dispose);
      final load = state.load();
      await session.clear(); // logout / account switch
      gate.complete(page(['previous-account'], last: 1));
      await load;
      expect(state.items, isEmpty);
      expect(state.loading, isFalse);
    });

    test('a session change empties data already shown', () async {
      repository.onList = (query) async => page(['a', 'b'], last: 1);
      final state = UserBookingsState(repository);
      addTearDown(state.dispose);
      await state.load();
      expect(state.items, hasLength(2));
      session.sessionChanges.value++;
      expect(state.items, isEmpty);
      expect(state.error, isNull);
    });

    test('replace swaps one booking for the fresher server copy', () async {
      repository.onList = (query) async => page(['a', 'b'], last: 1);
      final state = UserBookingsState(repository);
      addTearDown(state.dispose);
      await state.load();
      state.replace(Booking(bookingJson(guid: 'b', status: 'cancelled')));
      expect(state.items.map((b) => b.status),
          ['pending_approval', 'cancelled']);
    });
  });

  group('BookingDetailController', () {
    test('cancel: no optimistic update; shows the booking the server returned',
        () async {
      final gate = Completer<Booking>();
      repository.onCancel = (guid) => gate.future;
      final events = BookingEvents.changed.value;
      final controller =
          BookingDetailController(repository, Booking(bookingJson()));
      addTearDown(controller.dispose);

      final pending = controller.cancel();
      expect(controller.cancelling, isTrue);
      expect(controller.booking.status, 'pending_approval'); // not optimistic
      gate.complete(Booking(bookingJson(status: 'cancelled', cancellable: false)));
      expect(await pending, isTrue);
      expect(controller.booking.status, 'cancelled');
      expect(controller.booking.cancellable, isFalse);
      expect(controller.cancelling, isFalse);
      expect(BookingEvents.changed.value, events + 1);
    });

    test('double tap sends a single cancel request', () async {
      final gate = Completer<Booking>();
      repository.onCancel = (guid) => gate.future;
      final controller =
          BookingDetailController(repository, Booking(bookingJson()));
      addTearDown(controller.dispose);
      final first = controller.cancel();
      final second = await controller.cancel();
      expect(second, isFalse);
      gate.complete(Booking(bookingJson(status: 'cancelled', cancellable: false)));
      await first;
      expect(repository.cancelCalls, 1);
    });

    test('cancel is not offered or sent when the server says not cancellable',
        () async {
      final controller = BookingDetailController(
          repository, Booking(bookingJson(cancellable: false)));
      addTearDown(controller.dispose);
      expect(await controller.cancel(), isFalse);
      expect(repository.cancelCalls, 0);
    });

    test('409 booking_not_cancellable: precise message, then the detail is re-read',
        () async {
      repository.onCancel = (guid) async => throw const ApiException(
          'Booking cannot be cancelled.', 409, 'booking_not_cancellable');
      repository.onBooking = (guid) async =>
          Booking(bookingJson(status: 'confirmed', cancellable: false));
      final controller =
          BookingDetailController(repository, Booking(bookingJson()));
      addTearDown(controller.dispose);
      expect(await controller.cancel(), isFalse);
      expect(controller.message, contains('sudah diproses'));
      expect(repository.detailCalls, 1);
      expect(controller.booking.status, 'confirmed');
      expect(controller.booking.cancellable, isFalse);
      expect(controller.cancelling, isFalse);
    });

    test('409 booking_already_cancelled is reported as such', () async {
      repository.onCancel = (guid) async => throw const ApiException(
          'x', 409, 'booking_already_cancelled');
      repository.onBooking = (guid) async =>
          Booking(bookingJson(status: 'cancelled', cancellable: false));
      final controller =
          BookingDetailController(repository, Booking(bookingJson()));
      addTearDown(controller.dispose);
      await controller.cancel();
      expect(controller.message, contains('sudah dibatalkan'));
      expect(controller.booking.status, 'cancelled');
    });

    test('timeout is an unknown outcome: message says so and the server is re-read',
        () async {
      repository.onCancel =
          (guid) async => throw const ApiException('t', null, 'timeout');
      repository.onBooking = (guid) async => Booking(bookingJson());
      final controller =
          BookingDetailController(repository, Booking(bookingJson()));
      addTearDown(controller.dispose);
      expect(await controller.cancel(), isFalse);
      expect(controller.message, contains('Hasil belum diketahui'));
      expect(repository.cancelCalls, 1); // never retried automatically
      expect(repository.detailCalls, 1);
    });

    test('a cancel response from a previous session is ignored', () async {
      final gate = Completer<Booking>();
      repository.onCancel = (guid) => gate.future;
      final controller =
          BookingDetailController(repository, Booking(bookingJson()));
      addTearDown(controller.dispose);
      final pending = controller.cancel();
      await session.clear();
      gate.complete(Booking(bookingJson(status: 'cancelled', cancellable: false)));
      expect(await pending, isFalse);
      expect(controller.booking.status, 'pending_approval');
    });

    test('refresh keeps only the newest answer', () async {
      final first = Completer<Booking>();
      final second = Completer<Booking>();
      final gates = [first, second];
      repository.onBooking = (guid) => gates.removeAt(0).future;
      final controller =
          BookingDetailController(repository, Booking(bookingJson()));
      addTearDown(controller.dispose);
      final older = controller.refresh();
      final newer = controller.refresh();
      second.complete(Booking(bookingJson(status: 'confirmed')));
      await newer;
      first.complete(Booking(bookingJson(status: 'pending_approval')));
      await older;
      expect(controller.booking.status, 'confirmed');
    });

    test('awaiting_payment reads as awaiting payment, never as paid', () {
      expect(bookingStatusLabel('awaiting_payment'), 'Menunggu pembayaran');
      expect(bookingStatusNote('awaiting_payment'),
          contains('belum berarti pembayaran diterima'));
      expect(bookingStatusLabel('cancelled'), 'Dibatalkan');
      expect(bookingStatusLabel('confirmed'), 'Disetujui');
      expect(bookingStatusLabel('something_new'), 'something_new');
    });
  });

  group('documents', () {
    test('metadata, then a verified download with Bearer', () async {
      final requests = <http.Request>[];
      final live = await signedInSession((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/documents')) {
          return jsonResponse({
            'data': {
              'invoice': {'guid': 'i', 'invoice_number': 'INV-1'},
              'ticket': null
            }
          });
        }
        return http.Response.bytes(
            Uint8List.fromList('%PDF-1.4 ok'.codeUnits), 200,
            headers: {'content-type': 'application/pdf'});
      });
      final directory = await Directory.systemTemp.createTemp('user_doc_ctrl');
      addTearDown(() => directory.delete(recursive: true));
      final controller = BookingDetailController(
          repositoryFor(live), Booking(bookingJson(status: 'confirmed')));
      addTearDown(controller.dispose);

      await controller.loadDocuments();
      expect(controller.documents!.invoice, isNotNull);
      expect(controller.documents!.ticket, isNull);

      final saved = await controller.download('invoice', directory: directory);
      expect(saved, isNotNull);
      expect(File(saved!.path).existsSync(), isTrue);
      expect(controller.downloading, isNull);
      expect(requests.last.url.path,
          '/api/v1/bookings/booking-1/documents/invoice');
      expect(requests.last.headers['Authorization'], 'Bearer access');
    });

    test('a 404 download says the document is not ready', () async {
      final live = await signedInSession(
          (request) async => jsonResponse({'message': 'Not found'}, 404));
      final controller = BookingDetailController(
          repositoryFor(live), Booking(bookingJson(status: 'confirmed')));
      addTearDown(controller.dispose);
      expect(await controller.download('invoice'), isNull);
      expect(controller.message, 'Dokumen belum siap diunduh.');
    });
  });

  group('availability helpers', () {
    Availability row(String status, int remaining) => Availability({
          ...availabilityJson(capacity: 10, allocated: 10 - remaining),
          'status': status,
        });

    test('submit is allowed only for an open day with enough remaining', () {
      expect(canBookAvailability(row('open', 3), 3), isTrue);
      expect(canBookAvailability(row('open', 3), 4), isFalse);
      expect(canBookAvailability(row('open', 3), 0), isFalse);
      for (final status in [
        'full',
        'closed',
        'not_open_yet',
        'too_close',
        'unavailable'
      ]) {
        expect(canBookAvailability(row(status, 5), 1), isFalse, reason: status);
      }
      expect(canBookAvailability(null, 1), isFalse);
    });

    test('every availability status has an Indonesian label', () {
      expect(availabilityStatusLabel('open'), 'Tersedia');
      expect(availabilityStatusLabel('full'), 'Kuota penuh');
      expect(availabilityStatusLabel('closed'), 'Pendaftaran ditutup');
      expect(availabilityStatusLabel('not_open_yet'),
          'Pendaftaran belum dibuka');
      expect(availabilityStatusLabel('too_close'), startsWith('Terlalu dekat'));
      expect(availabilityStatusLabel('unavailable'), 'Tidak tersedia');
    });

    test('the row for the requested day is picked; a mismatch means no quota', () {
      final rows = [Availability(availabilityJson(date: '2027-03-11'))];
      expect(availabilityFor(rows, '2027-03-10'), isNull);
      expect(availabilityFor(rows, '2027-03-11'), isNotNull);
      expect(formatVisitDate(DateTime(2027, 3, 5)), '2027-03-05');
    });
  });
}
