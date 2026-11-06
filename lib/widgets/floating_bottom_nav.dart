import 'dart:ui';
import 'package:flutter/material.dart';
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
                CustomPaint(
                    size: const Size.square(26),
                    painter: operationsRole == null
                        ? _NavIconPainter(tab, selected)
                        : _OperationsIconPainter(
                            tab, selected, operationsRole!)),
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

class _OperationsIconPainter extends CustomPainter {
  const _OperationsIconPainter(this.tab, this.selected, this.role);
  final int tab;
  final bool selected;
  final int role;

  @override
  void paint(Canvas canvas, Size size) {
    if (tab == 0 || tab == 1 || tab == 4) {
      _NavIconPainter(tab, selected).paint(canvas, size);
      return;
    }
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = tab == 2 ? Colors.white : const Color(0xFF6F8199)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    if (tab == 2 && role == 1) {
      for (final origin in [
        const Offset(3, 3),
        const Offset(15, 3),
        const Offset(3, 15)
      ]) {
        path.addRRect(RRect.fromRectAndRadius(
            origin & const Size(6, 6), const Radius.circular(1)));
      }
      path
        ..moveTo(15, 15)
        ..lineTo(18, 15)
        ..lineTo(18, 18)
        ..lineTo(21, 18)
        ..lineTo(21, 21)
        ..moveTo(15, 21)
        ..lineTo(15, 18);
    } else if (tab == 2) {
      path
        ..moveTo(3, 3)
        ..lineTo(3, 21)
        ..lineTo(21, 21)
        ..moveTo(7, 17)
        ..lineTo(7, 12)
        ..moveTo(12, 17)
        ..lineTo(12, 7)
        ..moveTo(17, 17)
        ..lineTo(17, 3);
    } else if (role == 1) {
      path
        ..moveTo(3, 20)
        ..lineTo(8, 6)
        ..lineTo(14, 16)
        ..lineTo(18, 10)
        ..lineTo(22, 20)
        ..close();
    } else {
      for (final origin in [
        const Offset(3, 3),
        const Offset(14, 3),
        const Offset(3, 14),
        const Offset(14, 14)
      ]) {
        path.addRRect(RRect.fromRectAndRadius(
            origin & const Size(7, 7), const Radius.circular(1.5)));
      }
    }
    if (selected && tab == 3) {
      canvas.drawPath(
          path, Paint()..color = AppColors.blue.withValues(alpha: .18));
      stroke.color = AppColors.blue;
    }
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_OperationsIconPainter oldDelegate) =>
      tab != oldDelegate.tab ||
      selected != oldDelegate.selected ||
      role != oldDelegate.role;
}

class _NavIconPainter extends CustomPainter {
  const _NavIconPainter(this.tab, this.selected);
  final int tab;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final outline = Paint()
      ..color = tab == 2 ? Colors.white : const Color(0xFF6F8199)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final shape = Path();
    final detail = Path();
    switch (tab) {
      case 0:
        shape
          ..moveTo(3, 10)
          ..lineTo(12, 3)
          ..lineTo(21, 10)
          ..lineTo(21, 21)
          ..lineTo(3, 21)
          ..close();
        detail
          ..moveTo(9, 21)
          ..lineTo(9, 14)
          ..lineTo(15, 14)
          ..lineTo(15, 21);
      case 1:
        shape
          ..moveTo(3, 5)
          ..lineTo(21, 5)
          ..lineTo(21, 9)
          ..cubicTo(17, 9, 17, 15, 21, 15)
          ..lineTo(21, 19)
          ..lineTo(3, 19)
          ..lineTo(3, 15)
          ..cubicTo(7, 15, 7, 9, 3, 9)
          ..close();
        detail
          ..moveTo(14, 8)
          ..lineTo(14, 10)
          ..moveTo(14, 14)
          ..lineTo(14, 16);
      case 2:
        if (!selected) {
          canvas.drawCircle(const Offset(12, 12), 9, outline);
        }
        shape
          ..moveTo(16, 8)
          ..lineTo(14, 14)
          ..lineTo(8, 16)
          ..lineTo(10, 10)
          ..close();
      case 3:
        shape
          ..moveTo(5, 17)
          ..quadraticBezierTo(7, 14, 7, 10)
          ..cubicTo(7, 3, 17, 3, 17, 10)
          ..quadraticBezierTo(17, 14, 19, 17)
          ..close();
        detail
          ..moveTo(10, 21)
          ..quadraticBezierTo(12, 23, 14, 21);
      case 4:
        shape
          ..addOval(const Rect.fromLTWH(8, 3, 8, 8))
          ..moveTo(4, 21)
          ..cubicTo(4, 12, 20, 12, 20, 21)
          ..close();
    }
    if (selected) {
      canvas.drawPath(
          shape, Paint()..color = tab == 2 ? Colors.white : AppColors.blue);
    } else {
      canvas.drawPath(shape, outline);
      canvas.drawPath(detail, outline);
    }
  }

  @override
  bool shouldRepaint(_NavIconPainter oldDelegate) =>
      tab != oldDelegate.tab || selected != oldDelegate.selected;
}
