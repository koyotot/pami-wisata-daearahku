import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/booking_intent.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'user_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  tearDown(() => currentUser = null);

  test('HTTP replay preserves original phone punctuation, payload and key',
      () async {
    final requests = <http.Request>[];
    var posts = 0;
    final session = await signedInSession((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        posts++;
        final stored = await const FlutterSecureStorage()
            .read(key: 'booking_intent_user-1');
        expect(stored, isNotNull, reason: 'intent must exist before each POST');
        final persisted = jsonDecode(stored!) as Map<String, dynamic>;
        expect(persisted['key'], request.headers['Idempotency-Key']);
        expect(jsonDecode(persisted['fields'] as String),
            jsonDecode(request.body));
        if (posts == 1) throw TimeoutException('response lost');
        return jsonResponse({
          'data': {
            ...bookingJson(),
            'visitor_phone': '+6289655862781',
          }
        });
      }
      return jsonResponse({
        'data': {
          'state': 'not_found',
          'replay_safe': true,
          'key_expired': false,
          'booking': null,
        }
      });
    });
    final repository = repositoryFor(session);
    final intent = BookingIntent(repository: repository);
    final original = {
      'destination_guid': 'dest-1',
      'visit_date': '2027-03-10',
      'quantity': 2,
      'visitor_name': 'User',
      'visitor_email': 'u@example.test',
      'visitor_phone': '+62 896-5586-2781',
      'notes': '',
    };
    await expectLater(
        intent.submit('user-1', original),
        throwsA(isA<ApiException>()
            .having((e) => e.outcomeUnknown, 'unknown', true)));
    expect(await intent.pending('user-1'), original);
    expect(await intent.reconcile('user-1'), isA<IntentNotFound>());
    final result = await intent.submit(
        'user-1',
        {
          ...original,
          'visitor_phone': '+14155552671',
          'quantity': 9,
          'visit_date': '2028-01-01',
        },
        reconcile: true);
    final creates = requests.where((r) => r.method == 'POST').toList();
    expect(creates, hasLength(2));
    expect(creates.last.body, creates.first.body);
    expect(creates.last.headers['Idempotency-Key'],
        creates.first.headers['Idempotency-Key']);
    expect(jsonDecode(creates.last.body)['visitor_phone'], '+62 896-5586-2781');
    expect(result.visitorPhone, '+6289655862781');
    expect(currentUser!.noTelepon, '0812345678',
        reason: 'booking snapshot must not overwrite profile in client');
    expect(requests.any((r) => r.method == 'PATCH'), isFalse);
    expect(await intent.pending('user-1'), isNull);
  });

  test(
      'phone 422 preserves profile and removes only definitively refused intent',
      () async {
    final requests = <http.Request>[];
    final session = await signedInSession((request) async {
      requests.add(request);
      return jsonResponse({
        'message': 'Nomor tidak valid',
        'errors': {
          'visitor_phone': ['Gunakan nomor internasional yang valid.']
        }
      }, 422);
    });
    final intent = BookingIntent(repository: repositoryFor(session));
    await expectLater(
        intent.submit('user-1', {'visitor_phone': '+62123'}),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 422)
            .having((e) => e.fieldErrors['visitor_phone'], 'phone error',
                'Gunakan nomor internasional yang valid.')));
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/v1/bookings');
    expect(requests.single.method, 'POST');
    expect(currentUser!.noTelepon, '0812345678');
    expect(await intent.pending('user-1'), isNull);
  });
}
