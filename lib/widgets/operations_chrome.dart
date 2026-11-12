import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../data/admin_state.dart' show formatDate;
import '../screens/auth/auth_presentation.dart';
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
                  const Icon(PhosphorIconsRegular.mapPin,
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
                  const Icon(PhosphorIconsRegular.caretDown,
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
                      const Icon(PhosphorIconsRegular.calendarBlank,
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
                              child: Icon(PhosphorIconsRegular.mountains,
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

/// Daylight scenic header shared by the Superadmin dashboard and its child
/// pages, so every operations route opens with the same hierarchy.
class OperationsDayHeader extends StatelessWidget {
  const OperationsDayHeader(
      {super.key,
      required this.label,
      required this.title,
      required this.subtitle,
      this.onBack,
      this.actions = const []});
  final String label;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => ClipRect(
      child: CustomPaint(
          painter: const _OperationsDayScenery(),
          child: SafeArea(
              bottom: false,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 38),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          if (onBack != null)
                            BackButton(color: Colors.white, onPressed: onBack)
                          else ...[
                            const Icon(PhosphorIconsRegular.mountains,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                              child: Text(label,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white))),
                          for (final action in actions)
                            IconButtonTheme(
                                data: IconButtonThemeData(
                                    style: IconButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(48, 48))),
                                child: action),
                        ]),
                        const SizedBox(height: 10),
                        Text(title,
                            style: const TextStyle(
                                fontSize: 24,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.6,
                                color: Colors.white)),
                        const SizedBox(height: 6),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: Color(0xFFE6F1FF))),
                      ])))));
}

class _OperationsDayScenery extends CustomPainter {
  const _OperationsDayScenery();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2491EF), AppColors.blue, AppColors.blueDeep],
              stops: [0, .52, 1]).createShader(Offset.zero & size));
    canvas.drawCircle(
        Offset(w * .96, 0),
        72,
        Paint()
          ..color = Colors.white.withValues(alpha: .15)
          ..style = PaintingStyle.stroke);
    final back = Path()
      ..moveTo(0, h)
      ..lineTo(0, h - 2)
      ..lineTo(w * .10, h - 18)
      ..lineTo(w * .18, h - 7)
      ..lineTo(w * .27, h - 26)
      ..lineTo(w * .40, h - 6)
      ..lineTo(w * .47, h - 16)
      ..lineTo(w * .60, h - 3)
      ..lineTo(w * .72, h - 30)
      ..lineTo(w * .81, h - 9)
      ..lineTo(w * .89, h - 23)
      ..lineTo(w, h - 4)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
        back, Paint()..color = const Color(0xFF76B3ED).withValues(alpha: .56));
    final front = Path()
      ..moveTo(0, h)
      ..lineTo(w * .16, h - 3)
      ..lineTo(w * .29, h - 10)
      ..lineTo(w * .40, h - 1)
      ..lineTo(w * .53, h - 16)
      ..lineTo(w * .62, h - 1)
      ..lineTo(w * .75, h - 7)
      ..lineTo(w * .83, h - 1)
      ..lineTo(w * .93, h - 11)
      ..lineTo(w, h - 2)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
        front, Paint()..color = const Color(0xFFAECDF2).withValues(alpha: .36));
  }

  @override
  bool shouldRepaint(_OperationsDayScenery oldDelegate) => false;
}
