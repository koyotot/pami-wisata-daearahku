import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:wisata_daerahku/data/business_repository.dart';
import 'package:wisata_daerahku/widgets/availability_calendar.dart';
import 'package:wisata_daerahku/widgets/international_phone_field.dart';

void main() {
  testWidgets(
      'calendar stays readable on narrow scaled viewport with semantics',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final data = MonthlyAvailability({
      'destination_guid': 'dest',
      'month': '2027-03',
      'timezone': 'Asia/Jakarta',
      'requested_quantity': 1,
      'dates': [
        {
          'date': '2027-03-10',
          'capacity': 100,
          'remaining': 1,
          'remaining_percent': 1,
          'level': 'low',
          'status': 'available',
          'bookable': true,
        }
      ],
    });
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: AvailabilityCalendar(
              month: DateTime(2027, 3),
              availability: data,
              selectedDate: '2027-03-10',
              onMonthChanged: (_) {},
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    ));
    expect(find.bySemanticsLabel(RegExp('2027-03-10, Tersedia, Hampir penuh')),
        findsOneWidget);
    final selected = tester.widget<TextButton>(
        find.byKey(const ValueKey('availability-2027-03-10')));
    expect(
        selected.style!.foregroundColor!.resolve({}), const Color(0xFFC7353C));
    expect(selected.style!.side!.resolve({})!.color, const Color(0xFF1976D2));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  test('initial viewport uses destination IANA calendar at month boundary', () {
    final instant = DateTime.utc(2026, 10, 31, 12);
    final east = destinationCalendarNow('Pacific/Kiritimati', instant: instant);
    final west =
        destinationCalendarNow('America/Los_Angeles', instant: instant);
    expect(east.month, 11);
    expect(west.month, 10);
  });
  test('phone metadata converts national, international paste and US numbers',
      () {
    expect(parseBookingPhone('089655862781', IsoCode.ID)?.international,
        '+6289655862781');
    expect(parseBookingPhone('+1 (202) 555-0119', IsoCode.ID)?.isoCode,
        IsoCode.US);
    expect(parseBookingPhone('2025550119', IsoCode.US)?.international,
        '+12025550119');
    expect(parseBookingPhone('123', IsoCode.ID), isNull);
    expect(parseBookingPhone('', IsoCode.ID), isNull);
  });

  testWidgets('country selector defaults +62 and displays metadata formatting',
      (tester) async {
    final controller = TextEditingController(text: '+12025550119');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: InternationalPhoneField(
      controller: controller,
      country: IsoCode.ID,
      onCountryChanged: (_) {},
      onChanged: () {},
    ))));
    expect(find.text('+62'), findsOneWidget);
    expect(find.byKey(const ValueKey('countryFlag-ID')), findsOneWidget);
    expect(find.text('+1 202-555-0119'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('phoneCountryPicker')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('countrySearch')), 'United States');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'United States'), findsOneWidget);
    expect(find.byKey(const ValueKey('countryFlag-US')), findsOneWidget);
    // Dial code sits at the row's trailing edge.
    expect(
        find.descendant(
            of: find.widgetWithText(ListTile, 'United States'),
            matching: find.text('+1')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('national input formats using selected country metadata',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: InternationalPhoneField(
      controller: controller,
      country: IsoCode.US,
      onCountryChanged: (_) {},
      onChanged: () {},
    ))));
    await tester.enterText(find.byKey(const ValueKey('bookingPhone')), '20255');
    await tester.pump();
    expect(controller.text, '202-55');
    await tester.enterText(
        find.byKey(const ValueKey('bookingPhone')), '2025550119');
    await tester.pump();
    expect(controller.text, '202-555-0119');
    expect(parseBookingPhone(controller.text, IsoCode.US)?.international,
        '+12025550119');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'country search remains usable above keyboard at large text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!),
      home: Scaffold(
        body: InternationalPhoneField(
          controller: controller,
          country: IsoCode.JP,
          onCountryChanged: (_) {},
          onChanged: () {},
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('countryFlag-JP')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('phoneCountryPicker')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('countrySearch')), 'Japan');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Japan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final month in [
    (2028, 2, 29),
    (2027, 2, 28),
    (2027, 4, 30),
    (2027, 12, 31)
  ]) {
    testWidgets('calendar renders ${month.$3} dates without local date cutoff',
        (tester) async {
      final key = '${month.$1}-${month.$2.toString().padLeft(2, '0')}';
      String? picked;
      final data = MonthlyAvailability({
        'destination_guid': 'dest',
        'month': key,
        'timezone': 'Pacific/Kiritimati',
        'requested_quantity': 1,
        'dates': List.generate(
            month.$3,
            (i) => {
                  'date': '$key-${(i + 1).toString().padLeft(2, '0')}',
                  'capacity': 100,
                  'remaining': i == 0 ? 1 : 0,
                  'remaining_percent': i == 0 ? 1 : null,
                  'level': i == 0 ? 'low' : 'none',
                  'status': i == 0 ? 'available' : 'sold_out',
                  'bookable': i == 0,
                }),
      });
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: AvailabilityCalendar(
        month: DateTime(month.$1, month.$2),
        availability: data,
        selectedDate: null,
        onMonthChanged: (_) {},
        onSelected: (day) => picked = day.date,
      )))));
      expect(find.byType(TextButton), findsNWidgets(month.$3));
      final low = find.byKey(ValueKey('availability-$key-01'));
      await tester.tap(low);
      expect(picked, '$key-01');
      expect(
          tester
              .widget<TextButton>(find.byKey(ValueKey('availability-$key-02')))
              .onPressed,
          isNull);
      expect(find.text('Zona waktu: Pacific/Kiritimati'), findsOneWidget);
    });
  }
}
