import 'package:flutter/material.dart';
import '../data/business_repository.dart';
import '../core/config/app_config.dart';
import '../data/payment_models.dart';
import '../screens/user/booking_payment_screen.dart';
import '../screens/user/demo_checkout_screen.dart';
import '../theme/app_colors.dart';

/// Read-only capabilities beside the existing booking detail; one checkout route for all entries.
class BookingPaymentSection extends StatefulWidget {
  const BookingPaymentSection(
      {super.key,
      required this.booking,
      required this.repository,
      this.onSnapshot,
      this.layoutBuilder,
      required this.onReturned});
  final Booking booking;
  final BusinessRepository repository;
  final ValueChanged<PaymentSnapshot>? onSnapshot;

  /// Lets the detail page place the existing checkout action in its bottom bar.
  final Widget Function(BuildContext context, Widget content, Widget? checkout)?
      layoutBuilder;
  final Future<void> Function() onReturned;
  @override
  State<BookingPaymentSection> createState() => _BookingPaymentSectionState();
}

class _BookingPaymentSectionState extends State<BookingPaymentSection>
    with WidgetsBindingObserver {
  PaymentSnapshot? _methods;
  PaymentSnapshot? _intent;
  String? _error;
  bool _loading = false;
  bool _opening = false;

  /// Remembered across reloads so the real-payment view is not swapped out while a refresh is running.
  bool _realSeen = false;
  late final _generation = widget.repository.api.session.sessionGeneration;
  int _request = 0;
  bool get _valid =>
      mounted &&
      widget.repository.api.session.isCurrentGeneration(_generation) &&
      widget.repository.api.session.role == 0 &&
      widget.repository.api.session.deviceSessionReady;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(BookingPaymentSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking.status != widget.booking.status ||
        oldWidget.booking.paymentExpiresAt != widget.booking.paymentExpiresAt) {
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (!_valid) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _methods = null;
      _intent = null;
    });
    try {
      final snapshots = await Future.wait([
        widget.repository.paymentMethods(widget.booking.guid),
        widget.repository.paymentIntent(widget.booking.guid),
      ]);
      final methods = snapshots[0];
      final intent = snapshots[1];
      if (!_valid || request != _request) return;
      if (methods.bookingGuid != widget.booking.guid ||
          intent.bookingGuid != widget.booking.guid) {
        throw StateError('Invalid booking');
      }
      setState(() {
        _methods = methods;
        _intent = intent;
        _realSeen = intent.isRealPayment || methods.isRealPayment;
      });
      widget.onSnapshot?.call(intent);
    } catch (e) {
      if (_valid && request == _request) {
        setState(() => _error = paymentError(e));
      }
    } finally {
      if (_valid && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    if (_opening || !_valid) return;
    setState(() => _opening = true);
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => DemoCheckoutScreen(
              bookingGuid: widget.booking.guid,
              repository: widget.repository)));
      if (!_valid) return;
      await widget.onReturned();
      if (_valid) await _load();
    } finally {
      if (_valid) setState(() => _opening = false);
    }
  }

  /// BCA/BNI VA / QRIS checkout. Only navigates; nothing is created until the customer taps "Lanjut Bayar".
  Future<void> _openCheckout() async {
    if (_opening || !_valid) return;
    setState(() => _opening = true);
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => BookingPaymentScreen(
              bookingGuid: widget.booking.guid,
              repository: widget.repository)));
      if (!_valid) return;
      await widget.onReturned();
      if (_valid) await _load();
    } finally {
      if (_valid) setState(() => _opening = false);
    }
  }

  /// Label for the checkout entry, or null when the server offers nothing to do here.
  String? get _checkoutLabel {
    final snapshot = _intent ?? _methods;
    if (snapshot == null || !snapshot.isRealPayment) return null;
    final status = snapshot.attemptStatus;
    final method = snapshot.attemptMethod;
    // Unresolved past its expiry: only a status view, never "pay again".
    if (status != null && snapshot.verificationPending) {
      return 'Lihat Status Pembayaran';
    }
    if (status == null) {
      return snapshot.canCreate && snapshot.payChoices.any((c) => c.available)
          ? 'Pilih Metode Pembayaran'
          : null;
    }
    // Historical wallet attempts are read-only: no checkout action.
    if (method != 'virtual_account' && method != 'qris') return null;
    if (const ['initiating', 'pending', 'unknown'].contains(status)) {
      return 'Lanjutkan Pembayaran';
    }
    if (const ['failed', 'expired', 'cancelled'].contains(status) &&
        snapshot.canCreate &&
        snapshot.intentStatus != 'needs_review') {
      return 'Pilih Metode Pembayaran';
    }
    return 'Lihat Status Pembayaran';
  }

  @override
  void dispose() {
    ++_request;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final real = _realSeen;
    final demo = !real && AppConfig.demoPaymentEnabled;
    final realReason = _methods?.json['reason'] == null
        ? 'Pembayaran online tersedia.'
        : payChoiceReason(_methods?.json['reason'] as String?);
    // With DEMO off, a server still in demo mode is shown as unavailable, never as a simulator.
    final String? statusText = _error ??
        (real
            ? realReason
            : demo
                ? _methods?.reason
                : (_methods == null
                    ? null
                    : 'Pembayaran online belum tersedia saat ini.'));
    final checkout = real && _checkoutLabel != null
        ? ElevatedButton(
            key: const Key('payment-open-checkout'),
            onPressed: _loading || _opening || !_valid ? null : _openCheckout,
            style: ElevatedButton.styleFrom(
                elevation: 0,
                minimumSize: Size(widget.layoutBuilder == null ? 48 : 140,
                    widget.layoutBuilder == null ? 48 : 50),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                textStyle: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontSize: 13, fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: Text(widget.layoutBuilder != null &&
                    _checkoutLabel == 'Pilih Metode Pembayaran'
                ? 'Pilih Pembayaran →'
                : _checkoutLabel!))
        : null;
    final content = Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(demo ? 'Pembayaran DEMO / TEST_ONLY' : 'Pembayaran',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blueDeep)),
          const SizedBox(height: AppSpacing.sm),
          if (_loading) const LinearProgressIndicator(),
          Text(statusText ?? 'Memeriksa metode pembayaran…',
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          if (_intent?.attemptStatus != null && (real || demo))
            Text(
                'Pembayaran terakhir: ${paymentAttemptLabel(_intent!.attemptStatus)}',
                style: const TextStyle(
                    fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
          // Real payments open the native checkout. The DEMO controls stay for demo mode.
          if (real) ...[
            if (checkout != null && widget.layoutBuilder == null)
              Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: checkout),
          ] else if (demo) ...[
            ElevatedButton(
                onPressed: _loading ||
                        _opening ||
                        !_valid ||
                        _methods?.demoAvailable != true ||
                        _intent?.demoAvailable != true ||
                        _intent?.attemptStatus == 'unknown'
                    ? null
                    : _open,
                child: const Text('Lanjutkan Pembayaran DEMO')),
            TextButton(
                onPressed: _opening || !_valid ? null : _open,
                child: const Text('Cek Status / Pulihkan Pembayaran')),
          ],
          if (_error != null)
            TextButton(
                onPressed: _loading ? null : _load,
                child: const Text('Periksa metode lagi')),
        ]));
    return widget.layoutBuilder?.call(context, content, checkout) ?? content;
  }
}
