import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

class _Store implements SessionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

http.Response _json(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json'});

Map<String, dynamic> _me(int role) => {
      'data': {
        'guid': 'u1',
        'name': 'U',
        'email': 'u@example.test',
        'phone': null,
        'role': role,
        'status': 'active'
      }
    };

/// Logs in through the mock and routes everything else to [handler].
Future<AuthSession> _session(
    Future<http.Response> Function(http.Request request) handler,
    {int role = 1}) async {
  final session = AuthSession(
      baseUrl: 'https://example.test/api/v1',
      store: _Store(),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return _json({
            'data': {
              'access_token': 'access-1',
              'refresh_token': 'refresh-1',
              'user': {'guid': 'u1', 'name': 'U', 'email': 'u@example.test'}
            }
          });
        }
        if (request.url.path.endsWith('/auth/me')) return _json(_me(role));
        if (request.url.path.endsWith('/auth/refresh')) {
          return _json({
            'data': {
              'access_token': 'access-2',
              'refresh_token': 'refresh-2',
              'user': {'guid': 'u1', 'name': 'U', 'email': 'u@example.test'}
            }
          });
        }
        return handler(request);
      }));
  await session.login('u@example.test', 'password');
  return session;
}

void main() {
  group('structured errors', () {
    test('409 exposes code, context and the server message', () async {
      final session = await _session((_) async => _json({
            'message': 'Insufficient capacity.',
            'code': 'insufficient_capacity',
            'context': {'remaining': 2}
          }, 409));
      final repository = BusinessRepository(ApiClient(session));
      try {
        await repository.createBooking({'quantity': 5}, 'key-1');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.status, 409);
        expect(e.code, 'insufficient_capacity');
        expect(e.context?['remaining'], 2);
        expect(e.message, 'Insufficient capacity.');
        expect(e.outcomeUnknown, isFalse);
      }
    });

    test('a 409 without a code stays generic and still is not success',
        () async {
      final session = await _session((_) async => _json({}, 409));
      try {
        await BusinessRepository(ApiClient(session)).booking('b1');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.status, 409);
        expect(e.code, isNull);
      }
    });

    test('timeouts, network failures, 5xx and malformed 2xx are unknown outcomes',
        () async {
      var mode = 0;
      final session = await _session((request) async {
        switch (mode) {
          case 0:
            throw TimeoutException('slow');
          case 1:
            throw http.ClientException('offline');
          case 2:
            return _json({'message': 'boom'}, 503);
          default:
            return http.Response('<html>ok</html>', 200);
        }
      });
      final repository = BusinessRepository(ApiClient(session));
      final codes = <String?>[];
      for (mode = 0; mode < 4; mode++) {
        try {
          await repository.createBooking({}, 'k');
          fail('expected ApiException');
        } on ApiException catch (e) {
          expect(e.outcomeUnknown, isTrue, reason: 'mode $mode');
          codes.add(e.code);
        }
      }
      expect(codes, ['timeout', 'network', null, 'invalid_response']);
    });

    test('definitive failures are not unknown outcomes', () async {
      for (final status in [403, 404, 409, 422]) {
        final session = await _session((_) async => _json({}, status));
        try {
          await BusinessRepository(ApiClient(session)).booking('b');
          fail('expected ApiException');
        } on ApiException catch (e) {
          expect(e.outcomeUnknown, isFalse, reason: '$status');
        }
      }
    });
  });

  group('multipart', () {
    test('sends fields, the image part and the Bearer token', () async {
      http.Request? seen;
      final session = await _session((request) async {
        seen = request;
        return _json({
          'data': {'guid': 'd1', 'name': 'Candi', 'image_url': 'destinations/d1/image?v=1'}
        }, 201);
      });
      final repository = BusinessRepository(ApiClient(session));
      final destination = await repository.createDestination(
          {'name': 'Candi', 'ticket_price': 1500, 'is_active': true},
          image: const UploadFile('image', [137, 80, 78, 71], 'candi.png'));
      expect(destination.guid, 'd1');
      expect(destination.imageUrl, 'destinations/d1/image?v=1');
      expect(seen!.method, 'POST');
      expect(seen!.url.path, endsWith('/destinations'));
      expect(seen!.headers['Authorization'], 'Bearer access-1');
      expect(seen!.headers['content-type'], startsWith('multipart/form-data'));
      final body = latin1.decode(seen!.bodyBytes);
      expect(body, contains('name="name"'));
      expect(body, contains('1500'));
      expect(body, contains('name="is_active"'));
      expect(body, contains('name="image"; filename="candi.png"'));
    });

    test('edit with an image spoofs PATCH through POST', () async {
      http.Request? seen;
      final session = await _session((request) async {
        seen = request;
        return _json({
          'data': {'guid': 'd1', 'name': 'Baru'}
        });
      });
      await BusinessRepository(ApiClient(session)).updateDestination(
          'd1', {'name': 'Baru'},
          image: const UploadFile('image', [1, 2, 3], 'a.jpg'));
      expect(seen!.method, 'POST');
      expect(seen!.url.path, endsWith('/destinations/d1'));
      expect(seen!.body, contains('name="_method"'));
      expect(seen!.body, contains('PATCH'));
    });

    test('a 401 refreshes once and rebuilds the multipart body', () async {
      final tokens = <String?>[];
      final bodies = <String>[];
      final session = await _session((request) async {
        tokens.add(request.headers['Authorization']);
        bodies.add(request.body);
        if (request.headers['Authorization'] == 'Bearer access-1') {
          return _json({}, 401);
        }
        return _json({
          'data': {'guid': 'd1', 'name': 'X'}
        });
      });
      await BusinessRepository(ApiClient(session)).uploadDestinationImage(
          'd1', const UploadFile('image', [9, 9, 9], 'x.png'));
      expect(tokens, ['Bearer access-1', 'Bearer access-2']);
      expect(bodies[0], contains('filename="x.png"'));
      expect(bodies[1], contains('filename="x.png"'));
    });

    test('a validation error from the upload surfaces its message', () async {
      final session = await _session((_) async => _json({
            'message': 'invalid',
            'errors': {
              'image': ['The image must not be greater than 5120 kilobytes.']
            }
          }, 422));
      try {
        await BusinessRepository(ApiClient(session))
            .uploadDestinationImage('d1', const UploadFile('image', [1], 'x.png'));
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.status, 422);
        expect(e.message, contains('5120'));
      }
    });
  });

  group('binary', () {
    test('document download is authenticated and returns the PDF bytes',
        () async {
      http.Request? seen;
      final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7 body'));
      final session = await _session((request) async {
        seen = request;
        return http.Response.bytes(pdf, 200,
            headers: {'content-type': 'application/pdf'});
      });
      final response = await BusinessRepository(ApiClient(session))
          .downloadDocument('b1', 'invoice');
      expect(seen!.url.path, endsWith('/bookings/b1/documents/invoice'));
      expect(seen!.headers['Authorization'], 'Bearer access-1');
      expect(response.contentType, 'application/pdf');
      expect(response.bytes, pdf);
    });

    test('public images send no Authorization header', () async {
      http.Request? seen;
      final session = await _session((request) async {
        seen = request;
        return http.Response.bytes([1, 2, 3], 200,
            headers: {'content-type': 'image/png'});
      });
      final response = await BusinessRepository(ApiClient(session))
          .imageBytes('destinations/d1/image?v=5');
      expect(seen!.headers.containsKey('Authorization'), isFalse);
      expect(seen!.url.queryParameters['v'], '5');
      expect(response.bytes, [1, 2, 3]);
    });

    test('a binary 404 is an error, not an empty file', () async {
      final session = await _session((_) async => _json({}, 404));
      expect(
          () => BusinessRepository(ApiClient(session))
              .downloadDocument('b1', 'ticket'),
          throwsA(isA<ApiException>()
              .having((e) => e.status, 'status', 404)));
    });

    test('a download finishing after logout is discarded', () async {
      final gate = Completer<void>();
      final session = await _session((request) async {
        await gate.future;
        return http.Response.bytes([1], 200,
            headers: {'content-type': 'application/pdf'});
      });
      final pending = BusinessRepository(ApiClient(session))
          .downloadDocument('b1', 'invoice');
      final captured = expectLater(
          pending,
          throwsA(isA<ApiException>()
              .having((e) => e.status, 'status', 401)));
      await session.clear();
      gate.complete();
      await captured;
    });
  });

  group('availability and reconciliation endpoints', () {
    test('availability uses the visit_date query and parses the status',
        () async {
      http.Request? seen;
      final session = await _session((request) async {
        seen = request;
        return _json({
          'data': [
            {
              'visit_date': '2026-11-20',
              'capacity': 10,
              'allocated': 4,
              'remaining': 6,
              'status': 'open',
              'booking_opens_at': '2026-11-01T00:00:00+00:00',
              'booking_closes_at': '2026-11-19T00:00:00+00:00',
              'timezone': 'Asia/Jakarta'
            }
          ]
        });
      }, role: 0);
      final items = await BusinessRepository(ApiClient(session))
          .availability('d1', visitDate: '2026-11-20');
      expect(seen!.url.path, endsWith('/destinations/d1/availability'));
      expect(seen!.url.queryParameters['visit_date'], '2026-11-20');
      expect(items.single.remaining, 6);
      expect(items.single.isOpen, isTrue);
    });

    test('intent reconciliation and abandon hit the booking-intents paths',
        () async {
      final calls = <String>[];
      final session = await _session((request) async {
        calls.add('${request.method} ${request.url.path}');
        return _json({
          'data': {
            'key': 'k',
            'state': request.method == 'POST' ? 'abandoned' : 'not_found',
            'replay_safe': request.method == 'GET',
            'key_expired': false,
            'expires_at': null,
            'booking': null
          }
        });
      }, role: 0);
      final repository = BusinessRepository(ApiClient(session));
      final state = await repository.bookingIntent('k');
      expect(state.state, 'not_found');
      expect(state.replaySafe, isTrue);
      expect((await repository.abandonBookingIntent('k')).state, 'abandoned');
      expect(calls, [
        'GET /api/v1/booking-intents/k',
        'POST /api/v1/booking-intents/k/abandon'
      ]);
    });
  });
}
