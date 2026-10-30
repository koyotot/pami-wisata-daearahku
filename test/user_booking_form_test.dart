import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/booking_intent.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/screens/daftar_kunjungan_screen.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'user_support.dart';

class FormRepository extends BusinessRepository {
  FormRepository() : super(ApiClient(AuthSession.instance));
  Availability? availabilityAnswer;
  BookingIntentState? intentAnswer;
  int posts = 0;
  int availabilityCalls = 0;
  String? lastVisitDate;

  @override
  Future<List<Availability>> availability(String destinationGuid,
      {String? visitDate, String? from, String? to}) async {
    availabilityCalls++;
    lastVisitDate = visitDate;
    final answer = availabilityAnswer;
    return answer == null ? [] : [answer];
  }

  @override
  Future<Booking> createBooking(Json fields, String idempotencyKey) async {
    posts++;
    return Booking(bookingJson());
  }

  @override
  Future<BookingIntentState> bookingIntent(String key) async => intentAnswer!;
}

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

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    currentUser = User(
        id: 'user-1',
        namaLengkap: 'User',
        email: 'u@example.test',
        noTelepon: '0812345678',
        password: '',
        createdAt: DateTime(2026),
        isLaravel: true);
    repository = FormRepository();
  });
  tearDown(() => currentUser = null);

  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: DaftarKunjunganScreen(
      wisata: wisata,
      repository: repository,
      intent: BookingIntent(repository: repository),
      initialDate: DateTime(2027, 3, 10),
    )));
    await tester.pumpAndSettle();
  }

  bool submitEnabled(WidgetTester tester) => tester
      .widget<GestureDetector>(find.byKey(const ValueKey('submitButton')))
      .onTap != null;

  testWidgets('a full day shows the server numbers and disables submit',
      (tester) async {
    repository.availabilityAnswer =
        availability('full', capacity: 10, allocated: 10);
    await pumpForm(tester);

    expect(repository.lastVisitDate, '2027-03-10');
    expect(find.text('Kuota penuh'), findsOneWidget);
    expect(find.text('Kuota total 10 · sisa 0'), findsOneWidget);
    expect(submitEnabled(tester), isFalse);

    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pump();
    expect(repository.posts, 0);
  });

  testWidgets('an open day enables submit only while quantity fits the remaining',
      (tester) async {
    repository.availabilityAnswer =
        availability('open', capacity: 10, allocated: 9); // remaining 1
    await pumpForm(tester);
    expect(find.text('Tersedia'), findsOneWidget);
    expect(find.text('Kuota total 10 · sisa 1'), findsOneWidget);
    expect(submitEnabled(tester), isTrue);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(submitEnabled(tester), isFalse);
    expect(find.textContaining('melebihi sisa kuota'), findsOneWidget);
  });

  testWidgets('a day without a published quota is not bookable', (tester) async {
    repository.availabilityAnswer = null;
    await pumpForm(tester);
    expect(find.textContaining('belum tersedia'), findsWidgets);
    expect(submitEnabled(tester), isFalse);
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

  testWidgets('a completed check shows the booking number and the SERVER status',
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
    expect(find.byKey(const ValueKey('intentPanel')), findsNothing);
    expect(await const FlutterSecureStorage().read(key: 'booking_intent_user-1'),
        isNull);
    expect(find.textContaining('QR'), findsNothing);
  });
}
