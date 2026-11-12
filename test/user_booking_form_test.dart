import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/booking_intent.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/screens/user/daftar_kunjungan_screen.dart';
import 'package:wisata_daerahku/screens/user/permintaan_terkirim_screen.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'user_support.dart';

class FormRepository extends BusinessRepository {
  FormRepository(AuthSession session) : super(ApiClient(session));
  Availability? availabilityAnswer;
  BookingIntentState? intentAnswer;
  int posts = 0;
  int availabilityCalls = 0;
  String? lastMonth;
  int intentCalls = 0;
  Future<MonthlyAvailability> Function(String month, int quantity)? monthlyHook;
  Future<Booking> Function(Json fields)? createHook;
  Json? postedFields;
  String? postedKey;
  Booking? completedAbandon;

  @override
  Future<BookingIntentState> abandonBookingIntent(String key) async {
    throw ApiException('Sudah tercatat', 409, 'intent_already_completed',
        {'booking_guid': completedAbandon!.guid});
  }

  @override
  Future<Booking> booking(String guid) async => completedAbandon!;

  @override
  Future<MonthlyAvailability> monthlyAvailability(
      String destinationGuid, String month, int quantity) async {
    availabilityCalls++;
    lastMonth = month;
    if (monthlyHook != null) return monthlyHook!(month, quantity);
    final answer = availabilityAnswer;
    return MonthlyAvailability({
      'destination_guid': destinationGuid,
      'month': month,
      'timezone': 'Asia/Jakarta',
      'requested_quantity': quantity,
      'dates': answer == null
          ? []
          : [
              {
                'date': answer.visitDate,
                'capacity': answer.capacity,
                'remaining': answer.remaining,
                'remaining_percent': answer.capacity == 0
                    ? null
                    : answer.remaining / answer.capacity * 100,
                'level': answer.remaining > 0 ? 'low' : 'none',
                'status': answer.isOpen
                    ? (quantity <= answer.remaining
                        ? 'available'
                        : 'insufficient_quantity')
                    : 'sold_out',
                'bookable': answer.isOpen && quantity <= answer.remaining,
              }
            ],
    });
  }

  @override
  Future<Booking> createBooking(Json fields, String idempotencyKey) async {
    posts++;
    postedFields = Map.of(fields);
    postedKey = idempotencyKey;
    if (createHook != null) return createHook!(fields);
    return Booking(bookingJson());
  }

  @override
  Future<BookingIntentState> bookingIntent(String key) async {
    intentCalls++;
    return intentAnswer!;
  }
}

class BookingRouteObserver extends NavigatorObserver {
  int replacements = 0;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacements++;
  }
}

MonthlyAvailability monthAnswer(String month, int quantity,
        {int remaining = 10}) =>
    MonthlyAvailability({
      'destination_guid': 'dest-1',
      'month': month,
      'timezone': 'Asia/Jakarta',
      'requested_quantity': quantity,
      'dates': [
        {
          'date': '$month-10',
          'capacity': 100,
          'remaining': remaining,
          'remaining_percent': remaining.toDouble(),
          'level': 'low',
          'status':
              quantity <= remaining ? 'available' : 'insufficient_quantity',
          'bookable': quantity <= remaining,
        }
      ],
    });

Availability availability(String status,
        {int capacity = 10, int allocated = 0, String date = '2027-03-10'}) =>
    Availability(availabilityJson(
        date: date, capacity: capacity, allocated: allocated, status: status));

final wisata = Wisata(
    id: 'dest-1',
    nama: 'Pantai Test',
    lokasi: 'Bali',
    deskripsi: 'd',
    hargaTiket: 'IDR 10000',
    jamBuka: '08.00',
    kategori: 'Pantai',
    isLaravel: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FormRepository repository;
  late BookingRouteObserver observer;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    final session = await signedInSession((_) async => jsonResponse({}));
    currentUser = User(
        id: 'user-1',
        namaLengkap: 'User',
        email: 'u@example.test',
        noTelepon: '+6289655862781',
        password: '',
        createdAt: DateTime(2026),
        isLaravel: true);
    repository = FormRepository(session);
    observer = BookingRouteObserver();
  });
  tearDown(() => currentUser = null);

  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        navigatorObservers: [observer],
        home: DaftarKunjunganScreen(
          wisata: wisata,
          repository: repository,
          intent: BookingIntent(repository: repository),
          initialDate: DateTime(2027, 3, 10),
        )));
    await tester.pumpAndSettle();
  }

  bool submitEnabled(WidgetTester tester) =>
      tester
          .widget<GestureDetector>(find.byKey(const ValueKey('submitButton')))
          .onTap !=
      null;

  testWidgets('a full day shows the server numbers and disables submit',
      (tester) async {
    repository.availabilityAnswer =
        availability('full', capacity: 10, allocated: 10);
    await pumpForm(tester);

    expect(repository.lastMonth, '2027-03');
    expect(find.text('Habis'), findsWidgets);
    expect(find.text('Kuota total 10 · sisa 0'), findsOneWidget);
    expect(submitEnabled(tester), isFalse);

    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pump();
    expect(repository.posts, 0);
    expect(observer.replacements, 0);
  });

  testWidgets(
      'an open day enables submit only while quantity fits the remaining',
      (tester) async {
    repository.availabilityAnswer =
        availability('open', capacity: 10, allocated: 9); // remaining 1
    await pumpForm(tester);
    expect(find.text('Tersedia'), findsOneWidget);
    expect(find.text('Kuota total 10 · sisa 1'), findsOneWidget);
    expect(submitEnabled(tester), isTrue);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(submitEnabled(tester), isFalse);
    expect(repository.availabilityCalls, 2);
  });

  testWidgets('a day without a published quota is not bookable',
      (tester) async {
    repository.availabilityAnswer = null;
    await pumpForm(tester);
    expect(find.textContaining('belum tersedia'), findsWidgets);
    expect(submitEnabled(tester), isFalse);
  });

  testWidgets('old quantity response cannot overwrite newer calendar',
      (tester) async {
    final oldReply = Completer<MonthlyAvailability>();
    repository.monthlyHook = (month, quantity) => quantity == 2
        ? oldReply.future
        : Future.value(monthAnswer(month, quantity));
    await pumpForm(tester);
    expect(submitEnabled(tester), isTrue);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(submitEnabled(tester), isFalse,
        reason: 'unverified quantity cannot submit');
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(submitEnabled(tester), isTrue);
    oldReply.complete(monthAnswer('2027-03', 2, remaining: 0));
    await tester.pumpAndSettle();
    expect(find.text('Kuota total 100 · sisa 10'), findsOneWidget);
    expect(submitEnabled(tester), isTrue);
  });

  testWidgets(
      'nullable quota summary shows missing values without inventing zero',
      (tester) async {
    repository.monthlyHook = (month, quantity) async => MonthlyAvailability({
          ...monthAnswer(month, quantity).json,
          'dates': [
            {
              'date': '$month-10',
              'capacity': null,
              'remaining': null,
              'remaining_percent': null,
              'level': 'none',
              'status': 'unconfigured',
              'bookable': false,
            }
          ],
        });
    await pumpForm(tester);
    expect(find.text('Kuota total — · sisa —'), findsOneWidget);
    expect(submitEnabled(tester), isFalse);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('old month response cannot overwrite the visible month',
      (tester) async {
    final oldReply = Completer<MonthlyAvailability>();
    repository.monthlyHook = (month, quantity) => month == '2027-04'
        ? oldReply.future
        : Future.value(monthAnswer(month, quantity));
    await pumpForm(tester);
    await tester.tap(find.byTooltip('Bulan berikutnya'));
    await tester.pump();
    await tester.tap(find.byTooltip('Bulan berikutnya'));
    await tester.pumpAndSettle();
    expect(find.text('2027-05'), findsOneWidget);
    oldReply.complete(monthAnswer('2027-04', 1, remaining: 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('availability-2027-05-10')));
    await tester.pump();
    expect(find.text('Kuota total 100 · sisa 10'), findsOneWidget);
    expect(submitEnabled(tester), isTrue);
  });

  testWidgets('logout drops in-flight calendar and clears phone contact',
      (tester) async {
    final oldReply = Completer<MonthlyAvailability>();
    repository.monthlyHook = (month, quantity) => quantity == 2
        ? oldReply.future
        : Future.value(monthAnswer(month, quantity));
    await pumpForm(tester);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await tester.runAsync(() => repository.api.session.clear());
    oldReply.complete(monthAnswer('2027-03', 2));
    await tester.pumpAndSettle();
    expect(submitEnabled(tester), isFalse);
    expect(find.text('Kuota total 100 · sisa 10'), findsNothing);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('bookingPhone')))
            .controller!
            .text,
        isEmpty);
  });

  testWidgets('phone 422 stays inline with form and original input retained',
      (tester) async {
    repository.availabilityAnswer = availability('open');
    repository.createHook = (_) async => throw const ApiException(
        'Nomor ditolak server',
        422,
        null,
        null,
        {'visitor_phone': 'Nomor kontak tidak valid.'});
    await pumpForm(tester);
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();
    expect(find.text('Nomor kontak tidak valid.'), findsOneWidget);
    expect(repository.posts, 1);
    expect(repository.postedFields!['visitor_phone'], '+6289655862781');
    expect(find.byKey(const ValueKey('bookingPhone')), findsOneWidget);
    expect(find.byType(PermintaanTerkirimScreen), findsNothing);
    expect(
        await const FlutterSecureStorage().read(key: 'booking_intent_user-1'),
        isNull);
  });

  testWidgets(
      'ambiguous 409 reconciles intent and refreshes without second POST',
      (tester) async {
    repository.availabilityAnswer = availability('open');
    repository.createHook = (_) async =>
        throw const ApiException('Kuota berubah', 409, 'quota_changed');
    repository.intentAnswer = BookingIntentState({
      'state': 'not_found',
      'replay_safe': true,
      'key_expired': false,
      'booking': null,
    });
    await pumpForm(tester);
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();
    expect(repository.posts, 1);
    expect(repository.intentCalls, 1);
    expect(find.byType(PermintaanTerkirimScreen), findsNothing);
    expect(repository.availabilityCalls, 2);
    expect(find.byKey(const ValueKey('intentPanel')), findsOneWidget);
    expect(submitEnabled(tester), isFalse);
    expect(
        await const FlutterSecureStorage().read(key: 'booking_intent_user-1'),
        isNotNull);
  });

  testWidgets(
      'an unresolved intent shows the three actions; Kirim ulang needs replay-safe',
      (tester) async {
    repository.availabilityAnswer = availability('open');
    await const FlutterSecureStorage().write(
        key: 'booking_intent_user-1',
        value:
            '{"fields":"{\\"destination_guid\\":\\"dest-1\\",\\"visit_date\\":\\"2027-03-10\\",\\"quantity\\":2,\\"visitor_name\\":\\"User\\"}","key":"abc123"}');
    await pumpForm(tester);

    expect(find.byKey(const ValueKey('intentPanel')), findsOneWidget);
    expect(find.text('Periksa hasil'), findsOneWidget);
    expect(find.text('Batalkan percobaan'), findsOneWidget);
    expect(find.text('Kirim ulang'), findsNothing);
    // The unresolved attempt blocks a new booking even though the day is open.
    expect(submitEnabled(tester), isFalse);

    repository.intentAnswer = BookingIntentState({
      'key': 'abc123',
      'state': 'not_found',
      'replay_safe': true,
      'key_expired': false,
      'booking': null,
    });
    await tester.tap(find.text('Periksa hasil'));
    await tester.pumpAndSettle();
    expect(find.text('Kirim ulang'), findsOneWidget);
    expect(repository.posts, 0, reason: 'checking must never create a booking');
  });

  testWidgets(
      'a completed check shows the booking number and the SERVER status',
      (tester) async {
    repository.availabilityAnswer = availability('open');
    await const FlutterSecureStorage().write(
        key: 'booking_intent_user-1',
        value: '{"fields":"{\\"quantity\\":2}","key":"abc123"}');
    await pumpForm(tester);

    repository.intentAnswer = BookingIntentState({
      'key': 'abc123',
      'state': 'completed',
      'replay_safe': true,
      'key_expired': false,
      'booking': bookingJson(status: 'awaiting_payment', number: 'BK-777'),
    });
    await tester.tap(find.text('Periksa hasil'));
    await tester.pumpAndSettle();

    expect(find.text('Nomor: BK-777'), findsOneWidget);
    expect(find.text('Status: Menunggu pembayaran'), findsOneWidget);
    expect(find.byType(PermintaanTerkirimScreen), findsOneWidget);
    expect(find.byType(DaftarKunjunganScreen), findsNothing);
    expect(repository.posts, 0);
    expect(observer.replacements, 1);
    expect(find.byKey(const ValueKey('intentPanel')), findsNothing);
    expect(
        await const FlutterSecureStorage().read(key: 'booking_intent_user-1'),
        isNull);
    expect(find.textContaining('QR'), findsNothing);
  });

  testWidgets('confirmed submit replaces form once with actual server summary',
      (tester) async {
    repository.availabilityAnswer = availability('open');
    final response = Completer<Booking>();
    repository.createHook = (_) => response.future;
    await pumpForm(tester);
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    expect(repository.posts, 1);
    response.complete(Booking({
      ...bookingJson(number: 'BK-SERVER'),
      'destination_name': 'Nama dari server',
      'quantity': 5,
    }));
    await tester.pumpAndSettle();
    expect(find.byType(PermintaanTerkirimScreen), findsOneWidget);
    expect(find.byType(DaftarKunjunganScreen), findsNothing);
    expect(find.text('Nama dari server'), findsOneWidget);
    expect(find.text('5 orang'), findsOneWidget);
    expect(find.text('Nomor: BK-SERVER'), findsOneWidget);
    expect(find.text('Pendaftaran diterima server'), findsNothing);
    expect(find.text('Pendaftaran Terkonfirmasi Server'), findsNothing);
    expect(observer.replacements, 1);
    expect(repository.posts, 1);
  });

  testWidgets('409 completed reconciliation opens success without second POST',
      (tester) async {
    repository.availabilityAnswer = availability('open');
    repository.createHook = (_) async =>
        throw const ApiException('Outcome belum diketahui', 409, 'unknown');
    repository.intentAnswer = BookingIntentState({
      'state': 'completed',
      'booking': bookingJson(status: 'rejected', number: 'BK-409'),
    });
    await pumpForm(tester);
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();
    expect(find.byType(PermintaanTerkirimScreen), findsOneWidget);
    expect(find.text('Status: Ditolak'), findsOneWidget);
    expect(observer.replacements, 1);
    expect(repository.posts, 1);
    expect(repository.intentCalls, 1);
  });

  testWidgets(
      'unknown outcome stays unresolved and replay keeps payload and key',
      (tester) async {
    repository.availabilityAnswer = availability('open');
    repository.createHook = (_) async => throw const ApiException('Timeout');
    await pumpForm(tester);
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();
    expect(find.byType(PermintaanTerkirimScreen), findsNothing);
    expect(find.byKey(const ValueKey('intentPanel')), findsOneWidget);
    final original = jsonDecode((await const FlutterSecureStorage()
        .read(key: 'booking_intent_user-1'))!) as Json;
    repository.intentAnswer = BookingIntentState({
      'state': 'not_found',
      'replay_safe': true,
    });
    await tester.tap(find.byKey(const ValueKey('intentCheck')));
    await tester.pumpAndSettle();
    repository.createHook = (_) async =>
        Booking(bookingJson(status: 'cancelled', number: 'BK-REPLAY'));
    await tester.tap(find.byKey(const ValueKey('intentResend')));
    await tester.pumpAndSettle();
    expect(find.byType(PermintaanTerkirimScreen), findsOneWidget);
    expect(find.text('Status: Dibatalkan'), findsOneWidget);
    expect(observer.replacements, 1);
    expect(repository.posts, 2);
    expect(repository.postedKey, original['key']);
    expect(repository.postedFields, jsonDecode(original['fields'] as String));
  });

  testWidgets('logout during submit cannot display old account success',
      (tester) async {
    repository.availabilityAnswer = availability('open');
    final response = Completer<Booking>();
    repository.createHook = (_) => response.future;
    await pumpForm(tester);
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pump();
    await tester.runAsync(() => repository.api.session.clear());
    response.complete(Booking(bookingJson()));
    await tester.pumpAndSettle();
    expect(find.byType(PermintaanTerkirimScreen), findsNothing);
    expect(repository.posts, 1);
  });

  testWidgets('abandon already-completed intent shows success without POST',
      (tester) async {
    repository.availabilityAnswer = availability('open');
    repository.completedAbandon = Booking(bookingJson(number: 'BK-ABANDON'));
    await const FlutterSecureStorage().write(
        key: 'booking_intent_user-1',
        value: jsonEncode({
          'fields': jsonEncode({'quantity': 2}),
          'key': 'key'
        }));
    await pumpForm(tester);
    await tester.tap(find.byKey(const ValueKey('intentAbandon')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Batalkan percobaan'));
    await tester.pumpAndSettle();
    expect(find.byType(PermintaanTerkirimScreen), findsOneWidget);
    expect(find.text('Nomor: BK-ABANDON'), findsOneWidget);
    expect(observer.replacements, 1);
    expect(repository.posts, 0);
  });
}
