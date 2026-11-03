import 'package:flutter/material.dart';
import '../data/booking_state.dart';
import '../data/business_repository.dart';
import 'visit_format.dart';
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
  final bool navigationEnabled;
  final DateTime? earliestMonth;
  const AvailabilityCalendar(
      {super.key,
      required this.month,
      required this.availability,
      required this.selectedDate,
      required this.onMonthChanged,
      required this.onSelected,
      this.enabled = true,
      this.navigationEnabled = true,
      this.earliestMonth});

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
    final previous = DateTime(month.year, month.month - 1);
    final canPrevious = navigationEnabled &&
        (earliestMonth == null ||
            !previous
                .isBefore(DateTime(earliestMonth!.year, earliestMonth!.month)));
    return Column(children: [
      Row(children: [
        IconButton(
            tooltip: 'Bulan sebelumnya',
            onPressed: canPrevious ? () => onMonthChanged(previous) : null,
            icon: const Icon(Icons.chevron_left)),
        Expanded(
            child: Text(visitMonth(month),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF102D59),
                    fontSize: 15,
                    fontWeight: FontWeight.w800))),
        IconButton(
            tooltip: 'Bulan berikutnya',
            onPressed: navigationEnabled
                ? () => onMonthChanged(DateTime(month.year, month.month + 1))
                : null,
            icon: const Icon(Icons.chevron_right)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        for (final day in ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'])
          Expanded(
              child: Text(day,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)))
      ]),
      const SizedBox(height: 8),
      GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 4,
            mainAxisSpacing: 6,
            mainAxisExtent:
                58 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 2),
        itemCount: offset + count,
        itemBuilder: (context, index) {
          if (index < offset) return const SizedBox.shrink();
          final date = formatVisitDate(
              DateTime(month.year, month.month, index - offset + 1));
          final day = availability?.onDate(date);
          final selectable = enabled && day?.bookable == true;
          final selected = selectedDate == date;
          final available = day?.status == 'available';
          final color =
              available ? _color(day!.level) : const Color(0xFF64748B);
          final label = day == null
              ? 'Belum dimuat'
              : '${availabilityStatusLabel(day.status)}, ${availabilityLevelLabel(day.level)}, sisa ${day.remaining ?? '\u2014'} tiket';
          return Semantics(
              label: '$date, $label',
              button: true,
              enabled: selectable,
              selected: selected,
              child: Tooltip(
                  message: '$date: $label',
                  child: TextButton(
                    key: ValueKey('availability-$date'),
                    style: TextButton.styleFrom(
                        foregroundColor: color,
                        disabledForegroundColor: color,
                        backgroundColor: selected
                            ? const Color(0xFFE3F0FE)
                            : available
                                ? color.withValues(alpha: .07)
                                : const Color(0xFFF1F4F8),
                        side: selected
                            ? const BorderSide(
                                color: Color(0xFF1976D2), width: 2)
                            : BorderSide.none,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 1, vertical: 4)),
                    onPressed: selectable ? () => onSelected(day!) : null,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${index - offset + 1}',
                              style: TextStyle(
                                  color: selected
                                      ? const Color(0xFF1976D2)
                                      : color,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          if (day?.status == 'closed')
                            const Icon(Icons.lock_outline_rounded,
                                size: 12, color: Color(0xFF64748B))
                          else
                            Text(day?.remaining?.toString() ?? '\u2014',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: color, fontSize: 11)),
                        ]),
                  )));
        },
      ),
      const SizedBox(height: 12),
      const Text(
          'Angka kecil menunjukkan sisa tiket. Tahan tanggal untuk rincian.',
          style:
              TextStyle(color: Color(0xFF64748B), fontSize: 11, height: 1.5)),
      const SizedBox(height: 10),
      Wrap(
          spacing: 12,
          runSpacing: 8,
          children: ['high', 'medium', 'low', 'none']
              .map((level) => Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: _color(level), shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(
                        level == 'none'
                            ? 'Tutup / habis / belum tersedia'
                            : availabilityLevelLabel(level),
                        style: TextStyle(color: _color(level), fontSize: 11))
                  ]))
              .toList()),
      if (availability != null)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('Zona waktu: ${availability!.timezone}',
                style:
                    const TextStyle(color: Color(0xFF64748B), fontSize: 11))),
    ]);
  }
}
