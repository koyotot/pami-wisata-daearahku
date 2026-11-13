// ============================================================
// lib/screens/admin_common.dart
// Shared pieces of the admin screens (same palette & header as the
// existing admin pages): page shell, filter chips, status views, dialogs.
// ============================================================
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../services/auth_session.dart';
import '../../widgets/operations_chrome.dart';
import '../../widgets/scroll_aware_status_bar.dart';

class AdminColors {
  static const blue = Color(0xFF1976D2);
  static const blueDeep = Color(0xFF1558B0);
  static const navy = Color(0xFF102D59);
  static const orange = Color(0xFFFF9800);
  static const bg = Color(0xFFF5F8FD);
  static const card = Colors.white;
  static const tint = Color(0xFFE6F0FC);
  static const text = navy;
  static const textMuted = Color(0xFF728099);
  static const textDim = Color(0xFF9AA7BC);
  static const border = Color(0xFFDCE4F0);
  static const danger = Color(0xFFE5484D);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
}

/// Gradient header + scrolling body, matching the other admin pages.
class AdminPage extends StatelessWidget {
  final int? role;
  final String title;
  final String subtitle;
  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;
  final Widget? floatingActionButton;
  final Widget? bottomBar;
  final List<Widget>? actions;

  const AdminPage({
    super.key,
    this.role,
    required this.title,
    required this.subtitle,
    required this.slivers,
    this.onRefresh,
    this.floatingActionButton,
    this.bottomBar,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final currentRole = role ?? AuthSession.instance.role;
    void back() => Navigator.maybePop(context);
    return OperationsTheme(
        role: currentRole,
        child: ScrollAwareStatusBar(
          builder: (context, headerKey) => Scaffold(
            backgroundColor: AdminColors.bg,
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: bottomBar,
            body: RefreshIndicator(
              onRefresh: onRefresh ?? () async {},
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: KeyedSubtree(
                      key: headerKey,
                      child: currentRole == 1
                          ? OperationsScenicHeader(
                              title: title,
                              subtitle: subtitle,
                              onBack: back,
                              actions: actions ?? const [])
                          // Superadmin child pages share the dashboard header.
                          : OperationsDayHeader(
                              label: 'Wisata Daerahku · Operasional',
                              title: title,
                              subtitle: subtitle,
                              onBack: back,
                              actions: actions ?? const []),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  ...slivers,
                ],
              ),
            ),
          ),
        ));
  }
}

/// Sticky bottom bar: a short note on the left, the primary action on the right.
class AdminActionBar extends StatelessWidget {
  const AdminActionBar({
    super.key,
    required this.note,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.buttonKey,
  });
  final String note;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AdminColors.border)),
            boxShadow: [
              BoxShadow(
                  color: Color(0x14102D59),
                  blurRadius: 16,
                  offset: Offset(0, -4))
            ]),
        child: Row(children: [
          Expanded(
              child: Text(note,
                  style: const TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 11.5,
                      height: 1.4))),
          const SizedBox(width: 12),
          FilledButton.icon(
              key: buttonKey,
              style: FilledButton.styleFrom(
                  backgroundColor: AdminColors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  textStyle: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w800),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label)),
        ]),
      );
}

/// Horizontal single-choice chips (same look as the category chips).
class AdminFilterChips<T> extends StatelessWidget {
  final List<(String, T)> options;
  final T selected;
  final ValueChanged<T> onSelected;
  const AdminFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        itemCount: options.length,
        itemBuilder: (_, i) {
          final (label, value) = options[i];
          final sel = value == selected;
          return GestureDetector(
            key: ValueKey('chip-$label'),
            onTap: () => onSelected(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? AdminColors.blue : AdminColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel ? AdminColors.blue : AdminColors.border),
                boxShadow: sel
                    ? [
                        BoxShadow(
                            color: AdminColors.blue.withValues(alpha: 0.40),
                            blurRadius: 10,
                            offset: const Offset(0, 3))
                      ]
                    : [],
              ),
              child: Center(
                child: Text(label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : AdminColors.textMuted,
                    )),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Summary tile for the master-data screens: a big number over a short label,
/// optionally led by a coloured status dot.
class AdminStatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color? dotColor;
  const AdminStatCard(this.value, this.label, {super.key, this.dotColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
        decoration: BoxDecoration(
            color: AdminColors.card,
            border: Border.all(color: AdminColors.border),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: const TextStyle(
                  color: AdminColors.navy,
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Row(children: [
            if (dotColor != null) ...[
              Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AdminColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      );
}

/// Dashed rounded outline used behind empty states.
class AdminDashedBorderPainter extends CustomPainter {
  const AdminDashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC3D0E3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(18)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget adminLoadingSliver() => const SliverFillRemaining(
    hasScrollBody: false,
    child: Center(child: CircularProgressIndicator(color: AdminColors.blue)));

Widget adminErrorSliver(String message, VoidCallback onRetry, {int? role}) =>
    SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            if ((role ?? AuthSession.instance.role) != 1)
              TextButton(onPressed: onRetry, child: const Text('Coba lagi'))
            else
              const Text('Tarik turun untuk menyinkronkan data.'),
          ]),
        ),
      ),
    );

/// [bottomInset] keeps the message clear of a floating action button; when
/// the text is too tall for the remaining space the sliver scrolls instead.
Widget adminEmptySliver(IconData icon, String title, String subtitle,
        {double bottomInset = 0}) =>
    SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
        child: Center(
          child: Builder(builder: (context) {
            // Short screens with large text drop the decorative icon so the
            // message stays readable without scrolling.
            final media = MediaQuery.of(context);
            final compact = media.size.height / media.textScaler.scale(1) < 500;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact) ...[
                  Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: AdminColors.blue.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AdminColors.blue.withValues(alpha: 0.15),
                          width: 1.5),
                    ),
                    child: Icon(icon,
                        size: 42,
                        color: AdminColors.blue.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 18),
                ],
                Text(title,
                    style: const TextStyle(
                        color: AdminColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AdminColors.textMuted, fontSize: 13)),
              ],
            );
          }),
        ),
      ),
    );

/// Inline notice (error or info) shown above a list.
class AdminNotice extends StatelessWidget {
  final String message;
  final Color color;
  const AdminNotice(this.message, {super.key, this.color = AdminColors.danger});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Text(message,
            style: TextStyle(color: color, fontSize: 12.5, height: 1.4)),
      );
}

class AdminBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const AdminBadge(this.label, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

BoxDecoration adminCardDecoration() => BoxDecoration(
      color: AdminColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AdminColors.border),
      boxShadow: [
        BoxShadow(
          color: AdminColors.blue.withValues(alpha: 0.10),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );

void showAdminSnack(BuildContext context, String message,
    {bool error = false}) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AdminColors.danger : AdminColors.blueDeep,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Simple confirmation dialog; true only when the user confirms.
Future<bool> adminConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AdminColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(
              color: AdminColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
      content: Text(message,
          style: const TextStyle(
              color: AdminColors.textMuted, fontSize: 13, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal',
              style: TextStyle(color: AdminColors.textMuted, fontSize: 13)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: danger ? AdminColors.danger : AdminColors.blue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    ),
  );
  return result == true;
}

/// [label] null → no floating label (for fields with a label above them).
InputDecoration adminInputDecoration(String? label, {String? hint}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AdminColors.card,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AdminColors.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AdminColors.blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AdminColors.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AdminColors.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

/// Compact "⋮" row menu with Ubah + activate/deactivate, for master-data
/// lists. Item keys stay `edit-<id>` / `toggle-<id>`; the button is
/// `actions-<id>`.
class AdminRowMenu extends StatelessWidget {
  final String id;
  final bool active;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  const AdminRowMenu({
    super.key,
    required this.id,
    required this.active,
    required this.onEdit,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final toggleColor = active ? AdminColors.danger : AdminColors.success;
    Widget item(IconData icon, String label, Color color) => Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      color:
                          color == AdminColors.blue ? AdminColors.text : color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600))),
        ]);
    return PopupMenuButton<String>(
      key: ValueKey('actions-$id'),
      tooltip: 'Tindakan',
      icon: const Icon(PhosphorIconsBold.dotsThreeVertical,
          color: AdminColors.textMuted, size: 20),
      color: AdminColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AdminColors.border)),
      position: PopupMenuPosition.under,
      onSelected: (value) => value == 'edit' ? onEdit() : onToggle(),
      itemBuilder: (_) => [
        PopupMenuItem(
            key: ValueKey('edit-$id'),
            value: 'edit',
            child: item(
                PhosphorIconsRegular.pencilSimple, 'Ubah', AdminColors.blue)),
        PopupMenuItem(
            key: ValueKey('toggle-$id'),
            value: 'toggle',
            child: item(
                active
                    ? PhosphorIconsRegular.eyeSlash
                    : PhosphorIconsRegular.arrowCounterClockwise,
                active ? 'Nonaktifkan' : 'Aktifkan kembali',
                toggleColor)),
      ],
    );
  }
}
