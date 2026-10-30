import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisata_daerahku/data/app_data.dart';
import 'package:wisata_daerahku/data/booking_errors.dart';
import 'package:wisata_daerahku/data/booking_state.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/data/review_state.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'user_support.dart';

Map<String, dynamic> reviewJson({String guid = 'review-1'}) => {
      'guid': guid,
      'booking_guid': 'booking-1',
      'destination_guid': 'dest-1',
      'destination_name': 'Pantai Test',
      'rating': 4,
      'comment': 'Kunjungan menyenangkan',
      'created_at': '2027-03-10T05:00:00Z',
    };

Map<String, dynamic> visitBooking({bool checkedIn = false}) => {
      ...bookingJson(status: 'confirmed', cancellable: false),
      'can_check_in': !checkedIn,
      'can_review': checkedIn,
      'checked_in_at': checkedIn ? '2027-03-10T04:00:00Z' : null,
      'review': null,
    };

void main() {
  test('profile statistics use authenticated Laravel counts', () async {
    final session = await signedInSession((request) async {
      expect(request.url.path, '/api/v1/profile/statistics');
      expect(request.headers['authorization'], 'Bearer access');
      return jsonResponse({
        'data': {'bookings': 8, 'reviews': 2, 'visits': 3}
      });
    });
    final counts = await repositoryFor(session).profileStatistics();
    expect([counts.bookings, counts.reviews, counts.visits], [8, 2, 3]);
  });

  test('profile update applies server normalized name and phone', () async {
    final session = await signedInSession((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/v1/profile');
      expect(jsonDecode(request.body), {'name': 'Nama', 'phone': '08123'});
      return jsonResponse({
        'data': {
          'guid': 'user-1',
          'name': 'Nama Server',
          'phone': '08123',
          'email': 'u@example.test',
          'role': 0,
          'status': 'active'
        }
      });
    });
    await session.updateProfile('Nama', '08123');
    expect(currentUser?.id, 'user-1');
    expect(currentUser?.namaLengkap, 'Nama Server');
    expect(currentUser?.noTelepon, '08123');
  });

  test('pending profile response cannot restore identity during logout',
      () async {
    final patch = Completer<http.Response>();
    final logout = Completer<http.Response>();
    final session = await signedInSession((request) async {
      if (request.url.path.endsWith('/profile')) return patch.future;
      return logout.future;
    });
    final update = session.updateProfile('Stale', '08123');
    final updateCheck = expectLater(update, throwsA(isA<ApiException>()));
    final clearing = session.logout();
    expect(currentUser, isNull);
    patch.complete(jsonResponse({
      'data': {
        'guid': 'user-1',
        'name': 'Stale',
        'email': 'u@example.test',
        'role': 0,
        'status': 'active'
      }
    }));
    await updateCheck;
    expect(currentUser, isNull);
    logout.complete(jsonResponse({'data': {}}));
    await clearing;
  });

  test('profile counts response is rejected after account switch', () async {
    final pending = Completer<http.Response>();
    final session = await signedInSession((_) => pending.future);
    final request = repositoryFor(session).profileStatistics();
    final assertion = expectLater(request, throwsA(isA<ApiException>()));
    await session.clear();
    await session.login('u@example.test', 'password');
    pending.complete(jsonResponse({
      'data': {'bookings': 8, 'reviews': 2, 'visits': 3}
    }));
    await assertion;
  });

  test('public destination reviews omit booking identity and Bearer', () async {
    final session = await signedInSession((request) async {
      expect(request.url.path, '/api/v1/destinations/dest-1/reviews');
      expect(request.headers['authorization'], isNull);
      final review = reviewJson()..remove('booking_guid');
      return jsonResponse({
        'data': [review],
        'meta': {'last_page': 1}
      });
    });
    final reviews = await repositoryFor(session).destinationReviews('dest-1');
    expect(reviews.items.single.bookingGuid, '');
    expect(reviews.items.single.comment, 'Kunjungan menyenangkan');
  });

  test('own history loads all pages and deduplicates reviews', () async {
    final session = await signedInSession((request) async {
      expect(request.url.path, '/api/v1/reviews');
      expect(request.headers['authorization'], 'Bearer access');
      return jsonResponse({
        'data': [
          reviewJson(),
          if (request.url.queryParameters['page'] == '2')
            reviewJson(guid: 'review-2')
        ],
        'meta': {'last_page': 2}
      });
    });
    final reviews = await loadAllReviews(repositoryFor(session));
    expect(reviews.map((r) => r.guid), ['review-1', 'review-2']);
  });

  test('own review history cannot mix accounts while paging', () async {
    final pending = Completer<http.Response>();
    var requests = 0;
    final session = await signedInSession((request) async {
      requests++;
      if (requests == 1) {
        return jsonResponse({
          'data': [reviewJson()],
          'meta': {'last_page': 2}
        });
      }
      return pending.future;
    });
    final result = loadAllReviews(repositoryFor(session));
    final assertion = expectLater(result, throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);
    await session.clear();
    await session.login('u@example.test', 'password');
    pending.complete(jsonResponse({
      'data': [reviewJson(guid: 'other-account')],
      'meta': {'last_page': 2}
    }));
    await assertion;
  });

  test('destination rating uses only server average and count', () {
    final wisata = Wisata.fromDestination(Destination({
      'guid': 'dest-1',
      'name': 'Pantai',
      'rating_average': 4.25,
      'rating_count': 4
    }));
    expect(wisata.rating, 4.25);
    expect(wisata.ratingCount, 4);
    final empty = Wisata.fromDestination(Destination({
      'guid': 'dest-2',
      'name': 'Baru',
      'rating_average': null,
      'rating_count': 0
    }));
    expect(empty.ratingCount, 0);
    expect(empty.rating, 0);
  });

  test('check-in sends booking GUID once and adopts server response', () async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final session = await signedInSession((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/bookings/booking-1/check-in');
      return pending.future;
    });
    final state = BookingDetailController(
        repositoryFor(session), Booking(visitBooking()));
    final first = state.checkIn();
    expect(await state.checkIn(), isFalse);
    pending.complete(jsonResponse({'data': visitBooking(checkedIn: true)}));
    expect(await first, isTrue);
    expect(calls, 1);
    expect(state.booking.checkedInAt, isNotNull);
    expect(state.booking.canReview, isTrue);
    state.dispose();
  });

  test('awaiting_payment cannot be checked in or reviewed by UI gate',
      () async {
    var calls = 0;
    final session = await signedInSession((_) async {
      calls++;
      return jsonResponse({'data': {}});
    });
    final state = BookingDetailController(repositoryFor(session),
        Booking(bookingJson(status: 'awaiting_payment', cancellable: false)));
    expect(await state.checkIn(), isFalse);
    expect(await state.submitReview(4, 'Test'), isFalse);
    expect(calls, 0);
    state.dispose();
  });

  for (final kind in ['checkin', 'review']) {
    test('$kind ignores response during pending logout', () async {
      final pending = Completer<http.Response>();
      final logout = Completer<http.Response>();
      final session = await signedInSession((request) async {
        if (request.url.path.endsWith('/logout')) return logout.future;
        return pending.future;
      });
      final state = BookingDetailController(repositoryFor(session),
          Booking(visitBooking(checkedIn: kind == 'review')));
      final result =
          kind == 'review' ? state.submitReview(4, 'Test') : state.checkIn();
      final clearing = session.logout();
      pending.complete(jsonResponse({
        'data': kind == 'review' ? reviewJson() : visitBooking(checkedIn: true)
      }));
      expect(await result, isFalse);
      expect(state.booking.review, isNull);
      if (kind == 'checkin') expect(state.booking.checkedInAt, isNull);
      logout.complete(jsonResponse({'data': {}}));
      await clearing;
      state.dispose();
    });
  }

  test('review submits existing form fields with no Firebase ownership',
      () async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final session = await signedInSession((request) async {
      calls++;
      expect(request.url.path, '/api/v1/bookings/booking-1/review');
      expect(jsonDecode(request.body),
          {'rating': 4, 'comment': 'Kunjungan menyenangkan'});
      return pending.future;
    });
    final state = BookingDetailController(
        repositoryFor(session), Booking(visitBooking(checkedIn: true)));
    final submit = state.submitReview(4, 'Kunjungan menyenangkan');
    expect(await state.submitReview(4, 'Duplicate'), isFalse);
    pending.complete(jsonResponse({'data': reviewJson()}, 201));
    expect(await submit, isTrue);
    expect(calls, 1);
    expect(state.booking.canReview, isFalse);
    expect(state.booking.review?.guid, 'review-1');
    state.dispose();
  });

  for (final kind in ['checkin', 'review']) {
    test('$kind duplicate conflict reconciles with authoritative booking',
        () async {
      final session = await signedInSession((request) async {
        if (request.method == 'POST') {
          return jsonResponse({
            'message': 'Duplicate',
            'code': kind == 'review' ? 'review_duplicate' : 'check_in_duplicate'
          }, 409);
        }
        return jsonResponse({
          'data': {
            ...visitBooking(checkedIn: true),
            if (kind == 'review') 'review': reviewJson(),
            'can_review': false
          }
        });
      });
      final state = BookingDetailController(repositoryFor(session),
          Booking(visitBooking(checkedIn: kind == 'review')));
      expect(
          await (kind == 'review'
              ? state.submitReview(4, 'Test')
              : state.checkIn()),
          isFalse);
      expect(state.booking.checkedInAt, isNotNull);
      if (kind == 'review') expect(state.booking.review, isNotNull);
      expect(state.message, contains(kind == 'review' ? 'Ulasan' : 'check-in'));
      state.dispose();
    });
  }

  for (final code in [
    'check_in_duplicate',
    'check_in_not_eligible',
    'check_in_wrong_date',
    'review_duplicate',
    'review_not_eligible'
  ]) {
    test('maps $code to specific Indonesian domain message', () {
      expect(bookingErrorMessage(ApiException('English fallback', 409, code)),
          isNot('English fallback'));
    });
  }
}
