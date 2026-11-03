import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/services/api_client.dart';
import 'package:wisata_daerahku/services/auth_session.dart';

import 'user_support.dart' show MemoryStore;

void main() {
  final fixturePath = Platform.environment['PHASE6_FIXTURE'];
  test('Phase6 Flutter repository talks to real Laravel and MySQL', () async {
    final fixture = jsonDecode(await File(fixturePath!).readAsString())
        as Map<String, dynamic>;
    final session = AuthSession(
      baseUrl: Platform.environment['PHASE6_BASE_URL']!,
      store: MemoryStore(),
    );
    addTearDown(session.client.close);
    final repository = BusinessRepository(ApiClient(session));
    final guid = fixture['booking_guid'] as String;
    final destination = fixture['destination_guid'] as String;
    await session.login(
        fixture['owner_email'] as String, fixture['password'] as String);
    await session.updateProfile('Flutter Live Profile', '0812999');
    final booking = await repository.booking(guid);
    expect(booking.status, 'confirmed');
    expect(booking.json['can_check_in'], isNot(true));
    final tickets = await repository.bookingTickets(guid);
    expect(tickets.tickets.length, booking.quantity);
    await expectLater(
        session.requestEnvelope('POST', 'bookings/$guid/check-in'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 410)));
    // This integration fixture must now be checked in by authorized scanner staff.
    expect(booking.canReview, isTrue,
        reason:
            'Prepare at least one ticket check-in through staff confirm first.');
    final review =
        await repository.createReview(guid, 4, 'Real HTTP integration fixture');
    expect(review.bookingGuid, guid);
    expect((await repository.reviews()).items.single.guid, review.guid);
    expect(
        (await repository.destinationReviews(destination)).items.single.rating,
        4);
    expect((await repository.destination(destination)).json['rating_count'], 1);
    expect(
        (await repository.profileStatistics()).json, containsPair('visits', 1));
    expect((await repository.booking(guid)).canReview, isFalse);
    expect((await repository.bookingDocuments(guid)).ticket, isNotNull);
    final pdf = await repository.downloadDocument(guid, 'ticket');
    expect(utf8.decode(pdf.bytes.take(4).toList()), '%PDF');
    await session.registerDevice('phase6-isolated-test-token');
    await session.unregisterDevice('phase6-isolated-test-token');
    await session.logout();
    await session.login(
        fixture['other_email'] as String, fixture['password'] as String);
    expect((await repository.profileStatistics()).json['visits'], 0);
    expect((await repository.reviews()).items, isEmpty);
    await expectLater(repository.booking(guid),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
    await expectLater(repository.downloadDocument(guid, 'ticket'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
    await session.logout();
  },
      skip: fixturePath == null
          ? 'Set PHASE6_FIXTURE and PHASE6_BASE_URL for the isolated real API suite.'
          : false);
}
