import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/booking_intent.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

class FakeRepository extends BusinessRepository {
  FakeRepository(AuthSession session) : super(ApiClient(session));
  final keys = <String>[];
  final requests = <Map<String, dynamic>>[];
  bool fail = true;
  Completer<void>? gate;
  int? failureStatus;
  @override
  Future<Booking> createBooking(Json fields, String idempotencyKey) async {
    requests.add(Map.of(fields));
    if (gate != null) await gate!.future;
    keys.add(idempotencyKey);
    if (fail) throw ApiException('error', failureStatus);
    return Booking({'guid': 'booking'});
  }

  @override
  Future<Booking> booking(String guid) async => Booking({
        'guid': guid,
        'booking_number': 'BK-1',
        'status': 'pending_approval',
        'destination_guid': 'destination',
        'visit_date': '2027-01-01',
        'visitor_name': 'A',
        'visitor_email': 'a@example.com',
        'visitor_phone': '1',
        'destination_name': 'Wisata',
        'quantity': 1,
        'notes': null,
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    currentUser = User(
        id: 'user',
        namaLengkap: 'A',
        email: 'a@example.com',
        noTelepon: '1',
        password: '',
        createdAt: DateTime(2026),
        isLaravel: true);
  });
  tearDown(() => currentUser = null);
  test('hasil tidak diketahui direkonsiliasi dengan payload dan key awal',
      () async {
    final repository = FakeRepository(AuthSession());
    final intent = BookingIntent(repository: repository);
    final initial = {'destination_guid': 'destination', 'quantity': 1};
    await expectLater(
        intent.submit('user', initial), throwsA(isA<ApiException>()));
    expect(await intent.pending('user'), initial);
    await expectLater(
        intent.submit('user', {'quantity': 2}), throwsA(isA<ApiException>()));
    repository.fail = false;
    final booking =
        await intent.submit('user', {'quantity': 2}, reconcile: true);
    expect(booking.guid, 'booking');
    expect(repository.keys[0], repository.keys[1]);
    expect(repository.requests[1], initial);
    expect(await intent.pending('user'), isNull);
  });
  test('konflik pertama melepaskan intent dan akun lain ditolak', () async {
    final repository = FakeRepository(AuthSession())..failureStatus = 409;
    final intent = BookingIntent(repository: repository);
    await expectLater(
        intent.submit('user', {'quantity': 1}), throwsA(isA<ApiException>()));
    expect(await intent.pending('user'), isNull);
    await expectLater(intent.pending('other'), throwsA(isA<ApiException>()));
  });
  test('422 saat rekonsiliasi tetap menyimpan intent', () async {
    final repository = FakeRepository(AuthSession());
    final intent = BookingIntent(repository: repository);
    await expectLater(
        intent.submit('user', {'quantity': 1}), throwsA(isA<ApiException>()));
    repository.failureStatus = 422;
    await expectLater(intent.submit('user', {}, reconcile: true),
        throwsA(isA<ApiException>()));
    expect(await intent.pending('user'), {'quantity': 1});
  });
  test('double tap ditolak dan respons sesi lama disimpan untuk rekonsiliasi',
      () async {
    final session = AuthSession();
    final repository = FakeRepository(session)
      ..fail = false
      ..gate = Completer<void>();
    final intent = BookingIntent(repository: repository);
    final first = intent.submit('user', {'quantity': 1});
    while (repository.requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await expectLater(
        intent.submit('user', {'quantity': 1}), throwsA(isA<ApiException>()));
    await session.clear();
    repository.gate!.complete();
    await expectLater(first, throwsA(isA<ApiException>()));
    currentUser = User(
        id: 'user',
        namaLengkap: 'A',
        email: 'a@example.com',
        noTelepon: '1',
        password: '',
        createdAt: DateTime(2026),
        isLaravel: true);
    expect(await intent.pending('user'), {'quantity': 1});
    expect(repository.requests, hasLength(1));
  });
}
