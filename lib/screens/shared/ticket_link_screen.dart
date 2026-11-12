import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../data/business_repository.dart';
import '../../data/ticket_link.dart';
import '../../services/auth_session.dart';
import '../../theme/app_colors.dart';
import '../user/bukti_pendaftaran_screen.dart';
import 'session_destination.dart';
import '../auth/user_login_screen.dart';

enum _LinkState { resolving, needsLogin, notFound, failed, ready }

/// Landing screen for the HTTPS App Link `/tickets/{booking_guid}` (the e-ticket email link).
///
/// The link only names a booking. This screen needs a signed-in visitor, loads the booking from the
/// server (which decides ownership) and then shows the normal booking ticket screen. A 403 or 404
/// is shown as one neutral message so nothing about the booking is revealed.
class TicketLinkScreen extends StatefulWidget {
  const TicketLinkScreen(
      {super.key, required this.bookingGuid, required this.repository});
  final String bookingGuid;
  final BusinessRepository repository;

  @override
  State<TicketLinkScreen> createState() => _TicketLinkScreenState();
}

class _TicketLinkScreenState extends State<TicketLinkScreen> {
  _LinkState _state = _LinkState.resolving;
  Booking? _booking;
  int _request = 0;
  late int _generation;

  @override
  void initState() {
    super.initState();
    final session = widget.repository.api.session;
    _generation = session.sessionGeneration;
    session.sessionChanges.addListener(_sessionChanged);
    _resolve();
  }

  bool get _signedIn {
    final session = widget.repository.api.session;
    return session.authenticated.value &&
        session.deviceSessionReady &&
        session.role == 0;
  }

  void _sessionChanged() {
    if (!mounted) return;
    final generation = widget.repository.api.session.sessionGeneration;
    if (generation == _generation && _state != _LinkState.needsLogin) return;
    _generation = generation;
    _resolve();
  }

  Future<void> _resolve() async {
    final request = ++_request;
    _booking = null;
    if (!_signedIn) {
      // Continue to this ticket after the next sign-in (see MainNavigationScreen).
      PendingTicketLink.remember(widget.bookingGuid);
      if (mounted) setState(() => _state = _LinkState.needsLogin);
      return;
    }
    if (mounted) setState(() => _state = _LinkState.resolving);
    final generation = widget.repository.api.session.sessionGeneration;
    _LinkState result;
    Booking? booking;
    try {
      booking = await widget.repository.booking(widget.bookingGuid);
      result = booking.guid.toLowerCase() == widget.bookingGuid
          ? _LinkState.ready
          : _LinkState.notFound;
    } on ApiException catch (e) {
      result = e.status == 403 || e.status == 404
          ? _LinkState.notFound
          : _LinkState.failed;
    } catch (_) {
      result = _LinkState.failed;
    }
    if (!mounted ||
        request != _request ||
        !widget.repository.api.session.isCurrentGeneration(generation)) {
      return;
    }
    setState(() {
      _state = result;
      _booking = result == _LinkState.ready ? booking : null;
    });
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

  void _login() {
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const UserLoginScreen()),
        (_) => false);
  }

  @override
  void dispose() {
    ++_request;
    widget.repository.api.session.sessionChanges
        .removeListener(_sessionChanged);
    super.dispose();
  }

  Widget _panel(String key, IconData icon, String title, String body,
          List<Widget> actions, {Color color = AppColors.blueDeep}) =>
      Container(
          key: Key(key),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Icon(icon, size: 44, color: color),
            const SizedBox(height: AppSpacing.md),
            Semantics(
                header: true,
                liveRegion: true,
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy))),
            const SizedBox(height: AppSpacing.sm),
            Text(body,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: AppColors.textSecondary)),
            ...actions,
          ]));

  Widget _button(String text, VoidCallback onPressed,
          {required Key key, bool primary = true}) =>
      Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
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
                  child: Text(text, textAlign: TextAlign.center)));

  Widget _content() => switch (_state) {
        _LinkState.resolving => _panel(
              'ticket-link-resolving',
              PhosphorIconsRegular.hourglassHigh,
              'Memuat Tiket',
              'Kami sedang memeriksa tiket Anda ke server. Mohon tunggu.',
              const [
                Padding(
                    padding: EdgeInsets.only(top: AppSpacing.lg),
                    child: LinearProgressIndicator())
              ]),
        _LinkState.needsLogin => _panel(
              'ticket-link-needs-login',
              PhosphorIconsRegular.lock,
              'Masuk untuk Melihat Tiket',
              'Masuk dengan akun pengunjung yang memesan tiket ini. Setelah masuk, Anda diarahkan ke tiket tersebut.',
              [
                if (!widget.repository.api.session.authenticated.value)
                  _button('Masuk', _login, key: const Key('ticket-link-login')),
                _button('Coba Lagi', _resolve,
                    primary: false, key: const Key('ticket-link-retry-login')),
              ]),
        _LinkState.notFound => _panel(
            'ticket-link-not-found',
            PhosphorIconsRegular.warningCircle,
            'Tiket tidak ditemukan atau bukan milik akun ini',
            'Periksa bahwa Anda masuk dengan akun yang dipakai untuk memesan, lalu buka kembali tautan dari email.',
            [
              _button('Kembali', _back,
                  primary: false, key: const Key('ticket-link-back'))
            ],
            color: AppColors.warningText),
        _LinkState.failed => _panel(
            'ticket-link-failed',
            PhosphorIconsRegular.warningCircle,
            'Tiket belum dapat dimuat',
            'Koneksi atau layanan bermasalah. Tiket Anda tidak berubah. Coba lagi.',
            [
              _button('Coba Lagi', _resolve,
                  key: const Key('ticket-link-retry')),
              _button('Kembali', _back,
                  primary: false, key: const Key('ticket-link-back'))
            ],
            color: AppColors.warningText),
        _LinkState.ready => const SizedBox.shrink(),
      };

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    if (_state == _LinkState.ready && booking != null) {
      return BookingTicketScreen(
          bookingGuid: booking.guid,
          repository: widget.repository,
          preloaded: booking);
    }
    return Theme(
        data: AppColors.visitorTheme,
        child: Scaffold(
            backgroundColor: AppColors.bg,
            appBar: AppBar(title: const Text('Tiket')),
            body: SafeArea(
                child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [_content()]))));
  }
}

/// `MaterialApp.onGenerateRoute` hook for the `/tickets/{uuid}` App Link (cold and warm start).
/// Returns null for every other route, and for any link that is not a strict ticket link.
Route<dynamic>? ticketLinkRoute(RouteSettings settings,
    {BusinessRepository Function()? repository}) {
  final link = TicketLink.parse(settings.name);
  if (link == null) return null;
  return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => TicketLinkScreen(
          bookingGuid: link.bookingGuid,
          repository:
              repository == null ? BusinessRepository() : repository()));
}
