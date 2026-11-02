import 'package:flutter_test/flutter_test.dart';
import 'package:wisata_daerahku/data/business_repository.dart';

Map<String, dynamic> _day(String date,
        {num? capacity = 100,
        num? remaining = 70,
        num? percent = 70,
        String level = 'high',
        String status = 'available',
        bool bookable = true}) =>
    {
      'date': date,
      'capacity': capacity,
      'remaining': remaining,
      'remaining_percent': percent,
      'level': level,
      'status': status,
      'bookable': bookable,
    };

void main() {
  for (final item in [
    (2027, 2, 28),
    (2028, 2, 29),
    (2027, 4, 30),
    (2027, 12, 31)
  ]) {
    test(
        'monthly parser preserves all ${item.$3} dates and destination timezone',
        () {
      final month = '${item.$1}-${item.$2.toString().padLeft(2, '0')}';
      final data = MonthlyAvailability({
        'destination_guid': 'dest-1',
        'month': month,
        'timezone': 'Pacific/Kiritimati',
        'requested_quantity': 1,
        'dates': List.generate(
            item.$3,
            (index) =>
                _day('$month-${(index + 1).toString().padLeft(2, '0')}')),
      });
      expect(data.dates, hasLength(item.$3));
      expect(data.onDate('$month-01')!.date, '$month-01');
      expect(data.dates.last.date, '$month-${item.$3}');
      expect(data.timezone, 'Pacific/Kiritimati');
      expect(data.onDate('1900-01-01'), isNull);
    });
  }

  test('unconfigured nulls remain missing, numeric doubles are accepted', () {
    final unconfigured = AvailabilityDay(_day('2027-03-10',
        capacity: null,
        remaining: null,
        percent: null,
        level: 'none',
        status: 'unconfigured',
        bookable: false));
    expect(unconfigured.capacity, isNull);
    expect(unconfigured.remaining, isNull);
    expect(unconfigured.remainingPercent, isNull);
    expect(unconfigured.bookable, isFalse);
    final fractional = AvailabilityDay(_day('2027-03-11',
        capacity: 200.0, remaining: 69.0, percent: 34.5, level: 'low'));
    expect(fractional.capacity, 200);
    expect(fractional.remaining, 69);
    expect(fractional.remainingPercent, 34.5);
    expect(fractional.bookable, isTrue);
  });

  test('boundary levels are kept from server and do not gate bookability', () {
    for (final entry in [
      (60.01, 'high'),
      (60.0, 'medium'),
      (35.0, 'medium'),
      (34.99, 'low'),
      (0.01, 'low'),
    ]) {
      final day = AvailabilityDay(
          _day('2027-03-10', percent: entry.$1, level: entry.$2));
      expect(day.level, entry.$2);
      expect(day.remainingPercent, entry.$1);
      expect(day.bookable, isTrue,
          reason: 'low is selectable when server says available/bookable');
    }
  });

  for (final status in [
    'sold_out',
    'closed',
    'unconfigured',
    'unavailable',
    'insufficient_quantity',
    'future_unknown_status',
  ]) {
    test('$status remains distinct and cannot authorize a booking', () {
      final day =
          AvailabilityDay(_day('2027-03-10', status: status, bookable: false));
      expect(day.status, status);
      expect(day.bookable, isFalse);
    });
  }

  test('unknown status never becomes bookable even with inconsistent flag', () {
    final day = AvailabilityDay(_day('2027-03-10', status: 'unknown'));
    expect(day.bookable, isFalse);
  });

  test('explicit server refusal wins over high remaining capacity', () {
    final day = AvailabilityDay(_day('2027-03-10', bookable: false));
    expect(day.remaining, 70);
    expect(day.level, 'high');
    expect(day.bookable, isFalse);
  });
}
