import 'package:flutter/material.dart';
import '../data/business_repository.dart';
import '../core/config/app_config.dart';
import '../data/payment_models.dart';
import '../screens/demo_checkout_screen.dart';
import '../theme/app_colors.dart';
import 'ewallet_payment_section.dart';

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

  /// Remembered across reloads so the wallet section is not unmounted while a refresh is running.
  bool _dokuSeen = false;
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
        _dokuSeen = methods.isDoku;
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
  Widget build(BuildContext context) {
    final doku = _dokuSeen;
    final demo = !doku && AppConfig.demoPaymentEnabled;
    final dokuReason = _methods?.json['reason'] == null
        ? 'Pembayaran online tersedia.'
        : _methods?.reason;
    // With DEMO off, a server still in demo mode is shown as unavailable, never as a simulator.
    final String? statusText = _error ??
        (doku
            ? dokuReason
            : demo
                ? _methods?.reason
                : (_methods == null
                    ? null
                    : 'Pembayaran online belum tersedia saat ini.'));
    return Padding(
        padding: const EdgeInsets.only(top: 14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(demo ? 'Pembayaran DEMO / TEST_ONLY' : 'Pembayaran',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blueDeep)),
          const SizedBox(height: 8),
          if (_loading) const LinearProgressIndicator(),
          Text(statusText ?? 'Memeriksa metode pembayaran dari server…',
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: Color(0xFF526787))),
          const SizedBox(height: 8),
          if (_intent?.attemptStatus != null && (doku || demo))
            Text('Attempt terakhir: ${_intent!.attemptStatus}',
                style: const TextStyle(
                    fontSize: 12, height: 1.5, color: Color(0xFF526787))),
          // DOKU wallets: a separate, always-mounted section owns start/return/resume (a reload here
          // must not dispose it mid-refresh). The DEMO controls stay for demo mode.
          if (doku)
            EwalletPaymentSection(
                booking: widget.booking,
                repository: widget.repository,
                onChanged: () async {
                  await widget.onReturned();
                  if (_valid) await _load();
                })
          else if (demo) ...[
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
  }
}
