import 'package:flutter/material.dart';
import '../data/admin_state.dart' show formatDate;
import '../screens/auth_presentation.dart';
import '../theme/app_colors.dart';
import 'visit_format.dart' show visitMonths;

String operationsPeriodLabel(Map<String, String> filters,
    {bool includeYear = false}) {
  final from = DateTime.tryParse(filters['from'] ?? '');
  final to = DateTime.tryParse(filters['to'] ?? '');
  if (from == null || to == null) return 'Semua tanggal';
  final month = visitMonths[to.month - 1].substring(0, 3);
  if (from.year != to.year) return '${formatDate(from)}–${formatDate(to)}';
  final year = includeYear ? ' ${to.year}' : '';
  if (from.month != to.month) {
    return '${from.day} ${visitMonths[from.month - 1].substring(0, 3)}–${to.day} $month$year';
  }
  return from.day == to.day
      ? '${from.day} $month$year'
      : '${from.day}–${to.day} $month$year';
}

class OperationsFilterBar extends StatelessWidget {
  const OperationsFilterBar(
      {super.key,
      required this.filters,
      required this.keyPrefix,
      required this.dateTooltip,
      required this.onDestinationPressed,
      required this.onDatePressed,
      this.destinationLabel});
  final Map<String, String> filters;
  final String keyPrefix;
  final String dateTooltip;
  final String? destinationLabel;
  final VoidCallback? onDestinationPressed;
  final VoidCallback? onDatePressed;

  String get _dateLabel => operationsPeriodLabel(filters);

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            flex: 2,
            child: OutlinedButton(
                key: ValueKey('$keyPrefix-destination-filter'),
                onPressed: onDestinationPressed,
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    backgroundColor: AppColors.surface,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Row(children: [
                  const Icon(Icons.place_outlined,
                      size: 16, color: AppColors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          filters['destination_guid'] == null
                              ? 'Semua destinasi'
                              : destinationLabel ?? 'Destinasi terpilih',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600))),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: AppColors.blue),
                ]))),
        const SizedBox(width: 8),
        Expanded(
            child: Tooltip(
                message: dateTooltip,
                child: TextButton(
                    key: ValueKey('$keyPrefix-date-filter'),
                    onPressed: onDatePressed,
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.navy,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: AppColors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_dateLabel,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 12))),
                    ])))),
      ]);
}

/// Role-one routes share the visitor identity without changing the app theme.
class OperationsTheme extends StatelessWidget {
  const OperationsTheme({super.key, required this.child, required this.role});
  final Widget child;
  final int? role;

  @override
  Widget build(BuildContext context) =>
      role == 1 ? Theme(data: AppColors.operationsTheme, child: child) : child;
}

class OperationsScenicHeader extends StatelessWidget {
  const OperationsScenicHeader(
      {super.key,
      required this.title,
      required this.subtitle,
      this.onBack,
      this.actions = const []});
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => TimeBasedScenicBackground(
        child: SafeArea(
            bottom: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        if (onBack != null)
                          BackButton(color: Colors.white, onPressed: onBack)
                        else
                          const SizedBox(
                              height: 48,
                              child: Icon(Icons.landscape_outlined,
                                  color: Colors.white)),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text('Wisata Daerahku · Admin',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white))),
                        ...actions.map((action) => IconButtonTheme(
                            data: IconButtonThemeData(
                                style: IconButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(48, 48))),
                            child: action)),
                      ]),
                      const SizedBox(height: 12),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 24,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 13, height: 1.5, color: Colors.white)),
                    ]))),
      );
}
