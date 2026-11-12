import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/business_repository.dart';
import '../../data/ticket_scanner_state.dart';
import '../../theme/app_colors.dart';

Future<void> showAdminTicketScannerSheet(BuildContext context,
    {required BusinessRepository repository, WidgetBuilder? builder}) {
  final theme = AppColors.operationsTheme;
  return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Theme(
          data: theme.copyWith(
              filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      textStyle: theme.textTheme.labelLarge,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)))),
              outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.blue,
                      minimumSize: const Size(48, 48),
                      textStyle: theme.textTheme.labelLarge,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))))),
          child: builder?.call(context) ??
              AdminTicketScannerScreen(repository: repository)));
}

class AdminTicketScannerScreen extends StatefulWidget {
  const AdminTicketScannerScreen({super.key, this.repository});
  final BusinessRepository? repository;
  @override
  State<AdminTicketScannerScreen> createState() =>
      _AdminTicketScannerScreenState();
}

class _AdminTicketScannerScreenState extends State<AdminTicketScannerScreen>
    with WidgetsBindingObserver {
  final _camera = MobileScannerController(
      autoStart: false, formats: const [BarcodeFormat.qrCode]);
  late final TicketScannerState _state;
  bool _captured = false;
  bool _foreground = true;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    _state = TicketScannerState(widget.repository ?? BusinessRepository())
      ..addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _state.loadScope();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (!_state.valid) _stop();
    if (_state.canScan && !_state.hasCapture && _state.result == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  Future<void> _stop() async {
    try {
      await _camera.stop();
    } catch (_) {}
  }

  Future<void> _start() async {
    if (!_foreground ||
        !_state.canScan ||
        _state.hasCapture ||
        _state.result != null ||
        _camera.value.isRunning ||
        _camera.value.isStarting ||
        !mounted) {
      return;
    }
    try {
      await _camera.start();
      if (mounted) setState(() => _cameraError = null);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _cameraError = 'Kamera tidak dapat dibuka. Periksa izin kamera.');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      if (_camera.value.hasCameraPermission) _stop();
    } else if (_camera.value.hasCameraPermission ||
        _camera.value.error != null) {
      _start();
    }
  }

  Future<void> _detect(BarcodeCapture capture) async {
    if (_captured || !_state.canScan || !_foreground) return;
    final payload =
        capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (payload == null) return;
    _captured = true;
    await _stop();
    if (mounted && _foreground) {
      await _state.capture(payload);
    } else {
      _captured = false;
    }
  }

  void _rescan() {
    if (_state.loading || _state.confirmUncertain) return;
    _captured = false;
    // _changed restarts the camera after MobileScanner is mounted again.
    _state.reset();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.removeListener(_changed);
    _state.dispose();
    _camera.dispose();
    super.dispose();
  }

  bool get _canClose =>
      !_state.valid ||
      (!_state.confirmUncertain && !(_state.loading && _state.preview != null));

  @override
  Widget build(BuildContext context) {
    final textTheme = AppColors.operationsTheme.textTheme;
    return PopScope(
        canPop: _canClose,
        child: DefaultTextStyle(
            style: textTheme.bodyMedium!.copyWith(color: AppColors.navy),
            child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 0, 16,
                        MediaQuery.viewInsetsOf(context).bottom + 16),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text('Scan Tiket QR',
                                    style: textTheme.titleMedium!.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold))),
                            IconButton(
                                tooltip: 'Tutup scanner',
                                onPressed: _canClose
                                    ? () => Navigator.of(context).pop()
                                    : null,
                                style: IconButton.styleFrom(
                                    foregroundColor: AppColors.textMuted,
                                    backgroundColor: AppColors.bg,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                icon: const Icon(PhosphorIconsRegular.x,
                                    size: 20)),
                          ]),
                          const SizedBox(height: 8),
                          const Text(
                              'Arahkan kamera ke QR tiket pengunjung untuk memverifikasi tiket.',
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: AppColors.textMuted)),
                          const SizedBox(height: 24),
                          if (!_state.valid)
                            const Text('Sesi berubah. Silakan masuk kembali.')
                          else
                            _body(),
                        ])))));
  }

  Widget _body() {
    if (_state.scope == null ||
        (!_state.loading &&
            (_state.scope!['destinations'] as List? ?? []).isEmpty &&
            _state.scope!['global'] != true)) {
      return SizedBox(
          height: 180,
          child: RefreshIndicator(
              onRefresh: _state.loadScope,
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (_state.loading)
                      const Center(child: CircularProgressIndicator()),
                    if (_state.error != null)
                      Text(_state.error!, textAlign: TextAlign.center)
                    else if (!_state.loading)
                      const Text(
                          'Belum ditugaskan ke destinasi. Hubungi Superadmin untuk penugasan scanner.',
                          textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    const Text('Tarik turun untuk menyinkronkan penugasan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ])));
    }
    final preview = _state.preview;
    final result = _state.result;
    if (_state.hasCapture || result != null) {
      return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result != null) ...[
              Semantics(
                  liveRegion: true,
                  child: const Column(children: [
                    Icon(PhosphorIconsRegular.checkCircle,
                        size: 48, color: AppColors.success),
                    SizedBox(height: 16),
                    Text('Check-in berhasil',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ])),
              const SizedBox(height: 12),
              Text(
                  'Tiket ${result['sequence'] ?? '—'} dari ${result['quantity'] ?? '—'} berhasil tercatat.',
                  textAlign: TextAlign.center),
              Text(
                  '${result['checked_in_count'] ?? '—'}/${result['quantity'] ?? '—'} tiket sudah check-in',
                  textAlign: TextAlign.center),
              if (result['checked_in_at'] != null)
                Text('Waktu check-in: ${result['checked_in_at']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
            ] else if (preview != null) ...[
              Semantics(
                  liveRegion: true,
                  child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.successTint,
                          border: Border.all(
                              color: AppColors.success.withValues(alpha: .2)),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(PhosphorIconsRegular.shieldCheck,
                            size: 20, color: AppColors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                preview['check_in_status'] == 'not_checked_in'
                                    ? 'QR terverifikasi · belum check-in'
                                    : 'QR terverifikasi',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.success))),
                      ]))),
              const SizedBox(height: 12),
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${preview['destination_name'] ?? 'Destinasi'}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        for (final detail in [
                          (
                            'Pemegang tiket',
                            '${preview['booker_name'] ?? '—'}'
                          ),
                          (
                            'Jadwal',
                            '${preview['visit_date'] ?? '—'} (${preview['timezone'] ?? '—'})'
                          ),
                          ('Nomor tiket', '${preview['ticket_guid'] ?? '—'}'),
                        ]) ...[
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                        child: Text(detail.$1,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textMuted))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(detail.$2,
                                            textAlign: TextAlign.end,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600))),
                                  ])),
                          if (detail.$1 != 'Nomor tiket')
                            const Divider(height: 1, color: AppColors.border),
                        ],
                      ])),
            ],
            if (_state.loading)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator())),
            if (_state.error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child:
                      Semantics(liveRegion: true, child: Text(_state.error!))),
            if (preview != null && result == null) ...[
              const SizedBox(height: 12),
              FilledButton(
                  key: const ValueKey('scanner-confirm-check-in'),
                  onPressed: _state.canConfirm ? _state.confirm : null,
                  child: Text(_state.confirmUncertain
                      ? 'Coba Konfirmasi Lagi'
                      : 'Konfirmasi Check-in')),
            ],
            if (preview == null && result == null && !_state.loading)
              FilledButton(
                  onPressed: _state.retryPreview,
                  child: const Text('Coba verifikasi lagi')),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed:
                    _state.loading || _state.confirmUncertain ? null : _rescan,
                child: Text(
                    result == null ? 'Scan ulang' : 'Scan tiket berikutnya')),
          ]);
    }
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                  height: 180,
                  child: Stack(fit: StackFit.expand, children: [
                    ColoredBox(
                        color: AppColors.navy,
                        child: MobileScanner(
                            controller: _camera,
                            onDetect: _detect,
                            errorBuilder: (_, error) => _permissionError())),
                    IgnorePointer(
                        child: Center(
                            child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                    border: Border.all(
                                        color: AppColors.surface, width: 2),
                                    borderRadius: BorderRadius.circular(16))))),
                  ]))),
          const SizedBox(height: 12),
          const Text(
              'Posisikan QR di dalam bingkai. Internet diperlukan untuk verifikasi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, height: 1.5, color: AppColors.textMuted)),
          if (_cameraError != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_cameraError!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: _start, child: const Text('Aktifkan kamera'))),
            const SizedBox(width: 8),
            ValueListenableBuilder<MobileScannerState>(
                valueListenable: _camera,
                builder: (_, value, __) => IconButton(
                    tooltip: 'Lampu kamera',
                    onPressed: value.isRunning &&
                            value.torchState != TorchState.unavailable
                        ? _camera.toggleTorch
                        : null,
                    icon: Icon(value.torchState == TorchState.on
                        ? PhosphorIconsFill.flashlight
                        : PhosphorIconsRegular.lightningSlash))),
          ]),
        ]);
  }

  Widget _permissionError() => DefaultTextStyle(
      style: AppColors.operationsTheme.textTheme.bodySmall!
          .copyWith(color: AppColors.surface),
      child: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Izinkan akses kamera untuk memindai QR tiket.',
                    textAlign: TextAlign.center),
                TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.surface),
                    onPressed: () async {
                      await Geolocator.openAppSettings();
                    },
                    child: const Text('Buka Pengaturan')),
                TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.surface),
                    onPressed: _start,
                    child: const Text('Coba lagi')),
              ]))));
}
