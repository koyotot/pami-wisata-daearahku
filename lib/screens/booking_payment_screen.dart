import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../data/booking_payment_state.dart';
import '../data/booking_state.dart';
import '../data/business_repository.dart';
import '../data/payment_models.dart';
import '../services/payment_qr_export.dart';
import '../theme/app_colors.dart';
import '../widgets/availability_calendar.dart' show destinationCalendarNow;
import '../widgets/booking_refund_section.dart';
import '../widgets/booking_ticket_qr_section.dart';
import '../widgets/payment_deadline.dart';
import 'auth_presentation.dart';

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

  @override
  void initState() {
    super.initState();
    _payment.addListener(_changed);
    _payment.open();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = ModalRoute.isCurrentOf(context) ?? true;
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

  void _start() {
    final choice = _effectiveChoice;
    if (choice == null || !_payment.canStartWith(choice)) return;
    _payment.start(choice);
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

  Widget _summary() {
    final p = _payment;
    final s = p.snapshot!;
    final b = p.booking!;
    final total = s.totalAmount;
    final currency = (s.json['currency'] as String?) ?? b.currency;
    return _panel([
      Text(b.destinationName,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.navy)),
      const SizedBox(height: AppSpacing.sm),
      _line('Nomor booking', s.bookingNumber ?? b.bookingNumber),
      if (s.invoiceNumber != null) _line('Nomor invoice', s.invoiceNumber!),
      _line('Tanggal kunjungan', formatLongDate(b.visitDate)),
      if (s.quantity != null && s.unitPrice != null)
        _line(
            'Tiket', '${s.quantity} × ${formatMoney(s.unitPrice!, currency)}'),
      if (s.subtotal != null)
        _line('Subtotal', formatMoney(s.subtotal!, currency)),
      if ((s.serviceFee ?? 0) > 0)
        _line('Biaya layanan', formatMoney(s.serviceFee!, currency)),
      const Divider(height: AppSpacing.xl, color: AppColors.border),
      _line('Total tagihan',
          total == null ? 'Belum tersedia' : formatMoney(total, currency),
          key: const Key('pay-total')),
    ]);
  }

  Widget _countdown() => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: PaymentDeadline(
          key: const Key('pay-countdown'),
          label: 'Batas waktu pembayaran',
          expiresAt:
              _payment.serverNow == null ? null : _payment.paymentDeadline,
          now: () => _payment.serverNow,
          onElapsed: _payment.onCountdownElapsed));

  Widget _chooser() {
    final p = _payment;
    final choices = p.snapshot!.payChoices;
    final locked = p.lockedChoiceKey;
    final selected = _effectiveChoice;
    final anyAvailable = choices.any((c) => c.available);
    return _panel([
      _heading('Metode pembayaran'),
      for (final choice in choices) _choiceTile(choice, selected, locked),
      if (locked != null)
        Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: _body(
                'Percobaan sebelumnya belum pasti. Lanjutkan dengan metode yang sama agar tidak ada tagihan ganda.')),
      if (!anyAvailable)
        Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: _body(
                'Belum ada metode yang dapat dipakai. Tidak ada tagihan dibuat.')),
      _button(p.creating ? 'Membuat instruksi pembayaran…' : 'Lanjut Bayar',
          selected != null && p.canStartWith(selected) ? _start : null,
          key: const Key('pay-start')),
    ]);
  }

  Widget _choiceTile(PayChoice choice, PayChoice? selected, String? locked) {
    final isSelected = selected?.key == choice.key;
    final canPick = choice.available &&
        !_payment.busy &&
        (locked == null || locked == choice.key);
    return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: isSelected ? AppColors.blue : AppColors.border,
                        width: isSelected ? 2 : 1)),
                child: InkWell(
                    key: Key(
                        'pay-choice-${choice.methodCode}-${choice.channel}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: canPick
                        ? () => setState(() => _selected = choice)
                        : null,
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            minHeight: kMinInteractiveDimension),
                        child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ExcludeSemantics(
                                      child: Icon(
                                          isSelected
                                              ? PhosphorIconsRegular.radioButton
                                              : PhosphorIconsRegular.circle,
                                          color: choice.available
                                              ? AppColors.blue
                                              : AppColors.textMuted)),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(choice.label,
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: choice.available
                                                    ? AppColors.navy
                                                    : AppColors.textMuted)),
                                        const SizedBox(height: AppSpacing.xs),
                                        if (choice.available)
                                          Text(choice.subtitle,
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
                                      ])),
                                ])))))));
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
      if (isQris) _qrisPanel(amount) else _vaPanel(s, amount),
      if (!s.canSwitch)
        _panel([
          _heading('Ganti metode'),
          _body(switchReasonText(s.switchReason)),
        ], key: const Key('pay-switch-note')),
    ]);
  }

  Widget _vaPanel(PaymentSnapshot s, String? amount) {
    final digits = s.vaNumber!;
    final bank = s.bankCode!.toUpperCase();
    final grouped = _groupDigits(digits);
    return _panel([
      _heading('Virtual Account Bank $bank'),
      Semantics(
          label: 'Nomor virtual account $bank ${digits.split('').join(' ')}',
          excludeSemantics: true,
          child: Text(grouped,
              key: const Key('pay-va-number'),
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  fontFeatures: [FontFeature.tabularFigures()]))),
      if (amount != null) ...[
        const SizedBox(height: AppSpacing.sm),
        _body('Nominal tetap $amount. Jumlah yang dibayar harus sama persis.'),
      ],
      _button('Salin Nomor VA', () => _copyVa(digits),
          key: const Key('pay-va-copy'),
          primary: false,
          icon: PhosphorIconsRegular.copy),
      if (_feedback != null) ...[
        const SizedBox(height: AppSpacing.md),
        _live(_feedback!),
      ],
      const SizedBox(height: AppSpacing.md),
      _heading('Cara membayar'),
      _steps([
        'Buka m-banking, internet banking, atau ATM $bank.',
        bank == 'BCA'
            ? 'Pilih BCA Virtual Account, lalu masukkan nomor di atas.'
            : 'Pilih Virtual Account Billing, lalu masukkan nomor di atas.',
        'Periksa nama dan nominal, lalu konfirmasi pembayaran.',
      ]),
      _body(
          'Pembayaran dikonfirmasi otomatis setelah diterima. Jangan membayar dua kali.'),
    ]);
  }

  Widget _qrisPanel(String? amount) {
    final p = _payment;
    final png = p.qrPng;
    return _panel([
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
      _summary(),
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
      _button('Kembali ke Detail Booking', () => Navigator.maybePop(context),
          primary: false),
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
