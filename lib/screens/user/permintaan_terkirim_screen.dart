import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter/services.dart';

import '../../data/booking_state.dart';
import '../../data/business_repository.dart';
import '../../services/auth_session.dart';
import '../../theme/app_colors.dart';
import 'main_navigation_screen.dart';

class PermintaanTerkirimScreen extends StatefulWidget {
  const PermintaanTerkirimScreen({
    super.key,
    required this.booking,
    this.session,
    this.sessionGeneration,
  });

  final Booking booking;
  final AuthSession? session;
  final int? sessionGeneration;

  @override
  State<PermintaanTerkirimScreen> createState() =>
      _PermintaanTerkirimScreenState();
}

class _PermintaanTerkirimScreenState extends State<PermintaanTerkirimScreen> {
  late final _session = widget.session ?? AuthSession.instance;
  late final int _generation;
  bool _invalidSession = false;

  @override
  void initState() {
    super.initState();
    _generation = widget.sessionGeneration ?? _session.sessionGeneration;
    _invalidSession = !_sameSession;
    if (_invalidSession) _leaveInvalidSession();
    _session.sessionChanges.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!mounted) return;
    if (!_sameSession) {
      setState(() => _invalidSession = true);
      _leaveInvalidSession();
    }
  }

  bool get _sameSession =>
      _session.sessionGeneration == _generation &&
      _session.authenticated.value &&
      _session.deviceSessionReady &&
      _session.role == 0;

  void _leaveInvalidSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) MainNavigationScreen.returnToTab(context, 0);
    });
  }

  @override
  void dispose() {
    _session.sessionChanges.removeListener(_sessionChanged);
    super.dispose();
  }

  void _openTab(int index) => MainNavigationScreen.returnToTab(context, index);

  @override
  Widget build(BuildContext context) {
    if (_invalidSession) {
      return const Scaffold(backgroundColor: AppColors.bg);
    }
    final booking = widget.booking;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _openTab(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppColors.navy,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          title: const Text('Permintaan Terkirim',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                children: [
                  const Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: Color(0xFFE4F5EB)),
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: Icon(PhosphorIconsRegular.check,
                            size: 48, color: Color(0xFF238653)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Pendaftaran tercatat!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy)),
                  const SizedBox(height: 12),
                  const Text(
                    'Permintaan kunjungan berhasil diterima. Pantau status pendaftaranmu melalui Riwayat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14, height: 1.6, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(booking.destinationName,
                            style: const TextStyle(
                                color: AppColors.navy,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 16),
                        _summary('Tanggal kunjungan', booking.visitDate),
                        const SizedBox(height: 12),
                        _summary(
                            'Jumlah pengunjung', '${booking.quantity} orang'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(
                              'Status: ${bookingStatusLabel(booking.status)}',
                              key: const ValueKey('bookingStatus'),
                              style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (booking.bookingNumber.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Nomor: ${booking.bookingNumber}',
                              key: const ValueKey('bookingNumber'),
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    key: const ValueKey('successHistory'),
                    onPressed: () => _openTab(1),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    child: const Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      children: [
                        Text('Lihat Riwayat'),
                        Icon(PhosphorIconsRegular.arrowRight, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const ValueKey('successHome'),
                    onPressed: () => _openTab(0),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blue,
                        side: const BorderSide(color: AppColors.blue),
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    child: const Text('Kembali ke Beranda',
                        textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontSize: 14, color: AppColors.navy)),
        ],
      );
}
