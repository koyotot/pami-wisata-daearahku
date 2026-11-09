import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../data/booking_refund_state.dart';
import '../data/business_repository.dart';
import '../data/payment_models.dart';
import '../theme/app_colors.dart';
import 'visit_format.dart';

/// Same error tone the payment checkout uses.
const _errorColor = Color(0xFF9C493D);

/// Refund request and status for a paid booking. Renders nothing until the server confirms the
/// booking is paid and confirmed (or a request already exists). Pass [seed] to reuse a payment
/// snapshot the page already holds instead of reading it again.
class BookingRefundSection extends StatefulWidget {
  const BookingRefundSection(
      {super.key,
      required this.repository,
      required this.bookingGuid,
      this.seed,
      this.storage,
      this.onChanged});
  final BusinessRepository repository;
  final String bookingGuid;
  final PaymentSnapshot? seed;
  final FlutterSecureStorage? storage;

  /// Called after a request was filed, so the parent can refresh the booking.
  final VoidCallback? onChanged;

  @override
  State<BookingRefundSection> createState() => _BookingRefundSectionState();
}

class _BookingRefundSectionState extends State<BookingRefundSection> {
  late final BookingRefundState _state = BookingRefundState(
      widget.repository, widget.bookingGuid,
      storage: widget.storage, seed: widget.seed);
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _state.addListener(_changed);
    if (widget.seed == null) {
      _state.load();
    } else {
      _state.restoreOperation();
    }
  }

  @override
  void didUpdateWidget(BookingRefundSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final seed = widget.seed;
    if (seed != null && !identical(seed, oldWidget.seed) && !_state.submitting) {
      _state.applySnapshot(seed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _state.removeListener(_changed);
    _state.dispose();
    super.dispose();
  }

  Future<void> _openSheet() async {
    if (_state.submitting) return;
    _state.clearError();
    setState(() => _sheetOpen = true);
    final sent = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppColors.surface,
        builder: (_) => Theme(
            data: AppColors.visitorTheme, child: _RefundSheet(state: _state)));
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (sent == true) widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    final refund = s.refund;
    if (!s.loaded || (refund == null && !s.canRequest)) {
      return const SizedBox.shrink();
    }
    return Container(
        key: const Key('refund-section'),
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                  header: true,
                  child: const Text('Pengembalian Dana',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy))),
              const SizedBox(height: AppSpacing.sm),
              if (refund != null) _status(refund) else _intro(),
              if (s.notice != null)
                _live(s.notice!, key: const Key('refund-notice'), color: AppColors.success),
              if (s.error != null && !s.submitting && !_sheetOpen)
                _live(s.error!, key: const Key('refund-error'), color: _errorColor),
              if (s.canRequest)
                Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: OutlinedButton(
                        key: const Key('refund-open'),
                        style: OutlinedButton.styleFrom(
                            minimumSize:
                                const Size.fromHeight(kMinInteractiveDimension),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16))),
                        onPressed: s.submitting ? null : _openSheet,
                        child: const Text('Ajukan Pengembalian Dana',
                            textAlign: TextAlign.center))),
              if (refund != null && refund.isActive)
                Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: TextButton(
                        key: const Key('refund-refresh'),
                        onPressed: s.loading ? null : s.refresh,
                        child: Text(s.loading ? 'Memeriksa…' : 'Perbarui Status',
                            textAlign: TextAlign.center))),
            ]));
  }

  Widget _intro() => const Text(
      'Jika tidak jadi berkunjung, Anda dapat mengajukan pengembalian dana. Pengelola akan meninjau pengajuan; persetujuan belum dijamin.',
      style: TextStyle(
          fontSize: 13, height: 1.5, color: AppColors.textSecondary));

  Widget _status(RefundRequest refund) {
    final color = switch (refund.status) {
      'refunded' || 'manual_refunded' => AppColors.success,
      'rejected' => _errorColor,
      _ => AppColors.warningText,
    };
    final icon = switch (refund.status) {
      'refunded' || 'manual_refunded' => PhosphorIconsRegular.checkCircle,
      'rejected' => PhosphorIconsRegular.xCircle,
      _ => PhosphorIconsRegular.hourglassMedium,
    };
    final amount = refund.amount;
    final refundedAt = refund.isManualRefunded ? refund.refundedAt : null;
    return Column(
        key: Key('refund-status-${refund.status}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: Text(refund.title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: color))),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text(refund.message,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: AppColors.textSecondary)),
          if (refund.isRejected && refund.decisionNote != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _line('Catatan pengelola', refund.decisionNote!),
          ],
          if (refundedAt != null)
            _line('Tanggal pengembalian dana', visitDateLabel(refundedAt.toLocal())),
          if (amount != null)
            _line(refund.isClosedRefund ? 'Dana dikembalikan' : 'Nilai pengajuan',
                formatMoney(amount, refund.currency ?? 'IDR')),
          if (refund.reason != null) _line('Alasan Anda', refund.reason!),
        ]);
  }

  Widget _line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.xs),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.navy)),
      ]));

  Widget _live(String text, {Key? key, required Color color}) => Semantics(
      liveRegion: true,
      child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Text(text,
              key: key,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: color))));
}

/// Reason form. The key and reason are persisted by [BookingRefundState] before sending, so closing
/// and reopening after an uncertain outcome resumes the same request.
class _RefundSheet extends StatefulWidget {
  const _RefundSheet({required this.state});
  final BookingRefundState state;

  @override
  State<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends State<_RefundSheet> {
  late final TextEditingController _reason =
      TextEditingController(text: widget.state.pendingReason ?? '');
  String? _validation;

  BookingRefundState get _state => widget.state;
  bool get _locked => _state.pendingReason != null;

  @override
  void initState() {
    super.initState();
    _state.addListener(_changed);
  }

  @override
  void dispose() {
    _state.removeListener(_changed);
    _reason.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (_state.submitting) return;
    final invalid = _locked ? null : validateRefundReason(_reason.text);
    setState(() => _validation = invalid);
    if (invalid != null) return;
    final sent = await _state.submit(_reason.text);
    if (sent && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final submitting = _state.submitting;
    final error = submitting ? null : _state.error;
    return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                      header: true,
                      child: const Text('Ajukan Pengembalian Dana',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy))),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                      'Ceritakan alasan Anda. Pengelola akan meninjau pengajuan ini; dana baru dikirim setelah pengelola menyelesaikan prosesnya.',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                      key: const Key('refund-reason'),
                      controller: _reason,
                      enabled: !submitting,
                      readOnly: _locked,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: refundReasonMaxLength,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(refundReasonMaxLength)
                      ],
                      onChanged: (_) {
                        if (_validation != null) setState(() => _validation = null);
                      },
                      decoration: const InputDecoration(
                          labelText: 'Alasan pengembalian dana',
                          alignLabelWithHint: true)),
                  if (_locked)
                    const _SheetNote(
                        'Pengajuan sebelumnya belum pasti terkirim. Kirim ulang dengan alasan yang sama; pengajuan tidak akan terkirim ganda.'),
                  if (_validation != null)
                    _SheetNote(_validation!,
                        key: const Key('refund-reason-error'),
                        color: _errorColor),
                  if (error != null)
                    _SheetNote(error,
                        key: const Key('refund-submit-error'),
                        color: _errorColor),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                      key: const Key('refund-submit'),
                      onPressed: submitting ? null : _submit,
                      child: submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.blueDeep))
                          : const Text('Kirim Pengajuan',
                              textAlign: TextAlign.center)),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                      key: const Key('refund-cancel'),
                      onPressed:
                          submitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Batal')),
                ])));
  }
}

class _SheetNote extends StatelessWidget {
  const _SheetNote(this.text,
      {super.key, this.color = AppColors.textSecondary});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(text,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: color))));
}
