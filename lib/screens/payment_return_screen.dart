import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/app_data.dart';
import '../data/business_repository.dart';
import '../data/ewallet_payment_state.dart';
import '../data/payment_return_link.dart';
import '../theme/app_colors.dart';
import 'session_destination.dart';

/// Landing screen for the HTTPS App Link `/payment/return`. The link (and its `result` hint) proves
/// nothing: this screen finds the unfinished wallet attempt on this device and asks the server for its state.
class PaymentReturnScreen extends StatefulWidget {
  const PaymentReturnScreen(
      {super.key,
      required this.hint,
      required this.repository,
      this.launcher,
      this.storage,
      this.pollInterval = const Duration(seconds: 5)});
  final PaymentReturnHint hint;
  final BusinessRepository repository;
  final WalletLauncher? launcher;
  final FlutterSecureStorage? storage;
  final Duration pollInterval;
  @override
  State<PaymentReturnScreen> createState() => _PaymentReturnScreenState();
}

enum _Resolution { resolving, needsLogin, noPayment, ready }

class _PaymentReturnScreenState extends State<PaymentReturnScreen> {
  _Resolution _resolution = _Resolution.resolving;
  EwalletPaymentState? _payment;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final session = widget.repository.api.session;
    final user = currentUser;
    _payment?.dispose();
    _payment = null;
    if (user == null ||
        !session.authenticated.value ||
        !session.deviceSessionReady ||
        session.role != 0) {
      if (mounted) setState(() => _resolution = _Resolution.needsLogin);
      return;
    }
    if (mounted) setState(() => _resolution = _Resolution.resolving);
    final pointer = await EwalletPointer.load(user.id,
        storage: widget.storage ?? const FlutterSecureStorage());
    if (_disposed || !mounted) return;
    if (pointer == null) {
      setState(() => _resolution = _Resolution.noPayment);
      return;
    }
    final payment = EwalletPaymentState(widget.repository, pointer.bookingGuid,
        launcher: widget.launcher,
        storage: widget.storage,
        pollInterval: widget.pollInterval)
      ..hint = widget.hint
      ..pointer = pointer;
    _payment = payment;
    setState(() => _resolution = _Resolution.ready);
    // Server inquiry first; the hint never decides anything.
    await payment.refresh();
    if (!_disposed && payment.isActive) payment.startPolling();
  }

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
          MaterialPageRoute<void>(builder: (_) => sessionDestination()));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _payment?.dispose();
    super.dispose();
  }

  String _hintNote(PaymentReturnHint hint) => switch (hint) {
        PaymentReturnHint.success =>
          'Halaman dompet digital menyatakan proses selesai, tetapi hanya konfirmasi server yang menentukan hasil pembayaran.',
        PaymentReturnHint.cancel =>
          'Anda tampaknya membatalkan pembayaran di dompet digital. Kami tetap memeriksa status ke server.',
        PaymentReturnHint.error =>
          'Dompet digital melaporkan kendala. Kami tetap memeriksa status ke server.',
        _ => '',
      };

  Widget _panel(String title, String body, List<Widget> actions,
          {IconData icon = Icons.info_outline, Color? color, Key? key}) =>
      Container(
          key: key,
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 34, color: color ?? AppColors.blueDeep),
                const SizedBox(height: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(body,
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: Color(0xFF526787))),
                ...actions
              ]));

  Widget _button(String text, VoidCallback? onPressed,
          {bool primary = true, Key? key}) =>
      Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
              width: double.infinity,
              child: primary
                  ? ElevatedButton(
                      key: key, onPressed: onPressed, child: Text(text))
                  : OutlinedButton(
                      key: key, onPressed: onPressed, child: Text(text))));

  Widget _content() {
    switch (_resolution) {
      case _Resolution.resolving:
        return _loading();
      case _Resolution.needsLogin:
        return _panel(
            'Masuk untuk Melihat Status',
            'Masuk sebagai pengunjung pemilik booking untuk memeriksa pembayaran. Data pembayaran Anda tetap tersimpan di perangkat ini.',
            [
              _button('Kembali', _back, key: const Key('return-back')),
              _button('Coba Lagi', _resolve,
                  primary: false, key: const Key('return-retry'))
            ],
            icon: Icons.lock_outline,
            key: const Key('return-needs-login'));
      case _Resolution.noPayment:
        return _panel(
            'Tidak Ada Pembayaran yang Sedang Berjalan',
            'Aplikasi tidak menemukan pembayaran dompet digital yang menunggu. Buka detail booking untuk memeriksa status pembayaran.',
            [_button('Kembali ke Aplikasi', _back, key: const Key('return-back'))],
            key: const Key('return-none'));
      case _Resolution.ready:
        return ListenableBuilder(
            listenable: _payment!, builder: (context, child) => _paymentView(_payment!));
    }
  }

  Widget _loading() => _panel(
      'Memeriksa Status Pembayaran',
      'Kami sedang memeriksa status pembayaran ke server. Mohon tunggu.',
      const [Padding(padding: EdgeInsets.only(top: 14), child: LinearProgressIndicator())],
      icon: Icons.hourglass_top,
      key: const Key('return-resolving'));

  Widget _paymentView(EwalletPaymentState payment) {
    final note = _hintNote(widget.hint);
    final noteWidget = note.isEmpty
        ? const <Widget>[]
        : [
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(note,
                    key: const Key('return-hint-note'),
                    style: const TextStyle(fontSize: 12, height: 1.5)))
          ];
    final errorWidget = payment.error == null
        ? const <Widget>[]
        : [
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(payment.error!,
                    key: const Key('return-error'),
                    style: const TextStyle(
                        fontSize: 12, height: 1.5, color: Color(0xFFB3261E))))
          ];
    final refreshButton = _button('Periksa Status Lagi',
        payment.busy ? null : payment.refresh,
        key: const Key('return-refresh'));
    final backButton =
        _button('Kembali ke Booking', _back, primary: false, key: const Key('return-back'));

    // Nothing was read yet (first request pending, or every read failed).
    if (payment.intent == null || payment.booking == null) {
      if (payment.busy) return _loading();
      return _panel(
          'Status Belum Dapat Diperiksa',
          'Kami belum dapat memeriksa status pembayaran. Pembayaran Anda tidak berubah dan tidak dibayar ulang. Coba lagi.',
          [...noteWidget, ...errorWidget, refreshButton, backButton],
          icon: Icons.cloud_off,
          color: const Color(0xFFB3261E),
          key: const Key('return-unreachable'));
    }
    final progress = payment.busy
        ? const [
            Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator())
          ]
        : const <Widget>[];
    switch (payment.phase) {
      case EwalletPhase.confirmed:
        return _panel(
            'Pembayaran Terkonfirmasi',
            'Server telah memverifikasi pembayaran dan booking Anda sudah dikonfirmasi.',
            [_button('Kembali ke Booking', _back, key: const Key('return-back'))],
            icon: Icons.check_circle_outline,
            color: const Color(0xFF1B7F3B),
            key: const Key('return-confirmed'));
      case EwalletPhase.pending:
        return _panel(
            'Pembayaran Belum Terkonfirmasi',
            'Server belum menerima konfirmasi pembayaran dari penyedia. Ini belum berarti berhasil maupun gagal.',
            [
              ...noteWidget,
              ...errorWidget,
              ...progress,
              refreshButton,
              _button('Buka Dompet Digital', payment.busy ? null : payment.reopen,
                  primary: false, key: const Key('return-reopen')),
              backButton
            ],
            icon: Icons.hourglass_top,
            key: const Key('return-pending'));
      case EwalletPhase.unknown:
        return _panel(
            'Status Pembayaran Belum Pasti',
            'Server belum dapat memastikan status dari penyedia. Jangan membayar ulang; periksa kembali beberapa saat lagi.',
            [...noteWidget, ...errorWidget, ...progress, refreshButton, backButton],
            icon: Icons.help_outline,
            key: const Key('return-unknown'));
      case EwalletPhase.failed:
      case EwalletPhase.expired:
        return _panel(
            payment.phase == EwalletPhase.expired
                ? 'Pembayaran Kedaluwarsa'
                : 'Pembayaran Tidak Berhasil',
            'Pembayaran tidak selesai. Anda dapat memulai pembayaran baru dari detail booking selama batas waktu belum berakhir.',
            [...noteWidget, ...errorWidget, backButton],
            icon: Icons.highlight_off,
            color: const Color(0xFFB3261E),
            key: const Key('return-failed'));
      case EwalletPhase.review:
        return _panel(
            'Pembayaran Sedang Ditinjau',
            'Pengelola sedang memeriksa pembayaran ini. Jangan membayar ulang; hubungi pengelola bila perlu.',
            [...errorWidget, backButton],
            key: const Key('return-review'));
      case EwalletPhase.idle:
      case EwalletPhase.otherMethod:
        return _panel(
            'Tidak Ada Pembayaran Dompet Digital Aktif',
            'Server tidak mencatat pembayaran dompet digital yang sedang menunggu untuk booking ini.',
            [...noteWidget, ...errorWidget, refreshButton, backButton],
            key: const Key('return-idle'));
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: AppColors.visitorTheme,
      child: Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
              title: const Text('Status Pembayaran'),
              leading: BackButton(onPressed: _back)),
          body: SafeArea(
              child: ListView(
                  padding: const EdgeInsets.all(20), children: [_content()]))));
}

/// `MaterialApp.onGenerateRoute` hook for the `/payment/return` App Link (cold and warm start).
/// Returns null for every other route so the app's normal routing is untouched.
Route<dynamic>? paymentReturnRoute(RouteSettings settings,
    {BusinessRepository Function()? repository}) {
  final link = PaymentReturnLink.parse(settings.name);
  if (link == null) return null;
  return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => PaymentReturnScreen(
          hint: link.hint,
          repository: repository == null ? BusinessRepository() : repository()));
}
