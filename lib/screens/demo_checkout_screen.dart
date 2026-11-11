import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../data/booking_state.dart';
import '../data/business_repository.dart';
import '../data/demo_payment_state.dart';
import '../theme/app_colors.dart';
import '../widgets/booking_ticket_qr_section.dart';
import '../widgets/payment_deadline.dart';
import 'auth_presentation.dart';
import 'main_navigation_screen.dart';

class DemoCheckoutScreen extends StatefulWidget {
  const DemoCheckoutScreen(
      {super.key, required this.bookingGuid, required this.repository});
  final String bookingGuid;
  final BusinessRepository repository;
  @override
  State<DemoCheckoutScreen> createState() => _DemoCheckoutScreenState();
}

class _DemoCheckoutScreenState extends State<DemoCheckoutScreen>
    with WidgetsBindingObserver {
  late final _payment = DemoPaymentState(widget.repository, widget.bookingGuid);
  String _outcome = 'success';
  bool _checkout = false;
  bool _tickets = false;
  bool _recovery = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _payment.addListener(_changed);
    _payment.recover();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _recovery = true;
        _tickets = false;
      });
      _payment.recover();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _payment.removeListener(_changed);
    _payment.dispose();
    super.dispose();
  }

  Future<void> _recover() async {
    setState(() {
      _recovery = true;
      _checkout = false;
      _tickets = false;
    });
    await _payment.recover();
  }

  String _money(Booking b) {
    final value = b.totalAmount
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return b.currency == 'IDR' ? 'Rp$value' : '${b.currency} $value';
  }

  Widget _panel(List<Widget> children) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
  Widget _line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF526787)))),
        const SizedBox(width: 12),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700))),
      ]));
  Widget _action(String text, VoidCallback? action, {bool primary = true}) =>
      Padding(
          padding: const EdgeInsets.only(top: 10),
          child: primary
              ? ElevatedButton(onPressed: action, child: Text(text))
              : OutlinedButton(onPressed: action, child: Text(text)));

  @override
  Widget build(BuildContext context) {
    final p = _payment;
    final b = p.booking;
    final terminal =
        const ['failed', 'expired'].contains(p.intent?.attemptStatus);
    final showResult = !_checkout && terminal;
    final title = _tickets
        ? 'Detail Tiket'
        : p.paid
            ? 'Pembayaran Berhasil'
            : showResult
                ? (p.intent?.attemptStatus == 'expired'
                    ? 'Attempt Kedaluwarsa'
                    : 'Pembayaran Gagal')
                : _recovery || p.needsRecovery
                    ? 'Pemulihan Pembayaran'
                    : p.pending
                        ? 'Pembayaran Diproses'
                        : 'Pembayaran DEMO';
    return Theme(
        data: AppColors.visitorTheme,
        child: Scaffold(
            backgroundColor: AppColors.bg,
            body: SafeArea(
                top: false,
                child: RefreshIndicator(
                    onRefresh: _recover,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: [
                          TimeBasedScenicBackground(
                              active: true,
                              child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                      12,
                                      MediaQuery.paddingOf(context).top + 8,
                                      20,
                                      24),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          BackButton(color: Colors.white),
                                          const Expanded(
                                              child: Text('WISATA DAERAHKU',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors.white)))
                                        ]),
                                        Padding(
                                            padding: const EdgeInsets.only(
                                                left: 8, top: 16),
                                            child: Text(title,
                                                style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white))),
                                        const Padding(
                                            padding: EdgeInsets.only(
                                                left: 8, top: 6),
                                            child: Text(
                                                'Simulasi pembayaran · tanpa transfer dana',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white))),
                                      ]))),
                          Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 18, 20, 28),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text('DEMO / TEST_ONLY',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.blueDeep,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 12),
                                    if (!p.valid)
                                      _panel([
                                        const Text(
                                            'Sesi berubah. Buka kembali pembayaran dari akun pemilik booking.')
                                      ])
                                    else ...[
                                      if (p.busy)
                                        const LinearProgressIndicator(),
                                      if (p.busy && b == null)
                                        _panel([
                                          const Text(
                                              'Memuat tagihan & status pembayaran…'),
                                          const SizedBox(height: 12),
                                          Container(
                                              height: 32, color: AppColors.bg),
                                          const SizedBox(height: 12),
                                          Container(
                                              height: 16, color: AppColors.bg),
                                        ]),
                                      if (p.error != null)
                                        _panel([
                                          Text(p.error!,
                                              style: const TextStyle(
                                                  color: Color(0xFF9C493D))),
                                          _action('Periksa status terbaru',
                                              p.busy ? null : _recover,
                                              primary: false),
                                        ]),
                                      if (!p.reconciled &&
                                          !p.busy &&
                                          p.error == null)
                                        _panel([
                                          const Text(
                                              'Status pembayaran belum pasti.'),
                                          _action('Pulihkan status', _recover)
                                        ]),
                                      if (b != null && p.reconciled) ...[
                                        if (_tickets && p.paid) ...[
                                          _panel([
                                            Text(b.destinationName,
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            _line('Booking', b.bookingNumber),
                                            _line('Kunjungan', b.visitDate),
                                            const Text(
                                                'DEMO / TEST_ONLY · bukan bukti pembayaran uang nyata.'),
                                            BookingTicketQrSection(
                                                repository: widget.repository,
                                                bookingGuid: b.guid,
                                                onRefreshed: p.recover),
                                            const SizedBox(height: 10),
                                            const Text(
                                                'QR mengikuti H-5 menurut waktu destinasi. Check-in hanya pada hari kunjungan.'),
                                          ]),
                                        ] else if (p.paid) ...[
                                          _statePanel(
                                              PhosphorIconsRegular.checkCircle,
                                              'Pembayaran DEMO Berhasil!',
                                              'Pembayaran simulasi telah dicatat Laravel. Booking dikonfirmasi.',
                                              const Color(0xFF16784C)),
                                          _panel([
                                            _line('Nomor booking',
                                                b.bookingNumber),
                                            _line('Total DEMO', _money(b)),
                                            _line('Booking',
                                                bookingStatusLabel(b.status)),
                                            _line('Pembayaran', b.paymentStatus)
                                          ]),
                                          _action(
                                              'Lihat Tiket Kunjungan',
                                              p.busy
                                                  ? null
                                                  : () => setState(() {
                                                        _tickets = true;
                                                        _recovery = false;
                                                      })),
                                          _action(
                                              'Kembali ke Riwayat',
                                              () => MainNavigationScreen
                                                  .returnToTab(context, 1),
                                              primary: false),
                                        ] else if (showResult) ...[
                                          _statePanel(
                                              p.intent?.attemptStatus ==
                                                      'expired'
                                                  ? PhosphorIconsRegular.timer
                                                  : PhosphorIconsRegular
                                                      .warningCircle,
                                              p.intent?.attemptStatus ==
                                                      'expired'
                                                  ? 'Attempt DEMO Kedaluwarsa'
                                                  : 'Pembayaran DEMO Gagal',
                                              'Percobaan ini berakhir. Status booking mengikuti server; batas pembayaran tidak bertambah.',
                                              const Color(0xFF9C493D)),
                                          _panel([
                                            _line('Nomor booking',
                                                b.bookingNumber),
                                            _line('Booking',
                                                bookingStatusLabel(b.status)),
                                            _line('Attempt',
                                                p.intent!.attemptStatus!),
                                            _line('Total', _money(b))
                                          ]),
                                          PaymentDeadline(
                                              expiresAt: b.paymentExpiresAt,
                                              serverTime:
                                                  p.intent?.serverTime ??
                                                      p.methods?.serverTime,
                                              onElapsed: p.recover),
                                          _action(
                                              'Coba Lagi (DEMO)',
                                              p.canStart && !p.busy
                                                  ? () => setState(() {
                                                        _checkout = true;
                                                        _recovery = false;
                                                      })
                                                  : null),
                                          if (!p.canPay)
                                            Text(p.methods?.reason ??
                                                'Pembayaran belum tersedia.'),
                                        ] else ...[
                                          if (_recovery || p.needsRecovery)
                                            _panel([
                                              const Text(
                                                  'Status terbaru dari Laravel',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              _line('Intent',
                                                  p.intent!.intentStatus),
                                              _line(
                                                  'Attempt',
                                                  p.intent!.attemptStatus ??
                                                      'Belum dibuat'),
                                              Text(p.needsRecovery
                                                  ? 'Hasil pembayaran belum dapat dipastikan. Periksa status kembali; tidak ada percobaan baru yang dibuat.'
                                                  : p.pending
                                                      ? 'Lanjutkan dengan attempt yang sama. Tidak perlu membuat percobaan baru.'
                                                      : 'Belum ada pembayaran yang dikonfirmasi. Kelayakan mengikuti status terbaru server.'),
                                            ]),
                                          Container(
                                              padding: const EdgeInsets.all(20),
                                              margin: const EdgeInsets.only(
                                                  bottom: 12),
                                              decoration: BoxDecoration(
                                                  color: AppColors.blueDeep,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          18)),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                        'Total tagihan DEMO',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.white)),
                                                    const SizedBox(height: 8),
                                                    Text(_money(b),
                                                        style: const TextStyle(
                                                            fontSize: 32,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            fontFeatures: [
                                                              FontFeature
                                                                  .tabularFigures()
                                                            ],
                                                            color:
                                                                Colors.white)),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                        '${b.bookingNumber} · ${b.quantity} tiket',
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white)),
                                                  ])),
                                          PaymentDeadline(
                                              expiresAt: b.paymentExpiresAt,
                                              serverTime:
                                                  p.intent?.serverTime ??
                                                      p.methods?.serverTime,
                                              onElapsed: p.recover),
                                          const SizedBox(height: 12),
                                          _panel([
                                            Text(b.destinationName,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            _line('Kunjungan', b.visitDate),
                                            _line('Booking',
                                                bookingStatusLabel(b.status)),
                                            if (p.pending) ...[
                                              _line('Intent',
                                                  p.intent!.intentStatus),
                                              _line('Attempt',
                                                  p.intent!.attemptStatus!)
                                            ],
                                            const Text(
                                                'Invoice adalah konfirmasi booking, bukan tanda terima pembayaran.')
                                          ]),
                                          if (p.needsRecovery) ...[
                                            _statePanel(
                                                PhosphorIconsRegular
                                                    .arrowsClockwise,
                                                'Status pembayaran belum pasti',
                                                'Pulihkan status sebelum melanjutkan. Tidak ada pembayaran yang diulang otomatis.',
                                                AppColors.blueDeep),
                                          ] else if (p.canPay) ...[
                                            _panel([
                                              const ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  leading: Icon(
                                                      PhosphorIconsRegular
                                                          .wallet,
                                                      color: AppColors.blue),
                                                  title: Text(
                                                      'Dompet Digital · DEMO',
                                                      style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w700)),
                                                  subtitle: Text(
                                                      'Simulator Laravel · tanpa uang nyata'),
                                                  trailing: Icon(
                                                      PhosphorIconsRegular
                                                          .checkCircle)),
                                            ]),
                                            _panel([
                                              ExpansionTile(
                                                  trailing: Builder(
                                                      builder: (context) {
                                                    final controller =
                                                        ExpansibleController.of(
                                                            context);
                                                    final animation =
                                                        ExpansionTileTheme.of(
                                                                context)
                                                            .expansionAnimationStyle;
                                                    return ListenableBuilder(
                                                        listenable: controller,
                                                        builder: (context, _) => AnimatedRotation(
                                                            turns: controller
                                                                    .isExpanded
                                                                ? .5
                                                                : 0,
                                                            duration: animation
                                                                    ?.duration ??
                                                                const Duration(
                                                                    milliseconds:
                                                                        200),
                                                            curve: animation
                                                                    ?.curve ??
                                                                Curves.easeIn,
                                                            child: const Icon(
                                                                PhosphorIconsRegular
                                                                    .caretDown)));
                                                  }),
                                                  title: const Text(
                                                      'Skenario Simulasi',
                                                      style: TextStyle(
                                                          fontSize: 13)),
                                                  tilePadding: EdgeInsets.zero,
                                                  children: [
                                                    for (final option in [
                                                      (
                                                        'success',
                                                        'Berhasil · default'
                                                      ),
                                                      ('failed', 'Gagal'),
                                                      (
                                                        'expired',
                                                        'Attempt kedaluwarsa'
                                                      )
                                                    ])
                                                      RadioListTile<String>(
                                                          title:
                                                              Text(option.$2),
                                                          value: option.$1,
                                                          groupValue:
                                                              p.lockedOutcome ??
                                                                  _outcome,
                                                          onChanged: p.busy ||
                                                                  p.operation !=
                                                                      null
                                                              ? null
                                                              : (v) => setState(
                                                                  () =>
                                                                      _outcome =
                                                                          v!)),
                                                  ])
                                            ]),
                                            if (p.pending)
                                              _statePanel(
                                                  PhosphorIconsRegular
                                                      .hourglassHigh,
                                                  'Attempt DEMO siap diproses',
                                                  'Lanjutkan simulasi dengan attempt yang sama dari server.',
                                                  AppColors.blueDeep),
                                            _action(
                                                p.pending
                                                    ? 'Tampilkan hasil simulasi (DEMO)'
                                                    : 'Bayar Sekarang (DEMO)',
                                                p.busy ||
                                                        (!p.pending &&
                                                            !p.canStart)
                                                    ? null
                                                    : () async {
                                                        setState(() {
                                                          _checkout = false;
                                                          _recovery = false;
                                                        });
                                                        await p.submit(
                                                            outcome: p.pending
                                                                ? p.lockedOutcome ??
                                                                    _outcome
                                                                : null);
                                                      }),
                                          ] else ...[
                                            _statePanel(
                                                PhosphorIconsRegular.lock,
                                                'Pembayaran Belum Tersedia',
                                                p.methods?.reason ??
                                                    'Status pembayaran perlu diperiksa kembali.',
                                                AppColors.textMuted),
                                            _action(
                                                'Bayar Sekarang (DEMO)', null),
                                          ],
                                        ],
                                        _action(
                                            'Cek Status / Pulihkan Pembayaran',
                                            p.busy ? null : _recover,
                                            primary: false),
                                        _action('Kembali ke Detail Booking',
                                            () => Navigator.maybePop(context),
                                            primary: false),
                                      ],
                                    ],
                                    const SizedBox(height: 14),
                                    const Text(
                                        'DEMO / TEST_ONLY · Tidak ada transaksi uang nyata.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF526787))),
                                  ])),
                        ])))));
  }

  Widget _statePanel(IconData icon, String title, String text, Color color) =>
      _panel([
        Icon(icon, size: 44, color: color),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.navy)),
        const SizedBox(height: 8),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, height: 1.6, color: Color(0xFF526787))),
      ]);
}
