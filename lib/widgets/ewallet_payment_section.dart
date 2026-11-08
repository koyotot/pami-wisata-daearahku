import 'package:flutter/material.dart';
import '../data/business_repository.dart';
import '../data/ewallet_payment_state.dart';

/// DANA / ShopeePay entry beside the booking payment status. Opening a wallet is never proof of payment:
/// when the app comes back to the foreground it asks the server to re-check the unfinished attempt.
class EwalletPaymentSection extends StatefulWidget {
  const EwalletPaymentSection(
      {super.key,
      required this.booking,
      required this.repository,
      required this.onChanged,
      this.launcher});
  final Booking booking;
  final BusinessRepository repository;
  final Future<void> Function() onChanged;
  final WalletLauncher? launcher;
  @override
  State<EwalletPaymentSection> createState() => _EwalletPaymentSectionState();
}

class _EwalletPaymentSectionState extends State<EwalletPaymentSection> {
  late final EwalletPaymentState _payment = EwalletPaymentState(
      widget.repository, widget.booking.guid,
      launcher: widget.launcher);
  bool _wasConfirmed = false;

  @override
  void initState() {
    super.initState();
    _payment.addListener(_changed);
    _payment.recover();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (_payment.confirmed && !_wasConfirmed) {
      _wasConfirmed = true;
      widget.onChanged();
    }
  }

  @override
  void dispose() {
    _payment.removeListener(_changed);
    _payment.dispose();
    super.dispose();
  }

  String get _status => switch (_payment.phase) {
        EwalletPhase.confirmed =>
          'Pembayaran terkonfirmasi oleh server. Booking Anda sudah dikonfirmasi.',
        EwalletPhase.pending =>
          'Menunggu konfirmasi pembayaran dari penyedia. Menutup dompet digital belum berarti pembayaran berhasil.',
        EwalletPhase.unknown =>
          'Status pembayaran belum pasti. Periksa kembali; jangan membayar ulang.',
        EwalletPhase.failed =>
          'Pembayaran sebelumnya tidak berhasil. Anda dapat mencoba lagi.',
        EwalletPhase.expired =>
          'Pembayaran sebelumnya kedaluwarsa. Anda dapat mencoba lagi.',
        EwalletPhase.review =>
          'Pembayaran sedang ditinjau pengelola. Jangan membayar ulang.',
        EwalletPhase.otherMethod =>
          'Booking ini sudah memiliki pembayaran dengan metode lain.',
        EwalletPhase.idle => 'Pilih dompet digital untuk membayar.',
      };

  @override
  Widget build(BuildContext context) {
    final p = _payment;
    if (p.reconciled && p.channels.isEmpty && !p.isActive && !p.confirmed) {
      return const SizedBox.shrink();
    }
    return Column(
        key: const Key('ewallet-section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.busy) const LinearProgressIndicator(),
          Text(p.reconciled ? _status : 'Memeriksa pembayaran dompet digital…',
              key: const Key('ewallet-status'),
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: Color(0xFF526787))),
          if (p.error != null)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(p.error!,
                    key: const Key('ewallet-error'),
                    style: const TextStyle(
                        fontSize: 12, height: 1.5, color: Color(0xFFB3261E)))),
          if (p.canStart)
            for (final channel in p.channels)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ElevatedButton(
                      key: Key('ewallet-pay-$channel'),
                      onPressed: () => p.start(channel),
                      child: Text(
                          'Bayar dengan ${EwalletPaymentState.channelLabel(channel)}'))),
          if (p.phase == EwalletPhase.pending)
            TextButton(
                key: const Key('ewallet-reopen'),
                onPressed: p.busy ? null : p.reopen,
                child: const Text('Buka Dompet Digital')),
          if (p.isActive)
            TextButton(
                key: const Key('ewallet-refresh'),
                onPressed: p.busy ? null : p.refresh,
                child: const Text('Periksa Status Pembayaran')),
        ]);
  }
}
