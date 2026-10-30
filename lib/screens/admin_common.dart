// ============================================================
// lib/screens/admin_common.dart
// Shared pieces of the admin screens (same palette & header as the
// existing admin pages): page shell, filter chips, status views, dialogs.
// ============================================================
import 'package:flutter/material.dart';

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
  final String badge;
  final String title;
  final String subtitle;
  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const AdminPage({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.slivers,
    this.onRefresh,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bg,
      floatingActionButton: floatingActionButton,
      body: RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              expandedHeight: 210,
              floating: false,
              pinned: true,
              snap: false,
              backgroundColor: AdminColors.blueDeep,
              elevation: 0,
              leading: GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
              actions: actions,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2A93F0),
                        Color(0xFF1976D2),
                        Color(0xFF1558B0)
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 46,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.28)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AdminColors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    badge,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                height: 1.1,
                                shadows: [
                                  Shadow(
                                    color: Color(0x33000000),
                                    blurRadius: 12,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -1,
                        child: Container(
                          height: 26,
                          decoration: const BoxDecoration(
                            color: AdminColors.bg,
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(26)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ...slivers,
          ],
        ),
      ),
    );
  }
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

Widget adminLoadingSliver() => const SliverFillRemaining(
    hasScrollBody: false,
    child: Center(child: CircularProgressIndicator(color: AdminColors.blue)));

Widget adminErrorSliver(String message, VoidCallback onRetry) =>
    SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ]),
        ),
      ),
    );

Widget adminEmptySliver(IconData icon, String title, String subtitle) =>
    SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                  size: 42, color: AdminColors.blue.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 18),
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

void showAdminSnack(BuildContext context, String message, {bool error = false}) {
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
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    ),
  );
  return result == true;
}

InputDecoration adminInputDecoration(String label, {String? hint}) =>
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
