import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/data/admin_state.dart';
import 'package:wisata_daerahku/data/business_repository.dart';

void main() {
  final instant = DateTime.utc(2026, 11, 14, 5, 30);

  test('deadline is shown in the destination zone, not the device zone', () {
    expect(formatInstantInZone(instant, 'Asia/Jakarta'), contains('12.30 WIB'));
    expect(formatInstantInZone(instant, 'Asia/Makassar'), contains('13.30 WITA'));
    expect(formatInstantInZone(instant, 'Asia/Jayapura'), contains('14.30 WIT'));
  });

  test('an unknown or missing zone falls back to the device zone', () {
    expect(formatInstantInZone(instant, null), isNotEmpty);
    expect(destinationZoneOffset('Europe/Paris'), isNull);
  });

  test('a save that changed the zone reports the active bookings', () {
    final saved = Destination({
      'guid': 'd',
      'name': 'Pantai',
      'timezone': 'Asia/Makassar',
      'timezone_impact': {
        'previous_timezone': 'Asia/Jakarta',
        'timezone': 'Asia/Makassar',
        'active_bookings': 3
      },
    });
    expect(saved.timezoneImpactBookings, 3);
    expect(Destination({'guid': 'd', 'name': 'Pantai'}).timezoneImpactBookings, isNull);
  });
}
