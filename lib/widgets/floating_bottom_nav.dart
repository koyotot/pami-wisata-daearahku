import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../theme/app_colors.dart';

class FloatingBottomNav extends StatelessWidget {
  const FloatingBottomNav(
      {super.key,
      required this.index,
      required this.onSelected,
      this.unreadCount = 0,
      this.operationsRole});
  final int index;
  final ValueChanged<int> onSelected;
  final int unreadCount;
  final int? operationsRole;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x140F2D59),
                    blurRadius: 20,
                    offset: Offset(0, 5)),
              ]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Material(
                color: Colors.white.withValues(alpha: .94),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 5; i++)
                        Expanded(child: _tab(context, i)),
                    ]),
              ),
            ),
          ),
        ),
      );

  Widget _tab(BuildContext context, int tab) {
    final labels = operationsRole == 1
        ? ['Beranda', 'Booking', 'Scan QR', 'Destinasi', 'Profil']
        : operationsRole == 2
            ? ['Ringkasan', 'Operasi', 'Analitik', 'Kelola', 'Profil']
            : ['Beranda', 'Riwayat', 'Jelajah', 'Notifikasi', 'Profil'];
    final icons = switch (operationsRole) {
      1 => const [
          (PhosphorIconsRegular.house, PhosphorIconsFill.house),
          (PhosphorIconsRegular.ticket, PhosphorIconsFill.ticket),
          (PhosphorIconsRegular.qrCode, PhosphorIconsFill.qrCode),
          (PhosphorIconsRegular.mapPin, PhosphorIconsFill.mapPin),
          (PhosphorIconsRegular.userCircle, PhosphorIconsFill.userCircle),
        ],
      2 => const [
          (PhosphorIconsRegular.chartPie, PhosphorIconsFill.chartPie),
          (PhosphorIconsRegular.clipboardText, PhosphorIconsFill.clipboardText),
          (PhosphorIconsRegular.chartBar, PhosphorIconsFill.chartBar),
          (PhosphorIconsRegular.squaresFour, PhosphorIconsFill.squaresFour),
          (PhosphorIconsRegular.userCircle, PhosphorIconsFill.userCircle),
        ],
      _ => const [
          (PhosphorIconsRegular.house, PhosphorIconsFill.house),
          (PhosphorIconsRegular.ticket, PhosphorIconsFill.ticket),
          (PhosphorIconsRegular.compass, PhosphorIconsFill.compass),
          (PhosphorIconsRegular.bell, PhosphorIconsFill.bell),
          (PhosphorIconsRegular.userCircle, PhosphorIconsFill.userCircle),
        ],
    };
    final selected = index == tab;
    final center = tab == 2;
    return Semantics(
      selected: selected,
      button: true,
      onTap: () => onSelected(tab),
      label: operationsRole == null && tab == 3 && unreadCount > 0
          ? 'Notifikasi, $unreadCount belum dibaca'
          : labels[tab],
      excludeSemantics: true,
      child: Tooltip(
        message: labels[tab],
        child: InkWell(
          onTap: () => onSelected(tab),
          child: Padding(
            padding:
                EdgeInsets.fromLTRB(2, center ? 4 : 12, 2, center ? 20 : 12),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: center
                  ? BoxDecoration(
                      color: AppColors.blue,
                      border: Border.all(color: Colors.white, width: 2),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                          BoxShadow(
                              color: Color(0x331976D2),
                              blurRadius: 8,
                              offset: Offset(0, 3))
                        ])
                  : null,
              child: Stack(clipBehavior: Clip.none, children: [
                Icon(selected ? icons[tab].$2 : icons[tab].$1,
                    size: 26,
                    color: center
                        ? Colors.white
                        : selected
                            ? AppColors.blue
                            : const Color(0xFF6F8199)),
                if (operationsRole == null && tab == 3 && unreadCount > 0)
                  Positioned(
                    top: -5,
                    right: -7,
                    child: Container(
                      key: const ValueKey('notification-badge'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      decoration: BoxDecoration(
                          color: AppColors.orange,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(unreadCount > 99 ? '99+' : '$unreadCount',
                          textScaler: TextScaler.noScaling,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
