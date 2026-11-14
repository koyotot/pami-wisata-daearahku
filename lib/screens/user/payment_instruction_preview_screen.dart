import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../theme/app_colors.dart';
import '../../widgets/payment_deadline.dart';
import '../auth/auth_presentation.dart';
import 'booking_payment_screen.dart' show DashedBorderPainter;

/// Preview of the payment-instruction page, shown when the real payment
/// instruction could not be created. Nothing here talks to the server: there is
/// no VA number or QR, and the countdown is a local simulation.
class PaymentInstructionPreviewScreen extends StatefulWidget {
  const PaymentInstructionPreviewScreen(
      {super.key,
      required this.methodTitle,
      required this.isQris,
      required this.totalLabel,
      this.failure});
  final String methodTitle;
  final bool isQris;
  final String totalLabel;

  /// Why the real instruction could not be created, when known.
  final String? failure;

  @override
  State<PaymentInstructionPreviewScreen> createState() =>
      _PaymentInstructionPreviewScreenState();
}

class _PaymentInstructionPreviewScreenState
    extends State<PaymentInstructionPreviewScreen> {
  static const _window = Duration(minutes: 15);
  late final DateTime _opened = DateTime.now();

  List<String> get _steps => widget.isQris
      ? const [
          'Buka aplikasi bank atau dompet digital yang mendukung QRIS.',
          'Pilih menu pindai QR, lalu arahkan ke kode QR pembayaran resmi.',
          'Periksa nama penerima dan nominal sebelum mengonfirmasi.',
        ]
      : [
          'Buka aplikasi perbankan atau ATM yang mendukung pembayaran '
              '${widget.methodTitle.split(' ').first}.',
          'Pilih menu pembayaran atau transfer Virtual Account yang sesuai.',
          'Masukkan nomor VA dari instruksi pembayaran resmi.',
          'Periksa nama penerima dan nominal sebelum mengonfirmasi.',
        ];

  Widget _panel(List<Widget> children) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children));

  Widget _caption(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
          color: AppColors.textMuted));

  Widget _note(String text, {required bool warning}) {
    final bg = warning ? const Color(0xFFFFF7E6) : const Color(0xFFEEF5FD);
    final border = warning ? const Color(0xFFF3DDAA) : const Color(0xFFC9DDF7);
    final fg = warning ? const Color(0xFF80531B) : AppColors.blueDeep;
    return Container(
        margin: const EdgeInsets.only(top: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(PhosphorIconsRegular.info, size: 18, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 12, height: 1.5, color: fg))),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.isQris
        ? PhosphorIconsRegular.qrCode
        : PhosphorIconsRegular.creditCard;
    return Theme(
        data: AppColors.visitorTheme,
        child: Scaffold(
            backgroundColor: AppColors.bg,
            bottomNavigationBar: Material(
                color: AppColors.surface,
                elevation: 8,
                shadowColor: Colors.black26,
                child: SafeArea(
                    top: false,
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total tagihan',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 2),
                              Text(widget.totalLabel,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy)),
                            ])))),
            body: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  TimeBasedScenicBackground(
                      active: true,
                      child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              AppSpacing.md,
                              MediaQuery.paddingOf(context).top + AppSpacing.sm,
                              20,
                              AppSpacing.xl),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(children: [
                                  BackButton(color: Colors.white),
                                  Expanded(
                                      child: Text('WISATA DAERAHKU',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white)))
                                ]),
                                const Padding(
                                    padding: EdgeInsets.only(
                                        left: AppSpacing.sm,
                                        top: AppSpacing.lg),
                                    child: Text('Instruksi Pembayaran',
                                        style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white))),
                                const Padding(
                                    padding: EdgeInsets.only(
                                        left: AppSpacing.sm, top: 6),
                                    child: Text(
                                        'Pratinjau instruksi metode yang dipilih',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white))),
                              ]))),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(
                          20, AppSpacing.lg + 2, 20, AppSpacing.xl + 4),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md),
                                child: PaymentDeadline(
                                    key: const Key('preview-countdown'),
                                    banner: true,
                                    label: 'Sisa waktu pembayaran',
                                    caption: 'Countdown simulasi',
                                    expiresAt: _opened.add(_window),
                                    now: DateTime.now,
                                    onElapsed: () {})),
                            _panel([
                              _caption('METODE YANG DIPILIH'),
                              const SizedBox(height: AppSpacing.md),
                              Row(children: [
                                Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                        color: AppColors.blueTint,
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    child: Icon(icon,
                                        size: 22, color: AppColors.blue)),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(widget.methodTitle,
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.navy)),
                                      const SizedBox(height: 2),
                                      const Text('Pratinjau langkah selanjutnya',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors.textSecondary)),
                                    ])),
                              ]),
                              const Divider(
                                  height: AppSpacing.xl + 4,
                                  color: AppColors.border),
                              const Text('Total tagihan',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: AppSpacing.xs),
                              Text(widget.totalLabel,
                                  style: const TextStyle(
                                      fontSize: 30,
                                      height: 1.1,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.blueDeep)),
                            ]),
                            _panel([
                              _caption('INSTRUKSI PEMBAYARAN'),
                              const SizedBox(height: AppSpacing.md),
                              CustomPaint(
                                  painter: const DashedBorderPainter(
                                      Color(0xFFB9D3F2)),
                                  child: Container(
                                      width: double.infinity,
                                      padding:
                                          const EdgeInsets.all(AppSpacing.xl),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFF5F9FE),
                                          borderRadius:
                                              BorderRadius.circular(18)),
                                      child: Column(children: [
                                        Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                                color: AppColors.blueTint,
                                                borderRadius:
                                                    BorderRadius.circular(14)),
                                            child: Icon(icon,
                                                size: 24,
                                                color: AppColors.blue)),
                                        const SizedBox(height: AppSpacing.md),
                                        Text(
                                            widget.isQris
                                                ? 'Kode QR belum diterbitkan'
                                                : 'Nomor VA belum diterbitkan',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.navy)),
                                        const SizedBox(height: AppSpacing.sm),
                                        Text(
                                            widget.isQris
                                                ? 'QR pembayaran asli hanya boleh ditampilkan dari respons penyedia pembayaran.'
                                                : 'Nomor Virtual Account asli hanya boleh ditampilkan dari respons penyedia pembayaran.',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                height: 1.5,
                                                color:
                                                    AppColors.textSecondary)),
                                      ]))),
                              const SizedBox(height: AppSpacing.lg),
                              const Text('Cara pembayaran',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy)),
                              const SizedBox(height: AppSpacing.md),
                              for (var i = 0; i < _steps.length; i++)
                                Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: AppSpacing.sm),
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                              width: AppSpacing.xl,
                                              child: Text('${i + 1}.',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppColors.navy))),
                                          Expanded(
                                              child: Text(_steps[i],
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      height: 1.5,
                                                      color: AppColors
                                                          .textSecondary))),
                                        ])),
                              if (widget.failure != null)
                                _note(
                                    'Pembayaran asli belum dapat dibuat: ${widget.failure}',
                                    warning: false),
                              _note(
                                  'Mode prototype. Belum ada transaksi, nomor VA, atau QRIS asli yang dibuat. Pembayaran tidak bisa dilakukan dari layar simulasi ini.',
                                  warning: true),
                            ]),
                            Center(
                                child: TextButton.icon(
                                    key: const Key('preview-switch'),
                                    onPressed: () => Navigator.maybePop(context),
                                    style: TextButton.styleFrom(
                                        minimumSize: const Size(48, 48),
                                        foregroundColor: AppColors.blue),
                                    icon: const Icon(
                                        PhosphorIconsRegular.arrowLeft,
                                        size: 16),
                                    label: const Text('Pilih Metode Lain',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800)))),
                          ])),
                ]))));
  }
}
