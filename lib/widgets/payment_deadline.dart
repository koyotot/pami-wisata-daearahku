import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A clock for display only. Reaching zero asks Laravel for status; never expires a booking.
class PaymentDeadline extends StatefulWidget {
  const PaymentDeadline(
      {super.key, required this.expiresAt, required this.onElapsed});
  final DateTime? expiresAt;
  final VoidCallback onElapsed;
  @override
  State<PaymentDeadline> createState() => _PaymentDeadlineState();
}

class _PaymentDeadlineState extends State<PaymentDeadline>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _elapsed = false;
  Duration get _remaining =>
      widget.expiresAt?.difference(DateTime.now()) ?? Duration.zero;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tick();
    });
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (widget.expiresAt != null && _remaining <= Duration.zero && !_elapsed) {
      _elapsed = true;
      widget.onElapsed();
    }
  }

  @override
  void didUpdateWidget(PaymentDeadline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) _elapsed = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _remaining.inSeconds.clamp(0, 999999999);
    String two(int n) => n.toString().padLeft(2, '0');
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFFFF3DC),
            borderRadius: BorderRadius.circular(12)),
        child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 6,
            children: [
              const Text('Batas pembayaran',
                  style: TextStyle(fontSize: 12, color: Color(0xFF80531B))),
              Text(
                  widget.expiresAt == null
                      ? 'Belum tersedia'
                      : seconds == 0
                          ? 'Waktu habis · periksa status'
                          : '${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ]));
  }
}
