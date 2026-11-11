import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/core/config/app_config.dart';
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/widgets/booking_payment_section.dart';

import 'user_support.dart';

/// The server runs in DEMO mode (or Midtrans); the app must not offer the simulator unless a build opts in.
Map<String, dynamic> _snapshot({required bool demo}) => {
      'booking_guid': 'booking-1',
      'intent_guid': null,
      'status': 'not_created',
      'amount': 20000,
      'currency': 'IDR',
      'provider': demo ? 'demo' : 'midtrans',
      'environment': demo ? 'demo' : 'sandbox',
      'test_only': true,
      'can_pay': true,
      'booking_status': 'awaiting_payment',
      'payment_status': 'unverified',
      'reason': null,
      'methods': demo
          ? [
              {'code': 'demo', 'available': true, 'reason': null}
            ]
          : [
              {
                'code': 'virtual_account',
                'available': true,
                'reason': null,
                'channels': [
                  {'channel': 'bca', 'available': true, 'reason': null}
                ]
              }
            ],
      'last_attempt': null,
      'instruction': {'presentation_type': 'unavailable'},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<http.Request>> pumpSection(
      WidgetTester tester, {required bool demoServer}) async {
    FlutterSecureStorage.setMockInitialValues({});
    final requests = <http.Request>[];
    final session = await signedInSession((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path.endsWith('/payments/methods') ||
          path.endsWith('/payment-intent')) {
        return jsonResponse({'data': _snapshot(demo: demoServer)});
      }
      if (path.endsWith('/bookings/booking-1')) {
        return jsonResponse({
          'data': bookingJson(guid: 'booking-1', status: 'awaiting_payment')
        });
      }
      return jsonResponse({'message': 'not found'}, 404);
    });
    currentUser = User(
        id: 'user-1',
        namaLengkap: 'User',
        email: 'u@example.test',
        noTelepon: '+6289655862781',
        password: '',
        createdAt: DateTime(2026),
        isLaravel: true);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: BookingPaymentSection(
                    booking: Booking(
                        bookingJson(guid: 'booking-1', status: 'awaiting_payment')),
                    repository: repositoryFor(session),
                    onReturned: () async {})))));
    await tester.pumpAndSettle();
    return requests;
  }

  tearDown(() => currentUser = null);

  test('the DEMO simulator is off unless the build opts in', () {
    expect(AppConfig.demoPaymentEnabled, isFalse);
  });

  testWidgets('a DEMO-mode server shows no simulator controls',
      (tester) async {
    final requests = await pumpSection(tester, demoServer: true);

    expect(find.textContaining('DEMO'), findsNothing);
    expect(find.text('Lanjutkan Pembayaran DEMO'), findsNothing);
    expect(find.text('Cek Status / Pulihkan Pembayaran'), findsNothing);
    expect(find.text('Pembayaran online belum tersedia saat ini.'),
        findsOneWidget);
    expect(requests.where((r) => r.url.path.contains('demo-payment')), isEmpty);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('a Midtrans server shows real payment status without simulator or wallet',
      (tester) async {
    final requests = await pumpSection(tester, demoServer: false);

    expect(find.text('Pembayaran online tersedia.'), findsOneWidget);
    expect(find.textContaining('DANA'), findsNothing);
    expect(find.textContaining('DEMO'), findsNothing);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });
}
