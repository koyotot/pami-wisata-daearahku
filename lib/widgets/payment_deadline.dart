import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../theme/app_colors.dart';

/// A clock for display only. Reaching zero asks Laravel for status; never expires a booking.
class PaymentDeadline extends StatefulWidget {
  const PaymentDeadline(
      {super.key,
      required this.expiresAt,
      required this.onElapsed,
      this.label = 'Batas pembayaran',
      this.serverTime,
      this.now,
      this.banner = false,
      this.caption});
  final DateTime? expiresAt;
  final VoidCallback onElapsed;
  final String label;

  /// Larger card with an icon and a prominent clock; turns red at zero.
  final bool banner;

  /// Secondary line under [label] in banner mode.
  final String? caption;

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
    if (widget.banner) return _banner(seconds, two);
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

  Widget _banner(int seconds, String Function(int) two) {
    final unavailable = widget.expiresAt == null || _now == null;
    final expired = !unavailable && seconds == 0;
    final bg = expired ? const Color(0xFFFDECEC) : const Color(0xFFFFF7E6);
    final border = expired ? const Color(0xFFF3C9C9) : const Color(0xFFF3DDAA);
    final fg = expired ? const Color(0xFFB23B3B) : const Color(0xFF80531B);
    final clock = '${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .6),
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(PhosphorIconsRegular.clock, size: 22, color: fg)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(expired ? 'Waktu pembayaran habis' : widget.label,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
                const SizedBox(height: 2),
                Text(
                    expired
                        ? 'Waktu habis · periksa status'
                        : widget.caption ?? '',
                    style: TextStyle(
                        fontSize: 12, color: fg.withValues(alpha: .8))),
              ])),
          const SizedBox(width: 8),
          Text(unavailable ? 'Belum tersedia' : clock,
              style: TextStyle(
                  fontSize: unavailable ? 12 : 22,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]));
  }
}
