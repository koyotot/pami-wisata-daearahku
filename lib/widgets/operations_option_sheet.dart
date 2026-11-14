import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../theme/app_colors.dart';

/// Bottom sheet that lets the user pick one of [options] (value → label).
/// Returns the chosen value, or null when dismissed.
Future<String?> showOperationsOptionSheet(
  BuildContext context, {
  required String title,
  required Map<String, String> options,
  required String selected,
  String keyPrefix = 'option',
}) =>
    showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (sheetContext) => SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy))),
                        IconButton(
                            tooltip: 'Tutup',
                            onPressed: () => Navigator.pop(sheetContext),
                            style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFEEF3FA),
                                foregroundColor: AppColors.textSecondary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            icon: const Icon(PhosphorIconsRegular.x, size: 18)),
                      ]),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),
                      for (final entry in options.entries)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                                color: selected == entry.key
                                    ? AppColors.blueTint
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                        color: selected == entry.key
                                            ? AppColors.blue
                                            : AppColors.border)),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                    key: ValueKey('$keyPrefix-${entry.key}'),
                                    onTap: () =>
                                        Navigator.pop(sheetContext, entry.key),
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 16),
                                        child: Row(children: [
                                          Expanded(
                                              child: Text(entry.value,
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          selected == entry.key
                                                              ? FontWeight.w800
                                                              : FontWeight.w600,
                                                      color: AppColors.navy))),
                                          if (selected == entry.key)
                                            const Icon(
                                                PhosphorIconsRegular.check,
                                                size: 20,
                                                color: AppColors.blue),
                                        ]))))),
                    ]))));
