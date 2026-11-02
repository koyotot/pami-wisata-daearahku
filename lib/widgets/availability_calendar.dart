import 'package:flutter/material.dart';
import '../data/booking_state.dart';
import '../data/business_repository.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _zonesReady = false;

DateTime destinationCalendarNow(String timezone, {DateTime? instant}) {
  if (!_zonesReady) {
    tzdata.initializeTimeZones();
    _zonesReady = true;
  }
  try {
    return tz.TZDateTime.from(
        instant ?? DateTime.now(), tz.getLocation(timezone));
  } on tz.LocationNotFoundException {
    // shortcut: unknown IANA zones use device month; update zone data when backend adds zones.
    return instant ?? DateTime.now();
  }
}

String availabilityLevelLabel(String level) => switch (level) {
      'high' => 'Banyak tersedia',
      'medium' => 'Terbatas',
      'low' => 'Hampir penuh',
      _ => 'Tidak tersedia',
    };

class AvailabilityCalendar extends StatelessWidget {
  final DateTime month;
  final MonthlyAvailability? availability;
  final String? selectedDate;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<AvailabilityDay> onSelected;
  final bool enabled;
  const AvailabilityCalendar(
      {super.key,
      required this.month,
      required this.availability,
      required this.selectedDate,
      required this.onMonthChanged,
      required this.onSelected,
      this.enabled = true});

  Color _color(String level) => switch (level) {
        'high' => const Color(0xFF218348),
        'medium' => const Color(0xFF9B7400),
        'low' => const Color(0xFFC7353C),
        _ => const Color(0xFF728099),
      };

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final count = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1;
    return Column(children: [
      Row(children: [
        IconButton(
            tooltip: 'Bulan sebelumnya',
            onPressed: () =>
                onMonthChanged(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left)),
        Expanded(
            child: Text(
                '${month.year}-${month.month.toString().padLeft(2, '0')}',
                textAlign: TextAlign.center)),
        IconButton(
            tooltip: 'Bulan berikutnya',
            onPressed: () =>
                onMonthChanged(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right)),
      ]),
      Row(children: [
        for (final day in [
          'Sen',
          'Sel',
          'Rab',
          'Kam',
          'Jum',
          'Sab',
          'Min'
        ]) ...[
          if (day != 'Sen') const SizedBox(width: 4),
          Expanded(child: Text(day, textAlign: TextAlign.center)),
        ],
      ]),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, crossAxisSpacing: 4, mainAxisSpacing: 4),
        itemCount: offset + count,
        itemBuilder: (context, index) {
          if (index < offset) return const SizedBox.shrink();
          final date = formatVisitDate(
              DateTime(month.year, month.month, index - offset + 1));
          final day = availability?.onDate(date);
          final selectable = enabled && day?.bookable == true;
          final color = _color(day?.level ?? 'none');
          final label = day == null
              ? 'Belum dimuat'
              : '${availabilityStatusLabel(day.status)}, ${availabilityLevelLabel(day.level)}, sisa ${day.remaining ?? '—'}';
          return Semantics(
            label: '$date, $label',
            button: true,
            enabled: selectable,
            selected: selectedDate == date,
            child: Tooltip(
                message: '$date: $label',
                child: TextButton(
                  key: ValueKey('availability-$date'),
                  style: TextButton.styleFrom(
                      foregroundColor: color,
                      disabledForegroundColor: color,
                      backgroundColor: color.withValues(alpha: .09),
                      side: selectedDate == date
                          ? const BorderSide(color: Color(0xFF1976D2), width: 2)
                          : BorderSide.none,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero),
                  onPressed: selectable ? () => onSelected(day!) : null,
                  child: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        Center(
                            child: Text('${index - offset + 1}',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700))),
                        Positioned(
                          bottom: 4,
                          child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle)),
                        ),
                      ]),
                )),
          );
        },
      ),
      Wrap(
          spacing: 14,
          runSpacing: 6,
          children: ['high', 'medium', 'low', 'none']
              .map((level) => Text(availabilityLevelLabel(level),
                  style: TextStyle(color: _color(level), fontSize: 12)))
              .toList()),
      if (availability != null)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Zona waktu: ${availability!.timezone}',
                style: const TextStyle(fontSize: 12))),
    ]);
  }
}
