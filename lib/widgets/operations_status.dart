import 'package:flutter/material.dart';

/// Status palette shared by operational badges and notice cards.
enum OperationsTone { orange, blue, red, grey, green }

({Color bg, Color border, Color fg}) operationsToneColors(
        OperationsTone tone) =>
    switch (tone) {
      OperationsTone.orange => (
          bg: const Color(0xFFFFF4DD),
          border: const Color(0xFFF3DDAA),
          fg: const Color(0xFF8A5A12)
        ),
      OperationsTone.blue => (
          bg: const Color(0xFFE8F1FD),
          border: const Color(0xFFC9DDF7),
          fg: const Color(0xFF1558B0)
        ),
      OperationsTone.red => (
          bg: const Color(0xFFFDECEC),
          border: const Color(0xFFF3C9C9),
          fg: const Color(0xFFB23B3B)
        ),
      OperationsTone.green => (
          bg: const Color(0xFFE6F6EC),
          border: const Color(0xFFBFE5CC),
          fg: const Color(0xFF1E7A45)
        ),
      OperationsTone.grey => (
          bg: const Color(0xFFEEF1F6),
          border: const Color(0xFFD5DBE6),
          fg: const Color(0xFF526787)
        ),
    };

/// Pill badge with a leading dot (omitted when [small]).
class OperationsStatusBadge extends StatelessWidget {
  const OperationsStatusBadge(this.label, this.tone,
      {super.key, this.small = false});
  final String label;
  final OperationsTone tone;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = operationsToneColors(tone);
    return Container(
        padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 12, vertical: small ? 5 : 7),
        decoration: BoxDecoration(
            color: c.bg,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!small) ...[
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: small ? 11 : 12,
                  fontWeight: FontWeight.w800,
                  color: c.fg)),
        ]));
  }
}
