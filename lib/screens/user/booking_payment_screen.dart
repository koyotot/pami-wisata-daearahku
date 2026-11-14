import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../data/booking_payment_state.dart';
import '../../data/booking_state.dart';
import '../../data/business_repository.dart';
import '../../data/payment_models.dart';
import '../../services/payment_qr_export.dart';
import '../../theme/app_colors.dart';
import '../../widgets/availability_calendar.dart' show destinationCalendarNow;
import '../../widgets/booking_refund_section.dart';
import '../../widgets/booking_ticket_qr_section.dart';
import '../../widgets/payment_deadline.dart';
import '../auth/auth_presentation.dart';
import 'payment_instruction_preview_screen.dart';

/// When the real payment instruction cannot be created, open a preview of the
/// instruction page (no VA number or QR, local countdown) instead of leaving
/// the customer on the chooser. Set to false to show only the error.
const kPaymentPreviewOnFailure = true;

/// Native checkout for BCA/BNI virtual accounts and QRIS. Amounts, currency, deadlines and availability all
/// come from Laravel; this page only sends the chosen method and channel, on an explicit tap.
class BookingPaymentScreen extends StatefulWidget {
  const BookingPaymentScreen(
      {super.key,
      required this.bookingGuid,
      required this.repository,
      this.exporter,
      this.documentSaver,
      this.now,
      this.elapsed,
      this.jitter,
      this.storage});
  final String bookingGuid;
  final BusinessRepository repository;
  final PaymentQrExporter? exporter;
  final DocumentSaver? documentSaver;
  final DateTime Function()? now;
  final Duration Function()? elapsed;
  final double Function()? jitter;
  final FlutterSecureStorage? storage;

  @override
  State<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends State<BookingPaymentScreen> {
  late final BookingPaymentState _payment = BookingPaymentState(
      widget.repository, widget.bookingGuid,
      storage: widget.storage,
      now: widget.now,
      elapsed: widget.elapsed,
      jitter: widget.jitter);
  late final PaymentQrExporter _exporter =
      widget.exporter ?? PlatformPaymentQrExporter();
  PayChoice? _selected;
  String? _feedback;
  bool _exporting = false;
  bool _showTickets = false;
  bool _routeVisible = true;
  bool _detail = false;

  /// True while one of this page's own bottom sheets is open. A sheet sits on
  /// top of the page but does not hide it, so the payment window must not
  /// pause (pausing clears the server clock and blocks the create).
  bool _ownSheet = false;

  @override
  void initState() {
    super.initState();
    _payment.addListener(_changed);
    _payment.open();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = _ownSheet || (ModalRoute.isCurrentOf(context) ?? true);
    if (visible != _routeVisible) {
      _routeVisible = visible;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _payment.routeVisible = visible;
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _payment.removeListener(_changed);
    _payment.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────

  PayChoice? get _effectiveChoice {
    final locked = _payment.lockedChoiceKey;
    final choices = _payment.snapshot?.payChoices ?? const <PayChoice>[];
    if (locked != null) {
      for (final choice in choices) {
        if (choice.key == locked) return choice;
      }
    }
    for (final choice in choices) {
      if (choice.key == _selected?.key) return choice;
    }
    return null;
  }

  Future<void> _start() async {
    final choice = _effectiveChoice;
    if (choice == null || !_payment.canStartWith(choice)) return;
    await _payment.start(choice);
    if (!mounted) return;
    final p = _payment;
    final snapshot = p.snapshot;
    // Success shows the real VA/QR inline (phase awaiting). The preview is only
    // a fallback when the server refused to create the instruction.
    if (kPaymentPreviewOnFailure &&
        p.phase != PaymentPhase.awaiting &&
        p.error != null &&
        snapshot != null &&
        p.booking != null) {
      final total = snapshot.totalAmount;
      final currency =
          (snapshot.json['currency'] as String?) ?? p.booking!.currency;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => PaymentInstructionPreviewScreen(
              methodTitle: _choiceTitle(choice),
              isQris: choice.methodCode == 'qris',
              totalLabel: total == null
                  ? 'Belum tersedia'
                  : formatMoney(total, currency),
              failure: p.error)));
    }
  }

  Future<void> _copyVa(String digits) async {
    await Clipboard.setData(ClipboardData(text: digits));
    if (!mounted) return;
    setState(
        () => _feedback = 'Nomor VA disalin. Tempel di aplikasi bank Anda.');
  }

  Future<void> _export({required bool save}) async {
    final png = _payment.qrPng;
    if (png == null ||
        !_payment.windowOpen ||
        _payment.phase != PaymentPhase.awaiting ||
        _exporting) {
      return;
    }
    setState(() {
      _exporting = true;
      _feedback = null;
    });
    PaymentQrExportResult result;
    try {
      final validFor =
          _payment.paymentDeadline!.difference(_payment.serverNow!);
      final name = paymentQrFileName(_payment.booking?.bookingNumber ?? '');
      result = save
          ? await _exporter.save(png, fileName: name, validFor: validFor)
          : await _exporter.share(png, fileName: name, validFor: validFor);
    } catch (_) {
      result = PaymentQrExportResult.failed;
    }
    if (!mounted) return;
    setState(() {
      _exporting = false;
      _feedback = paymentQrExportMessage(result, saving: save);
    });
  }

  Future<void> _downloadReceipt() async {
    final saved = await _payment
        .downloadReceipt(widget.documentSaver ?? saveBookingDocument);
    if (!mounted) return;
    setState(() => _feedback = saved != null
        ? 'Bukti pembayaran diambil dan disimpan sementara di ${saved.path}. '
            'Aplikasi ini belum memiliki pembaca PDF; buka file tersebut dengan aplikasi lain.'
        : _payment.notice);
  }

  // ── Presentation helpers ───────────────────────────────────

  String _title(PaymentPhase phase) => switch (phase) {
        PaymentPhase.choose => 'Pilih Metode Pembayaran',
        PaymentPhase.awaiting => 'Menunggu Pembayaran',
        PaymentPhase.verifying => 'Memverifikasi Pembayaran',
        PaymentPhase.review => 'Pembayaran Ditinjau',
        PaymentPhase.failed => 'Pembayaran Gagal',
        PaymentPhase.expired => 'Pembayaran Kedaluwarsa',
        PaymentPhase.cancelled => 'Pembayaran Dibatalkan',
        PaymentPhase.adjusted => 'Penyesuaian Pembayaran',
        PaymentPhase.paid => 'Pembayaran Berhasil',
        _ => 'Pembayaran Booking',
      };

  Widget _panel(List<Widget> children, {Key? key}) => Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children));

  Widget _line(String label, String value, {Key? key}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary))),
        const SizedBox(width: AppSpacing.md),
        Flexible(
            child: Text(value,
                key: key,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700))),
      ]));

  Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.navy)));

  Widget _body(String text, {Color color = AppColors.textSecondary}) =>
      Text(text, style: TextStyle(fontSize: 13, height: 1.5, color: color));

  Widget _button(String text, VoidCallback? onPressed,
          {Key? key, bool primary = true, IconData? icon}) =>
      Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: SizedBox(
              width: double.infinity,
              child: primary
                  ? ElevatedButton(
                      key: key, onPressed: onPressed, child: Text(text))
                  : OutlinedButton(
                      key: key,
                      style: OutlinedButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(kMinInteractiveDimension),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      onPressed: onPressed,
                      child: icon == null
                          ? Text(text, textAlign: TextAlign.center)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  Icon(icon, size: 18),
                                  const SizedBox(width: AppSpacing.sm),
                                  Flexible(
                                      child: Text(text,
                                          textAlign: TextAlign.center)),
                                ]))));

  Widget _statePanel(IconData icon, String title, String text, Color color,
          {Key? key, List<Widget> actions = const []}) =>
      _panel([
        Icon(icon, size: 44, color: color),
        const SizedBox(height: AppSpacing.md),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.navy)),
        const SizedBox(height: AppSpacing.sm),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, height: 1.6, color: AppColors.textSecondary)),
        ...actions,
      ], key: key);

  Widget _live(String text, {Key? key, Color color = AppColors.blueDeep}) =>
      Semantics(
          liveRegion: true,
          child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(text,
                  key: key,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: color))));

  // ── Sections ───────────────────────────────────────────────

  Widget _caption(String text) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
          color: AppColors.textMuted));

  bool get _deadlineElapsed {
    final deadline = _payment.paymentDeadline;
    final now = _payment.serverNow;
    return deadline != null && now != null && !now.isBefore(deadline);
  }

  Widget _summary() {
    final p = _payment;
    final s = p.snapshot!;
    final b = p.booking!;
    final total = s.totalAmount;
    final currency = (s.json['currency'] as String?) ?? b.currency;
    final quantity = s.quantity ?? b.quantity;
    return _panel([
      _caption('RINGKASAN PESANAN'),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.blueTint,
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(PhosphorIconsRegular.mountains,
                size: 22, color: AppColors.blue)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b.destinationName,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 2),
          Text('${formatLongDate(b.visitDate)} · $quantity tiket masuk',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ])),
      ]),
      const Divider(height: AppSpacing.xl + 4, color: AppColors.border),
      if (s.quantity != null && s.unitPrice != null)
        _line('Harga tiket',
            '${s.quantity} × ${formatMoney(s.unitPrice!, currency)}'),
      if (s.subtotal != null)
        _line('Subtotal', formatMoney(s.subtotal!, currency)),
      if ((s.serviceFee ?? 0) > 0)
        _line('Biaya layanan', formatMoney(s.serviceFee!, currency)),
      const Divider(height: AppSpacing.xl + 4, color: AppColors.border),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total tagihan',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text(total == null ? 'Belum tersedia' : formatMoney(total, currency),
              key: const Key('pay-total'),
              style: TextStyle(
                  fontSize: total == null ? 16 : 30,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blueDeep)),
        ])),
        TextButton(
            key: const Key('pay-detail'),
            onPressed: () => setState(() => _detail = !_detail),
            style: TextButton.styleFrom(
                minimumSize: const Size(48, 44),
                foregroundColor: AppColors.blue,
                backgroundColor: AppColors.blueTint,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Detail',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              AnimatedRotation(
                  turns: _detail ? .5 : 0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  child: const Icon(PhosphorIconsRegular.caretDown, size: 14)),
            ])),
      ]),
      AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: ClipRect(
              child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _detail ? 1 : 0,
                  child: IgnorePointer(
                      ignoring: !_detail,
                      child: ExcludeSemantics(
                          excluding: !_detail,
                          child: AnimatedOpacity(
                              opacity: _detail ? 1 : 0,
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOut,
                              child: Column(
                                  key: const Key('pay-detail-body'),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: AppSpacing.lg),
                                    const SizedBox(
                                        height: 1,
                                        child: CustomPaint(
                                            painter: _DashedLinePainter(
                                                Color(0xFFC9D6E8)))),
                                    const SizedBox(height: AppSpacing.lg),
                                    _copyTile('Nomor booking',
                                        s.bookingNumber ?? b.bookingNumber),
                                    if (s.invoiceNumber != null) ...[
                                      const SizedBox(height: AppSpacing.md),
                                      _copyTile(
                                          'Nomor invoice', s.invoiceNumber!),
                                    ],
                                  ]))))))),
    ]);
  }

  Widget _copyTile(String label, String value) => Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md + 2, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F9FE),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy)),
        ])),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
            key: Key('pay-copy-${label.toLowerCase().replaceAll(' ', '-')}'),
            tooltip: 'Salin $label',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text('$label disalin')));
            },
            style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                backgroundColor: AppColors.blueTint,
                foregroundColor: AppColors.blue,
                side: const BorderSide(color: Color(0xFFC9DDF7)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            icon: const Icon(PhosphorIconsRegular.copy, size: 18)),
      ]));

  Widget _countdown() => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: PaymentDeadline(
          key: const Key('pay-countdown'),
          banner: true,
          label: 'Sisa waktu pembayaran',
          caption: 'Selesaikan sebelum waktu habis',
          expiresAt:
              _payment.serverNow == null ? null : _payment.paymentDeadline,
          now: () => _payment.serverNow,
          onElapsed: _payment.onCountdownElapsed));

  String _choiceTitle(PayChoice choice) => choice.methodCode == 'qris'
      ? 'QRIS'
      : '${choice.channel.toUpperCase()} Virtual Account';

  String _choiceDescription(PayChoice choice) {
    if (choice.methodCode == 'qris') {
      return 'Bayar dengan aplikasi bank atau dompet digital yang mendukung QRIS.';
    }
    return switch (choice.channel) {
      'bca' => 'Transfer melalui m-banking, internet banking, atau ATM.',
      'bni' => 'Transfer melalui layanan BNI atau ATM yang mendukung.',
      _ => choice.subtitle,
    };
  }

  /// Official bank/QRIS marks (assets/images/payment) on a white tile.
  Widget _choiceLogo(PayChoice choice, {required bool muted}) {
    final asset = choice.methodCode == 'qris'
        ? 'assets/images/payment/qris.png'
        : switch (choice.channel) {
            'bca' => 'assets/images/payment/bca.png',
            'bni' => 'assets/images/payment/bni.png',
            _ => null,
          };
    final tile = Container(
        width: 72,
        height: 52,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14)),
        child: asset == null
            ? Text(choice.channel.toUpperCase(),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blueDeep))
            : Image.asset(asset,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                filterQuality: FilterQuality.medium));
    return muted ? Opacity(opacity: .4, child: tile) : tile;
  }

  Widget _chooser() {
    final p = _payment;
    final choices = p.snapshot!.payChoices;
    final locked = p.lockedChoiceKey;
    final selected = _effectiveChoice;
    final available = choices.where((c) => c.available).length;
    final anyAvailable = available > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: AppSpacing.sm),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Expanded(
            child: Text('Metode Pembayaran',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy))),
        Text('$available pilihan',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.blue)),
      ]),
      const SizedBox(height: AppSpacing.xs),
      const Text('Pilih metode yang paling nyaman untuk Anda.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: AppSpacing.md),
      for (final choice in choices) _choiceTile(choice, selected, locked),
      if (locked != null)
        Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _body(
                'Percobaan sebelumnya belum pasti. Lanjutkan dengan metode yang sama agar tidak ada tagihan ganda.')),
      if (!anyAvailable)
        Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _body(
                'Belum ada metode yang dapat dipakai. Tidak ada tagihan dibuat.')),
      _noteBox(
          'Nomor Virtual Account atau kode QR pembayaran akan diterbitkan oleh penyedia pembayaran setelah permintaan diproses. Jangan transfer menggunakan nomor booking atau invoice.'),
      const SizedBox(height: AppSpacing.md),
    ]);
  }

  Widget _noteBox(String text, {bool warning = false}) {
    final bg = warning ? const Color(0xFFFFF7E6) : const Color(0xFFEEF5FD);
    final border = warning ? const Color(0xFFF3DDAA) : const Color(0xFFC9DDF7);
    final fg = warning ? const Color(0xFF80531B) : AppColors.blueDeep;
    return Container(
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

  Widget _choiceTile(PayChoice choice, PayChoice? selected, String? locked) {
    final isSelected = selected?.key == choice.key;
    final canPick = choice.available &&
        !_payment.busy &&
        (locked == null || locked == choice.key);
    return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Semantics(
            inMutuallyExclusiveGroup: true,
            checked: isSelected,
            enabled: choice.available,
            label: choice.available
                ? choice.label
                : '${choice.label}, tidak tersedia',
            child: Material(
                color: isSelected ? AppColors.blueTint : AppColors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                        color: isSelected ? AppColors.blue : AppColors.border,
                        width: isSelected ? 1.5 : 1)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    key: Key(
                        'pay-choice-${choice.methodCode}-${choice.channel}'),
                    onTap: canPick
                        ? () => setState(() => _selected = choice)
                        : null,
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            minHeight: kMinInteractiveDimension),
                        child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  ExcludeSemantics(
                                      child: Container(
                                          width: 24,
                                          height: 24,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                              border: Border.all(
                                                  color: choice.available
                                                      ? AppColors.blue
                                                      : AppColors.border,
                                                  width: 2)),
                                          child: isSelected
                                              ? Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration:
                                                      const BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color:
                                                              AppColors.blue))
                                              : null)),
                                  const SizedBox(width: AppSpacing.md),
                                  ExcludeSemantics(
                                      child: _choiceLogo(choice,
                                          muted: !choice.available)),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(_choiceTitle(choice),
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: choice.available
                                                    ? AppColors.navy
                                                    : AppColors.textMuted)),
                                        const SizedBox(height: AppSpacing.xs),
                                        if (choice.available)
                                          Text(_choiceDescription(choice),
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  height: 1.5,
                                                  color:
                                                      AppColors.textSecondary))
                                        else ...[
                                          Text(payChoiceReason(choice.reason),
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  height: 1.5,
                                                  color:
                                                      AppColors.warningText)),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text('Kode alasan: ${choice.reason}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textMuted)),
                                        ],
                                        if (isSelected) ...[
                                          const SizedBox(height: AppSpacing.sm),
                                          Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFDCEBFB),
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              child: const Text('Terpilih',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color:
                                                          AppColors.blueDeep))),
                                        ],
                                      ])),
                                ])))))));
  }

  Widget _checkButton() {
    final p = _payment;
    return FilledButton(
        key: const Key('pay-check'),
        onPressed: p.canCheckNow ? p.checkNow : null,
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFD5DEEC),
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        child: Text(p.checking ? 'Memeriksa status…' : 'Cek Status Pembayaran',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)));
  }

  Future<void> _explainSwitch(PaymentSnapshot s) => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Expanded(
                          child: Text('Ganti Metode',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy))),
                      IconButton(
                          tooltip: 'Tutup',
                          onPressed: () => Navigator.pop(sheet),
                          style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFEEF3FA),
                              foregroundColor: AppColors.textSecondary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          icon: const Icon(PhosphorIconsRegular.x, size: 18)),
                    ]),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 16),
                    KeyedSubtree(
                        key: const Key('pay-switch-note'),
                        child: _noteBox(switchReasonText(s.switchReason))),
                    const SizedBox(height: 20),
                    FilledButton(
                        onPressed: () => Navigator.pop(sheet),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: AppColors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        child: const Text('Mengerti',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800))),
                  ]))));

  Future<void> _confirmStart() async {
    final choice = _effectiveChoice;
    final p = _payment;
    if (choice == null || !p.canStartWith(choice) || p.snapshot == null) return;
    final s = p.snapshot!;
    final b = p.booking!;
    final total = s.totalAmount;
    final currency = (s.json['currency'] as String?) ?? b.currency;
    final rows = <(String, String)>[
      ('Destinasi', b.destinationName),
      ('Metode', _choiceTitle(choice)),
      (
        'Total tagihan',
        total == null ? 'Belum tersedia' : formatMoney(total, currency)
      ),
    ];
    _ownSheet = true;
    final bool? ok;
    try {
      ok = await showModalBottomSheet<bool>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          showDragHandle: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (sheet) => SafeArea(
              top: false,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const Expanded(
                              child: Text('Konfirmasi Metode',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy))),
                          IconButton(
                              tooltip: 'Tutup',
                              onPressed: () => Navigator.pop(sheet, false),
                              style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFEEF3FA),
                                  foregroundColor: AppColors.textSecondary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              icon:
                                  const Icon(PhosphorIconsRegular.x, size: 18)),
                        ]),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 16),
                        Text(_choiceTitle(choice),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy)),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                            'Periksa pilihan pembayaran sebelum melanjutkan ke instruksi.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: AppSpacing.lg),
                        for (final row in rows) ...[
                          const Divider(height: 1, color: AppColors.border),
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(children: [
                                Expanded(
                                    child: Text(row.$1,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary))),
                                const SizedBox(width: AppSpacing.md),
                                Flexible(
                                    child: Text(row.$2,
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.navy))),
                              ])),
                        ],
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: AppSpacing.lg),
                        _noteBox(
                            'Melanjutkan akan membuat instruksi pembayaran untuk metode ini. Nominal dan batas waktu ditentukan oleh server.'),
                        const SizedBox(height: AppSpacing.lg),
                        Row(children: [
                          Expanded(
                              child: OutlinedButton(
                                  key: const Key('pay-confirm-change'),
                                  onPressed: () => Navigator.pop(sheet, false),
                                  style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      foregroundColor: AppColors.blue,
                                      side: const BorderSide(
                                          color: AppColors.border),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14))),
                                  child: const Text('Ubah Metode',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800)))),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                              child: FilledButton(
                                  key: const Key('pay-confirm'),
                                  onPressed: () => Navigator.pop(sheet, true),
                                  style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(52),
                                      backgroundColor: AppColors.blue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14))),
                                  child: const Text('Lihat Instruksi',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800)))),
                        ]),
                      ]))));
    } finally {
      _ownSheet = false;
    }
    if (ok == true && mounted) _start();
  }

  Widget? _dock(PaymentPhase phase) {
    final p = _payment;
    if (!p.valid ||
        phase == PaymentPhase.loading ||
        phase == PaymentPhase.loadFailed ||
        phase == PaymentPhase.paid ||
        p.snapshot == null ||
        p.booking == null ||
        (phase != PaymentPhase.awaiting && !p.chooserVisible)) {
      return null;
    }
    final awaiting = phase == PaymentPhase.awaiting;
    final s = p.snapshot!;
    final total = s.totalAmount;
    final currency = (s.json['currency'] as String?) ?? p.booking!.currency;
    final selected = _effectiveChoice;
    final expired = _deadlineElapsed;
    final enabled = selected != null && p.canStartWith(selected) && !expired;
    return Material(
        color: AppColors.surface,
        elevation: 8,
        shadowColor: Colors.black26,
        child: SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(awaiting ? 'Total tagihan' : 'Total pembayaran',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                            total == null
                                ? 'Belum tersedia'
                                : formatMoney(total, currency),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy)),
                      ])),
                  const SizedBox(width: AppSpacing.md),
                  awaiting
                      ? _checkButton()
                      : FilledButton(
                          key: const Key('pay-start'),
                          onPressed: enabled ? _confirmStart : null,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 52),
                              backgroundColor: AppColors.blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFD5DEEC),
                              disabledForegroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 22),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                                p.creating
                                    ? 'Membuat instruksi…'
                                    : expired
                                        ? 'Waktu Habis'
                                        : 'Lanjut Bayar',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 8),
                            const Icon(PhosphorIconsRegular.arrowRight,
                                size: 18),
                          ])),
                ]))));
  }

  String _groupDigits(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    return [
      for (var i = 0; i < compact.length; i += 4)
        compact.substring(i, i + 4 > compact.length ? compact.length : i + 4)
    ].join(' ');
  }

  Widget _steps(List<String> steps) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: AppSpacing.xl,
                    child: Text('${i + 1}.',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy))),
                Expanded(child: _body(steps[i])),
              ])),
      ]);

  Widget _instruction() {
    final p = _payment;
    final s = p.snapshot!;
    final total = s.totalAmount;
    final amount = total == null ? null : formatMoney(total);
    final isQris = s.attemptMethod == 'qris';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _countdown(),
      _methodCard(s, total),
      if (isQris) _qrisPanel(amount) else _vaPanel(s, amount),
      Center(
          child: TextButton.icon(
              key: const Key('pay-switch'),
              onPressed: () => _explainSwitch(s),
              style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: AppColors.blue),
              icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 16),
              label: const Text('Pilih Metode Lain',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w800)))),
    ]);
  }

  Widget _methodCard(PaymentSnapshot s, int? total) {
    final isQris = s.attemptMethod == 'qris';
    final currency =
        (s.json['currency'] as String?) ?? _payment.booking?.currency;
    return _panel([
      _caption('METODE YANG DIPILIH'),
      const SizedBox(height: AppSpacing.md),
      Row(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.blueTint,
                borderRadius: BorderRadius.circular(14)),
            child: Icon(
                isQris
                    ? PhosphorIconsRegular.qrCode
                    : PhosphorIconsRegular.creditCard,
                size: 22,
                color: AppColors.blue)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(paymentMethodLabel(s.attemptMethod, s.attemptChannel),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 2),
          const Text('Instruksi pembayaran aktif',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
      ]),
      const Divider(height: AppSpacing.xl + 4, color: AppColors.border),
      const Text('Total tagihan',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: AppSpacing.xs),
      Text(
          total == null
              ? 'Belum tersedia'
              : formatMoney(total, currency ?? 'IDR'),
          key: const Key('pay-total'),
          style: TextStyle(
              fontSize: total == null ? 16 : 30,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: AppColors.blueDeep)),
    ]);
  }

  Widget _vaPanel(PaymentSnapshot s, String? amount) {
    final digits = s.vaNumber;
    final bank = (s.bankCode ?? s.attemptChannel ?? '').toUpperCase();
    final grouped = digits == null ? '' : _groupDigits(digits);
    return _panel([
      _caption('INSTRUKSI PEMBAYARAN'),
      const SizedBox(height: AppSpacing.md),
      CustomPaint(
          painter: const DashedBorderPainter(Color(0xFFB9D3F2)),
          child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F9FE),
                  borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        color: AppColors.blueTint,
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(PhosphorIconsRegular.creditCard,
                        size: 24, color: AppColors.blue)),
                const SizedBox(height: AppSpacing.md),
                Text(
                    digits == null
                        ? 'Nomor VA belum diterbitkan'
                        : 'Virtual Account Bank $bank',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy)),
                const SizedBox(height: AppSpacing.sm),
                if (digits == null)
                  const Text(
                      'Nomor Virtual Account asli hanya ditampilkan dari respons penyedia pembayaran.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.textSecondary))
                else
                  Semantics(
                      label:
                          'Nomor virtual account $bank ${digits.split('').join(' ')}',
                      excludeSemantics: true,
                      child: Text(grouped,
                          key: const Key('pay-va-number'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              fontFeatures: [FontFeature.tabularFigures()]))),
                if (digits != null && amount != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                      'Nominal tetap $amount. Jumlah yang dibayar harus sama persis.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.textSecondary)),
                ],
              ]))),
      if (digits != null)
        _button('Salin Nomor VA', () => _copyVa(digits),
            key: const Key('pay-va-copy'),
            primary: false,
            icon: PhosphorIconsRegular.copy),
      if (_feedback != null) ...[
        const SizedBox(height: AppSpacing.md),
        _live(_feedback!),
      ],
      const SizedBox(height: AppSpacing.lg),
      _heading('Cara pembayaran'),
      _steps([
        'Buka m-banking, internet banking, atau ATM $bank.',
        bank == 'BCA'
            ? 'Pilih BCA Virtual Account, lalu masukkan nomor di atas.'
            : 'Pilih Virtual Account Billing, lalu masukkan nomor di atas.',
        'Periksa nama dan nominal, lalu konfirmasi pembayaran.',
      ]),
      const SizedBox(height: AppSpacing.xs),
      _noteBox(
          'Pembayaran dikonfirmasi otomatis setelah diterima. Jangan membayar dua kali.',
          warning: true),
    ]);
  }

  Widget _qrisPanel(String? amount) {
    final p = _payment;
    final png = p.qrPng;
    return _panel([
      _caption('INSTRUKSI PEMBAYARAN'),
      const SizedBox(height: AppSpacing.md),
      _heading('QR Pembayaran QRIS'),
      _body('Kode ini hanya untuk membayar, bukan tiket masuk.'),
      const SizedBox(height: AppSpacing.md),
      if (p.qrLoading)
        const Center(
            child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator()))
      else if (png != null && p.windowOpen)
        Center(
            child: Semantics(
                image: true,
                label: 'QR pembayaran QRIS, bukan tiket masuk',
                excludeSemantics: true,
                child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: AspectRatio(
                            aspectRatio: 1,
                            child: Image.memory(png,
                                key: const Key('pay-qr-image'),
                                excludeFromSemantics: true,
                                errorBuilder: (_, __, ___) => const Center(
                                    child: Text(
                                        'QR gagal ditampilkan. Muat ulang.')))))))),
      if (p.qrError != null) ...[
        _live(p.qrError!, color: AppColors.warningText),
        _button('Muat Ulang QR', p.retryQr,
            key: const Key('pay-qr-retry'), primary: false),
      ],
      if (amount != null) ...[
        const SizedBox(height: AppSpacing.md),
        _body('Nominal tetap $amount.'),
      ],
      if (png != null && p.windowOpen) ...[
        if (_exporter.supported) ...[
          _button('Simpan QR', _exporting ? null : () => _export(save: true),
              key: const Key('pay-qr-save'),
              primary: false,
              icon: PhosphorIconsRegular.downloadSimple),
          _button('Bagikan QR', _exporting ? null : () => _export(save: false),
              key: const Key('pay-qr-share'),
              primary: false,
              icon: PhosphorIconsRegular.shareNetwork),
        ] else
          Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: _body(
                  'Simpan dan bagikan QR belum tersedia di perangkat ini. Tunjukkan QR dari layar ini.')),
      ],
      if (_feedback != null) ...[
        const SizedBox(height: AppSpacing.md),
        _live(_feedback!),
      ],
      const SizedBox(height: AppSpacing.md),
      _heading('Cara membayar'),
      _steps(const [
        'Buka aplikasi bank atau dompet digital yang mendukung QRIS.',
        'Pindai QR di atas, atau pilih dari galeri setelah menyimpannya.',
        'Periksa nominal, lalu konfirmasi pembayaran.',
      ]),
      _body(
          'Pembayaran dikonfirmasi otomatis setelah diterima. Jangan membayar dua kali.'),
    ]);
  }

  Widget _statusChecks() {
    final p = _payment;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (p.offline)
        _live(
            'Tidak ada koneksi. Pembayaran Anda tidak terpengaruh; pemeriksaan dilanjutkan otomatis saat koneksi kembali.',
            key: const Key('pay-offline'),
            color: AppColors.warningText),
      if (p.phase != PaymentPhase.awaiting)
        _button(p.checking ? 'Memeriksa status…' : 'Cek Status Pembayaran',
            p.canCheckNow ? p.checkNow : null,
            key: const Key('pay-check'), primary: false),
      const Padding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
              'Status diperiksa otomatis selama halaman ini terbuka. Cek manual tersedia setiap 10 detik.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, height: 1.5, color: AppColors.textMuted))),
    ]);
  }

  Widget _inline(PaymentPhase phase) {
    final p = _payment;
    final s = p.snapshot!;
    final b = p.booking!;
    final status = s.attemptStatus;
    final retry = p.canRetry
        ? [
            _button('Pilih Metode Lagi', p.openRetry,
                key: const Key('pay-retry'))
          ]
        : const <Widget>[];
    const key = Key('pay-inline-state');
    switch (phase) {
      case PaymentPhase.verifying when s.verificationPending:
        return _statePanel(
            PhosphorIconsRegular.hourglassHigh,
            'Pembayaran sedang diverifikasi',
            verificationPendingMessage,
            AppColors.blueDeep,
            key: key);
      case PaymentPhase.verifying:
        final wallet = s.attemptMethod == 'ewallet';
        final title = status == 'paid'
            ? 'Pembayaran diterima, sedang diverifikasi'
            : status == 'initiating'
                ? 'Membuat instruksi pembayaran'
                : 'Status pembayaran sedang diperiksa';
        final text = wallet
            ? 'Pembayaran dompet digital sedang berjalan. Lanjutkan dari halaman detail booking dan jangan membayar ulang.'
            : status == 'paid'
                ? 'Penyedia melaporkan pembayaran. Booking baru dikonfirmasi setelah server memverifikasinya; halaman ini diperbarui otomatis.'
                : 'Kami memeriksa status langsung ke penyedia. Jangan membayar ulang; halaman ini diperbarui otomatis.';
        return _statePanel(
            PhosphorIconsRegular.hourglassHigh, title, text, AppColors.blueDeep,
            key: key);
      case PaymentPhase.review:
        return _statePanel(
            PhosphorIconsRegular.lock,
            'Pembayaran sedang ditinjau pengelola',
            s.verificationPending
                ? verificationPendingMessage
                : 'Jangan membayar ulang. Hasil peninjauan akan tampil di sini.',
            AppColors.warningText,
            key: key);
      case PaymentPhase.failed:
        return _statePanel(
            PhosphorIconsRegular.warningCircle,
            'Pembayaran Gagal',
            p.canRetry
                ? 'Instruksi ini tidak berhasil dibuat atau ditolak. Tidak ada tagihan yang perlu dibayar. Anda dapat memilih metode lagi.'
                : 'Instruksi ini tidak berhasil. Percobaan baru belum dapat dibuat sekarang; periksa status booking.',
            const Color(0xFF9C493D),
            key: key,
            actions: retry);
      case PaymentPhase.expired:
        return _statePanel(
            PhosphorIconsRegular.timer,
            'Pembayaran Kedaluwarsa',
            p.canRetry
                ? 'Waktu pembayaran habis. Jangan membayar ke instruksi lama. Anda dapat memilih metode lagi.'
                : 'Waktu pembayaran habis. Jangan membayar ke instruksi lama. Percobaan baru belum dapat dibuat sekarang.',
            const Color(0xFF9C493D),
            key: key,
            actions: retry);
      case PaymentPhase.cancelled:
        return _statePanel(
            PhosphorIconsRegular.prohibit,
            'Pembayaran Dibatalkan',
            'Instruksi lama tidak aktif lagi. Jangan membayar ke instruksi tersebut.',
            AppColors.textMuted,
            key: key,
            actions: retry);
      case PaymentPhase.adjusted:
        final refunded = status == 'refunded';
        return _statePanel(
            PhosphorIconsRegular.arrowsClockwise,
            status == 'refund_pending'
                ? 'Pengembalian dana diproses'
                : (refunded
                    ? 'Pembayaran dikembalikan'
                    : 'Pembayaran dibatalkan penyedia'),
            status == 'refund_pending'
                ? 'Dana belum dinyatakan kembali. Hak masuk ditahan sementara sampai proses selesai.'
                : 'Status pembayaran berubah setelah dilaporkan lunas. Periksa status tiket atau hubungi pengelola.',
            AppColors.warningText,
            key: key);
      default:
        final reason = s.json['reason'] as String?;
        return _statePanel(
            PhosphorIconsRegular.info,
            'Belum dapat dibayar',
            reason != null
                ? payChoiceReason(reason)
                : (bookingStatusNote(b.status) ??
                    'Booking ini sedang ${bookingStatusLabel(b.status).toLowerCase()}.'),
            AppColors.textMuted,
            key: key);
    }
  }

  // ── Success ────────────────────────────────────────────────

  String _paidAtLabel() {
    final paid = _payment.snapshot?.paidAt;
    if (paid == null) return 'Belum tersedia';
    final zone = _payment.tickets?.timezone ?? '';
    final local = zone.isEmpty
        ? paid.toUtc()
        : destinationCalendarNow(zone, instant: paid);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${formatLongDate('${local.year}-${two(local.month)}-${two(local.day)}')}, '
        '${two(local.hour)}.${two(local.minute)} ${local.timeZoneName}';
  }

  Widget _ticketStatus() {
    final p = _payment;
    final data = p.tickets;
    String text;
    var qrReady = false;
    if (data == null) {
      text = p.ticketsError ??
          (p.ticketsLoading
              ? 'Memeriksa status tiket masuk…'
              : 'Status tiket masuk belum diperiksa.');
    } else {
      final list = data.tickets;
      qrReady = data.admissionAllowed &&
          data.state != 'scheduled' &&
          list.any((t) => t.qrAvailable || t.checkedIn);
      text = switch (data.state) {
        'scheduled' =>
          'QR tiket masuk per pengunjung tersedia mulai ${formatLongDate(data.availableFrom)} (${data.timezone}).',
        'available' when data.admissionAllowed && !qrReady =>
          'Tiket sedang diterbitkan. QR per pengunjung akan muncul di sini begitu siap.',
        _ => data.message,
      };
    }
    return _panel([
      _heading('Tiket masuk'),
      _body(text),
      const SizedBox(height: AppSpacing.sm),
      _body(
          'Pembayaran dan tiket masuk adalah dua status berbeda. QR pembayaran tidak dipakai untuk masuk.',
          color: AppColors.textMuted),
      if (qrReady)
        _button(_showTickets ? 'Sembunyikan Tiket' : 'Lihat Tiket',
            () => setState(() => _showTickets = !_showTickets),
            key: const Key('pay-view-ticket')),
      _button(p.ticketsLoading ? 'Memeriksa…' : 'Perbarui Status Tiket',
          p.ticketsLoading ? null : p.loadTickets,
          key: const Key('pay-ticket-refresh'), primary: false),
      if (_showTickets && qrReady)
        BookingTicketQrSection(
            repository: widget.repository,
            bookingGuid: widget.bookingGuid,
            onRefreshed: p.loadTickets),
    ]);
  }

  Widget _success() {
    final p = _payment;
    final s = p.snapshot!;
    final b = p.booking!;
    final total = s.totalAmount;
    final currency = (s.json['currency'] as String?) ?? b.currency;
    return Column(
        key: const Key('pay-success'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statePanel(
              PhosphorIconsRegular.checkCircle,
              'Pembayaran Berhasil!',
              'Pembayaran sudah diverifikasi server dan booking Anda dikonfirmasi.',
              AppColors.success),
          _panel([
            _line('Status', 'Lunas'),
            _line('Nomor booking', s.bookingNumber ?? b.bookingNumber),
            _line('Nomor invoice', s.invoiceNumber ?? 'Belum tersedia'),
            _line('Destinasi', b.destinationName),
            _line('Tanggal kunjungan', formatLongDate(b.visitDate)),
            _line('Jumlah tiket', '${s.quantity ?? b.quantity}'),
            _line('Metode',
                paymentMethodLabel(s.attemptMethod, s.attemptChannel)),
            _line(
                'Total dibayar',
                total == null
                    ? 'Belum tersedia'
                    : formatMoney(total, currency)),
            _line('Waktu bayar', _paidAtLabel()),
          ]),
          _ticketStatus(),
          if (_feedback != null) _live(_feedback!),
          if (!s.receiptAvailable)
            _body('Bukti pembayaran sedang disiapkan.',
                color: AppColors.textMuted),
          _button(p.receiptBusy ? 'Mengunduh…' : 'Unduh Bukti Pembayaran',
              s.receiptAvailable && !p.receiptBusy ? _downloadReceipt : null,
              key: const Key('pay-receipt')),
          BookingRefundSection(
              repository: widget.repository,
              bookingGuid: widget.bookingGuid,
              seed: s,
              storage: widget.storage),
          _button('Lihat Booking', () => Navigator.maybePop(context),
              primary: false),
        ]);
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = _payment;
    final phase = p.phase;
    return Theme(
        data: AppColors.visitorTheme,
        child: Scaffold(
            backgroundColor: AppColors.bg,
            bottomNavigationBar: _dock(phase),
            body: SafeArea(
                top: false,
                child: RefreshIndicator(
                    onRefresh: p.reload,
                    child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _header(context, phase),
                              Padding(
                                  padding: const EdgeInsets.fromLTRB(20,
                                      AppSpacing.lg + 2, 20, AppSpacing.xl + 4),
                                  child: _content(phase)),
                            ]))))));
  }

  Widget _header(BuildContext context, PaymentPhase phase) =>
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
                    Padding(
                        padding: const EdgeInsets.only(
                            left: AppSpacing.sm, top: AppSpacing.lg),
                        child: Semantics(
                            header: true,
                            child: Text(_title(phase),
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)))),
                    const Padding(
                        padding: EdgeInsets.only(left: AppSpacing.sm, top: 6),
                        child: Text(
                            'Status pembayaran dikonfirmasi oleh server',
                            style:
                                TextStyle(fontSize: 12, color: Colors.white))),
                  ])));

  Widget _content(PaymentPhase phase) {
    final p = _payment;
    if (!p.valid) {
      return _panel([
        _body(p.error ??
            'Sesi berubah. Buka kembali pembayaran dari akun pemilik booking.')
      ]);
    }
    if (phase == PaymentPhase.loading) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const LinearProgressIndicator(),
        const SizedBox(height: AppSpacing.md),
        _panel([_body('Memuat tagihan dan status pembayaran…')]),
      ]);
    }
    if (phase == PaymentPhase.loadFailed) {
      return _panel([
        Text(p.error ?? 'Status pembayaran belum dapat dimuat.',
            style: const TextStyle(color: Color(0xFF9C493D))),
        _button('Coba lagi', p.busy ? null : () => p.reload(initial: true),
            primary: false),
      ]);
    }
    if (phase == PaymentPhase.paid) return _success();
    final pollable = const [
      PaymentPhase.awaiting,
      PaymentPhase.verifying,
      PaymentPhase.review
    ].contains(phase);
    final s = p.snapshot!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (p.busy && p.creating) const LinearProgressIndicator(),
      if (p.error != null)
        _live(p.error!,
            key: const Key('pay-error'), color: const Color(0xFF9C493D)),
      if (phase != PaymentPhase.awaiting) _summary(),
      if (phase == PaymentPhase.verifying &&
          s.attemptExpiresAt != null &&
          !s.verificationPending &&
          s.attemptStatus != 'paid')
        _countdown(),
      if (p.chooserVisible) ...[_countdown(), _chooser()],
      if (phase == PaymentPhase.awaiting)
        _instruction()
      else if (!p.chooserVisible)
        _inline(phase),
      if (pollable) _statusChecks(),
    ]);
  }
}

/// Shown while an attempt past its instruction expiry is still unresolved.
const verificationPendingMessage =
    'Pembayaran Anda sedang diverifikasi. Jangan bayar ulang. Kami akan memperbarui status setelah ada konfirmasi dari penyedia pembayaran.';

String formatLongDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value.isEmpty ? 'Belum tersedia' : value;
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Dashed rounded border for the empty/instruction placeholder box.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(18)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color;
}

/// Horizontal dashed rule.
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(
          Offset(x, 0), Offset((x + 4).clamp(0, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
