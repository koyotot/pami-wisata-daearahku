import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A clock for display only. Reaching zero asks Laravel for status; never expires a booking.
class PaymentDeadline extends StatefulWidget {
  const PaymentDeadline(
      {super.key,
      required this.expiresAt,
      required this.onElapsed,
      this.label = 'Batas pembayaran',
      this.serverTime,
      this.now});
  final DateTime? expiresAt;
  final VoidCallback onElapsed;
  final String label;

  final DateTime? serverTime;

  /// Authoritative clock, or server timestamp plus monotonic elapsed time. Never falls back to device time.
  final DateTime? Function()? now;
  @override
  State<PaymentDeadline> createState() => _PaymentDeadlineState();
}

class _PaymentDeadlineState extends State<PaymentDeadline>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _elapsed = false;
  final Stopwatch _clock = Stopwatch()..start();
  DateTime? get _now => widget.now != null
      ? widget.now!()
      : widget.serverTime?.add(_clock.elapsed);
  Duration get _remaining {
    final current = _now;
    return current != null
        ? widget.expiresAt?.difference(current) ?? Duration.zero
        : Duration.zero;
  }

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
    if (_now != null &&
        widget.expiresAt != null &&
        _remaining <= Duration.zero &&
        !_elapsed) {
      _elapsed = true;
      widget.onElapsed();
    }
  }

  @override
  void didUpdateWidget(PaymentDeadline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) _elapsed = false;
    if (oldWidget.serverTime != widget.serverTime) {
      _clock.reset();
      _elapsed = false;
    }
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
              Text(widget.label,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF80531B))),
              Text(
                  widget.expiresAt == null || _now == null
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
