import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The inset two-tab control used by the operations home.
class OperationsHomeTabs extends StatelessWidget {
  const OperationsHomeTabs(
      {super.key, required this.personal, required this.onChanged});
  final bool personal;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
          color: AppColors.blueTint, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        for (final tab in [(false, 'Destinasi'), (true, 'Kinerja Saya')])
          Expanded(
              child: Semantics(
                  selected: personal == tab.$1,
                  child: TextButton(
                      key: ValueKey('home-tab-${tab.$1}'),
                      style: TextButton.styleFrom(
                          foregroundColor: personal == tab.$1
                              ? AppColors.blueDeep
                              : AppColors.textSecondary,
                          backgroundColor: personal == tab.$1
                              ? AppColors.surface
                              : Colors.transparent,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.md),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () => onChanged(tab.$1),
                      child: Text(tab.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700))))),
      ]));
}
