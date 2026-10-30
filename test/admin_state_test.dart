import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/admin_state.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';
import 'admin_test_support.dart';

Booking _booking(String guid, String status) =>
    Booking(bookingJson(guid, status));

ApiPage<Booking> _page(List<Booking> items,
        {int page = 1, int last = 1, int? total}) =>
    ApiPage(items, {'current_page': page, 'last_page': last, 'total': total ?? items.length},
        {'next': page < last ? 'next' : null});

void main() {
  group('AdminBookingDecider', () {
    test('a second tap while in flight sends no second request', () async {
      final log = <http.Request>[];
      final gate = Completer<void>();
      final session = await adminSession((request) async {
        await gate.future;
        return jsonResponse({'data': bookingJson('b1', 'confirmed')});
      }, role: 1, log: log);
      final decider = AdminBookingDecider(repositoryFor(session), session: session);

      final first = decider.decide('b1', approve: true);
      await Future<void>.delayed(Duration.zero);
      expect(decider.isBusy('b1'), isTrue);
      final second = await decider.decide('b1', approve: true);
      expect(second.kind, DecisionKind.inFlight);
      expect(second.actionable, isFalse);

      gate.complete();
      final result = await first;
      expect(result.kind, DecisionKind.applied);
      expect(result.booking!.status, 'confirmed');
      expect(log.where((r) => r.method == 'POST'), hasLength(1));
      expect(decider.isBusy('b1'), isFalse);
    });

    test('status is only what the server returns (no optimistic update)',
        () async {
      final gate = Completer<void>();
      final session = await adminSession((request) async {
        if (request.method == 'GET') {
          return jsonResponse(pageEnvelope([bookingJson('b1', 'pending_approval')]));
        }
        await gate.future;
        // The server answers with a status the client did not predict.
        return jsonResponse({'data': bookingJson('b1', 'awaiting_payment')});
      }, role: 1);
      final repo = repositoryFor(session);
      final list = PagedListController<Booking>(
          session: session,
          keyOf: (b) => b.guid,
          fetchPage: (page, filters) => repo.adminBookings(query: {'page': '$page'}));
      await list.load();
      final decider = AdminBookingDecider(repo, session: session);

      final pending = decider.decide('b1', approve: true);
      await Future<void>.delayed(Duration.zero);
      expect(list.items.single.status, 'pending_approval');
      gate.complete();
      final result = await pending;
      expect(result.booking!.status, 'awaiting_payment');
      expect(result.message, contains('Menunggu pembayaran'));
      // The decider never edits the list on its own.
      expect(list.items.single.status, 'pending_approval');
      list.dispose();
    });

    test('409 booking_not_pending re-reads the detail and reports its status',
        () async {
      final log = <http.Request>[];
      final session = await adminSession((request) async {
        if (request.method == 'POST') {
          return conflict('booking_not_pending',
              context: {'status': 'confirmed'});
        }
        return jsonResponse({'data': bookingJson('b1', 'confirmed')});
      }, role: 1, log: log);
      final decider = AdminBookingDecider(repositoryFor(session), session: session);
      final result = await decider.decide('b1', approve: false);
      expect(result.kind, DecisionKind.alreadyProcessed);
      expect(result.booking!.status, 'confirmed');
      expect(result.message, contains('sudah diproses'));
      expect(result.message, contains('Disetujui'));
      expect(log.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/v1/admin/bookings/b1/reject',
        'GET /api/v1/admin/bookings/b1',
      ]);
    });

    test('approval_deadline_passed and visit_date_too_close are precise',
        () async {
      for (final code in ['approval_deadline_passed', 'visit_date_too_close']) {
        final session = await adminSession((request) async {
          if (request.method == 'POST') return conflict(code);
          return jsonResponse({'data': bookingJson('b1', 'expired')});
        }, role: 1);
        final decider = AdminBookingDecider(repositoryFor(session), session: session);
        final result = await decider.decide('b1', approve: true);
        if (code == 'approval_deadline_passed') {
          expect(result.kind, DecisionKind.alreadyProcessed);
          expect(result.message, contains('Batas waktu persetujuan'));
          expect(result.booking!.status, 'expired');
        } else {
          expect(result.kind, DecisionKind.failed);
          expect(result.message, contains('terlalu dekat'));
          expect(result.booking, isNull);
        }
      }
    });

    test('403 and 422 are reported as definite failures without re-reading',
        () async {
      final log = <http.Request>[];
      final session = await adminSession((request) async {
        return jsonResponse({'message': 'forbidden'}, 403);
      }, role: 1, log: log);
      final decider = AdminBookingDecider(repositoryFor(session), session: session);
      final result = await decider.decide('b1', approve: true);
      expect(result.kind, DecisionKind.failed);
      expect(result.message, contains('hak akses'));
      expect(log, hasLength(1));
    });

    test('timeout reconciles via adminBooking and never re-POSTs', () async {
      final log = <http.Request>[];
      var detailStatus = 'pending_approval';
      final session = await adminSession((request) async {
        if (request.method == 'POST') throw TimeoutException('slow');
        return jsonResponse({'data': bookingJson('b1', detailStatus)});
      }, role: 1, log: log);
      final decider = AdminBookingDecider(repositoryFor(session), session: session);

      var result = await decider.decide('b1', approve: true);
      expect(result.kind, DecisionKind.reconciled);
      expect(result.booking!.status, 'pending_approval');
      expect(result.message, contains('belum terkonfirmasi'));

      detailStatus = 'confirmed';
      result = await decider.decide('b1', approve: true);
      expect(result.kind, DecisionKind.reconciled);
      expect(result.booking!.status, 'confirmed');
      expect(result.message, contains('Disetujui'));

      // Two user-initiated attempts -> exactly two POSTs, each followed by a GET.
      expect(log.map((r) => r.method), ['POST', 'GET', 'POST', 'GET']);
    });

    test('unknown outcome with a failing re-read is reported unconfirmed',
        () async {
      final session = await adminSession((request) async {
        throw TimeoutException('slow');
      }, role: 1);
      final decider = AdminBookingDecider(repositoryFor(session), session: session);
      final result = await decider.decide('b1', approve: true);
      expect(result.kind, DecisionKind.unconfirmed);
      expect(result.booking, isNull);
    });

    test('a result arriving after logout is ignored', () async {
      final gate = Completer<void>();
      final session = await adminSession((request) async {
        await gate.future;
        return jsonResponse({'data': bookingJson('b1', 'confirmed')});
      }, role: 1);
      final decider = AdminBookingDecider(repositoryFor(session), session: session);
      final pending = decider.decide('b1', approve: true);
      await Future<void>.delayed(Duration.zero);
      await session.clear();
      gate.complete();
      final result = await pending;
      expect(result.kind, DecisionKind.stale);
      expect(result.actionable, isFalse);
    });
  });

  group('PagedListController', () {
    test('loads every page and de-duplicates rows that shifted', () async {
      final session = await adminSession((_) async => jsonResponse({}), role: 1);
      final pages = <int, ApiPage<Booking>>{
        1: _page([_booking('a', 'pending_approval'), _booking('b', 'pending_approval')],
            page: 1, last: 3, total: 4),
        // 'b' moved to page 2 because a newer row was inserted at the top.
        2: _page([_booking('b', 'confirmed'), _booking('c', 'pending_approval')],
            page: 2, last: 3, total: 4),
        3: _page([_booking('d', 'rejected')], page: 3, last: 3, total: 4),
      };
      final requested = <int>[];
      final list = PagedListController<Booking>(
          session: session,
          keyOf: (b) => b.guid,
          fetchPage: (page, filters) async {
            requested.add(page);
            return pages[page]!;
          });
      await list.load();
      expect(requested, [1, 2, 3]);
      expect(list.items.map((b) => b.guid), ['a', 'b', 'c', 'd']);
      expect(list.items[1].status, 'confirmed');
      expect(list.total, 4);
      expect(list.hasLoaded, isTrue);
      list.dispose();
    });

    test('forwards the server-side filter to every page request', () async {
      final session = await adminSession((_) async => jsonResponse({}), role: 1);
      final seen = <Map<String, String>>[];
      final list = PagedListController<Booking>(
          session: session,
          keyOf: (b) => b.guid,
          fetchPage: (page, filters) async {
            seen.add({...filters, 'page': '$page'});
            return _page([_booking('p$page', 'confirmed')], page: page, last: 2);
          });
      await list.load(filters: {'status': 'confirmed'});
      expect(seen, [
        {'status': 'confirmed', 'page': '1'},
        {'status': 'confirmed', 'page': '2'},
      ]);
      list.dispose();
    });

    test('an older request finishing later does not overwrite a newer one',
        () async {
      final session = await adminSession((_) async => jsonResponse({}), role: 1);
      final gates = <String, Completer<ApiPage<Booking>>>{
        'pending_approval': Completer(),
        'confirmed': Completer(),
      };
      final list = PagedListController<Booking>(
          session: session,
          keyOf: (b) => b.guid,
          fetchPage: (page, filters) => gates[filters['status']]!.future);
      final older = list.load(filters: {'status': 'pending_approval'});
      final newer = list.load(filters: {'status': 'confirmed'});

      gates['confirmed']!.complete(_page([_booking('new', 'confirmed')]));
      await newer;
      expect(list.items.map((b) => b.guid), ['new']);

      gates['pending_approval']!.complete(_page([_booking('old', 'pending_approval')]));
      await older;
      expect(list.items.map((b) => b.guid), ['new']);
      expect(list.loading, isFalse);
      expect(list.filters, {'status': 'confirmed'});
      list.dispose();
    });

    test('an older failure cannot replace newer data with an error', () async {
      final session = await adminSession((_) async => jsonResponse({}), role: 1);
      final gates = [Completer<ApiPage<Booking>>(), Completer<ApiPage<Booking>>()];
      var call = 0;
      final list = PagedListController<Booking>(
          session: session,
          keyOf: (b) => b.guid,
          fetchPage: (page, filters) => gates[call++].future);
      final older = list.load();
      final newer = list.load();
      gates[1].complete(_page([_booking('x', 'confirmed')]));
      await newer;
      gates[0].completeError(const ApiException('boom'));
      await older;
      expect(list.error, isNull);
      expect(list.items.single.guid, 'x');
      list.dispose();
    });

    test('rows of another filter are cleared while the new filter loads',
        () async {
      final session = await adminSession((_) async => jsonResponse({}), role: 1);
      final gate = Completer<ApiPage<Booking>>();
      var first = true;
      final list = PagedListController<Booking>(
          session: session,
          keyOf: (b) => b.guid,
          fetchPage: (page, filters) {
            if (first) {
              first = false;
              return Future.value(_page([_booking('a', 'pending_approval')]));
            }
            return gate.future;
          });
      await list.load(filters: {'status': 'pending_approval'});
      expect(list.items, hasLength(1));
      final next = list.load(filters: {'status': 'rejected'});
      expect(list.items, isEmpty);
      expect(list.hasLoaded, isFalse);
      gate.complete(_page([_booking('r', 'rejected')]));
      await next;
      expect(list.items.single.guid, 'r');
      list.dispose();
    });

    test('logout or account switch drops a late response', () async {
      final session = await adminSession((_) async => jsonResponse({}), role: 1);
      final gate = Completer<ApiPage<Booking>>();
      final list = PagedListController<Booking>(
          session: session, keyOf: (b) => b.guid, fetchPage: (page, f) => gate.future);
      final loading = list.load();
      expect(list.loading, isTrue);

      await session.clear();
      expect(list.loading, isFalse);
      gate.complete(_page([_booking('secret', 'confirmed')]));
      await loading;

      expect(list.items, isEmpty);
      expect(list.error, isNull);
      expect(list.hasLoaded, isFalse);
      list.dispose();
    });

    test('a late response after dispose is harmless', () async {
      final session = await adminSession((_) async => jsonResponse({}), role: 1);
      final gate = Completer<ApiPage<Booking>>();
      final list = PagedListController<Booking>(
          session: session, keyOf: (b) => b.guid, fetchPage: (page, f) => gate.future);
      final loading = list.load();
      list.dispose();
      gate.complete(_page([_booking('x', 'confirmed')]));
      await loading;
    });
  });

  group('role gating', () {
    test('menu entries follow the role (UX only)', () {
      expect(canManageCategories(2), isTrue);
      expect(canManageCategories(1), isFalse);
      expect(canManageCategories(0), isFalse);
      expect(canManageCategories(null), isFalse);
      expect(canManageAdmins(2), isTrue);
      expect(canManageAdmins(1), isFalse);
      expect(canManageQuota(1), isTrue);
      expect(canManageQuota(2), isTrue);
      expect(canManageQuota(0), isFalse);
      expect(canAccessAdmin(null), isFalse);
    });

    test('own account never offers role or status changes', () {
      final me = AdminAccount({'guid': 'me', 'role': 2});
      final other = AdminAccount({'guid': 'other', 'role': 1});
      expect(canModifyAccount(me, 'me'), isFalse);
      expect(canModifyAccount(other, 'me'), isTrue);
      expect(canModifyAccount(other, null), isFalse);
    });
  });

  group('helpers', () {
    test('slug suggestion from a name', () {
      expect(slugify('Wisata Bahari & Pantai!'), 'wisata-bahari-pantai');
      expect(slugify('  Alam  '), 'alam');
      expect(slugify('---'), '');
    });

    test('image validation: JPEG/PNG/WebP up to 5 MB', () {
      final jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0];
      final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0];
      final webp = [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0];
      final gif = [0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0, 0, 0, 0, 0, 0, 0];
      expect(validateDestinationImage(jpeg), isNull);
      expect(validateDestinationImage(png), isNull);
      expect(validateDestinationImage(webp), isNull);
      expect(validateDestinationImage(gif), contains('JPEG, PNG, atau WebP'));
      expect(validateDestinationImage(const []), isNotNull);
      final big = List<int>.filled(kMaxImageBytes + 1, 0)..setRange(0, 3, [0xFF, 0xD8, 0xFF]);
      expect(validateDestinationImage(big), contains('5 MB'));
      final atLimit = List<int>.filled(kMaxImageBytes, 0)..setRange(0, 3, [0xFF, 0xD8, 0xFF]);
      expect(validateDestinationImage(atLimit), isNull);
    });

    test('quota input validation: closes must be after opens', () {
      final opens = DateTime(2026, 11, 1, 8);
      expect(
          validateQuotaInput(
              visitDate: DateTime(2026, 12, 1),
              capacity: 10,
              opensAt: opens,
              closesAt: opens),
          contains('setelah'));
      expect(
          validateQuotaInput(
              visitDate: DateTime(2026, 12, 1),
              capacity: -1,
              opensAt: opens,
              closesAt: opens.add(const Duration(hours: 1))),
          contains('Kapasitas'));
      expect(
          validateQuotaInput(
              visitDate: null,
              capacity: 1,
              opensAt: opens,
              closesAt: opens.add(const Duration(hours: 1))),
          contains('Tanggal'));
      expect(
          validateQuotaInput(
              visitDate: DateTime(2026, 12, 1),
              capacity: 0,
              opensAt: opens,
              closesAt: opens.add(const Duration(hours: 1))),
          isNull);
    });

    test('quota payload uses UTC ISO-8601 with Z', () {
      final payload = buildQuotaPayload(
          visitDate: DateTime(2026, 12, 1),
          capacity: 5,
          opensAt: DateTime.utc(2026, 11, 1, 1, 30),
          closesAt: DateTime.utc(2026, 11, 30, 23));
      expect(payload, {
        'visit_date': '2026-12-01',
        'capacity': 5,
        'booking_opens_at': '2026-11-01T01:30:00.000Z',
        'booking_closes_at': '2026-11-30T23:00:00.000Z',
      });
    });

    test('error messages are keyed on the structured code', () {
      String message(String code, {int status = 409, Map<String, dynamic>? context}) =>
          adminErrorMessage(ApiException('x', status, code, context));
      expect(message('category_in_use'), contains('destinasi aktif'));
      expect(message('category_inactive'), contains('kategorinya nonaktif'));
      expect(message('insufficient_capacity', context: {'remaining': 3}),
          contains('tersisa 3'));
      expect(adminErrorMessage(const ApiException('x', 403)), contains('hak akses'));
      expect(adminErrorMessage(const ApiException('Slug sudah dipakai.', 422)),
          'Slug sudah dipakai.');
      expect(
          adminErrorMessage(const ApiException(
              'The last active superadmin cannot be suspended or demoted.', 422)),
          contains('Superadmin aktif terakhir'));
    });

    test('server visit_date timestamps are shown as a day', () {
      expect(visitDay('2026-12-01T00:00:00.000000Z'), '2026-12-01');
      expect(visitDay('2026-12-01'), '2026-12-01');
      expect(formatMoney(25000, 'IDR'), 'IDR 25.000');
      expect(formatMoney(0, 'IDR'), 'Gratis');
    });
  });
}
