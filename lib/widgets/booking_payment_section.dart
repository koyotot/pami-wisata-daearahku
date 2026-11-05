import 'package:flutter/material.dart';
import '../data/business_repository.dart';
import '../data/payment_models.dart';
import '../screens/demo_checkout_screen.dart';
import '../theme/app_colors.dart';

/// Read-only capabilities beside the existing booking detail; one checkout route for all entries.
class BookingPaymentSection extends StatefulWidget {
  const BookingPaymentSection(
      {super.key,
      required this.booking,
      required this.repository,
      required this.onReturned});
  final Booking booking;
  final BusinessRepository repository;
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
      });
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

  @override
  void dispose() {
    ++_request;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Pembayaran DEMO / TEST_ONLY',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.blueDeep)),
        const SizedBox(height: 8),
        if (_loading) const LinearProgressIndicator(),
        Text(
            _error ??
                _methods?.reason ??
                'Memeriksa metode pembayaran dari server…',
            style: const TextStyle(
                fontSize: 12, height: 1.5, color: Color(0xFF526787))),
        const SizedBox(height: 8),
        if (_intent?.attemptStatus != null)
          Text('Attempt terakhir: ${_intent!.attemptStatus}',
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: Color(0xFF526787))),
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
        if (_error != null)
          TextButton(
              onPressed: _loading ? null : _load,
              child: const Text('Periksa metode lagi')),
      ]));
}
