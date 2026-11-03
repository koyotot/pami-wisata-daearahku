import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/business_repository.dart';
import '../data/ticket_scanner_state.dart';
import '../theme/app_colors.dart';

class AdminTicketScannerScreen extends StatefulWidget {
  const AdminTicketScannerScreen({super.key});
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
    _state = TicketScannerState(BusinessRepository())..addListener(_changed);
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

  Future<void> _rescan() async {
    _state.reset();
    if (_state.confirmUncertain) return;
    _captured = false;
    await _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.removeListener(_changed);
    _state.dispose();
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: AppColors.visitorTheme,
        child: Scaffold(
          appBar: AppBar(title: const Text('Scan Tiket'), actions: [
            ValueListenableBuilder<MobileScannerState>(
                valueListenable: _camera,
                builder: (_, value, __) => IconButton(
                      tooltip: 'Lampu kamera',
                      onPressed: value.isRunning &&
                              value.torchState != TorchState.unavailable
                          ? _camera.toggleTorch
                          : null,
                      icon: Icon(value.torchState == TorchState.on
                          ? Icons.flash_on
                          : Icons.flash_off),
                    )),
          ]),
          body: SafeArea(
              child: !_state.valid
                  ? const Center(
                      child: Text('Sesi berubah. Silakan masuk kembali.'))
                  : _body()),
        ));
  }

  Widget _body() {
    if (_state.scope == null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_state.loading) const CircularProgressIndicator(),
        if (_state.error != null)
          Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_state.error!, textAlign: TextAlign.center)),
        if (!_state.loading)
          TextButton(
              onPressed: _state.loadScope, child: const Text('Coba lagi')),
      ]));
    }
    if (!_state.canScan &&
        !_state.loading &&
        (_state.scope!['destinations'] as List? ?? []).isEmpty &&
        _state.scope!['global'] != true) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'Belum ditugaskan ke destinasi. Hubungi Superadmin untuk penugasan scanner.',
                  textAlign: TextAlign.center)));
    }
    final preview = _state.preview;
    final result = _state.result;
    if (_state.hasCapture || result != null) {
      return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (result != null) ...[
              const Icon(Icons.check_circle, size: 64, color: AppColors.blue),
              const SizedBox(height: 16),
              const Text('Check-in Berhasil',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(
                  'Tiket ${result['sequence']} dari ${result['quantity']} berhasil tercatat.'),
              Text(
                  '${result['checked_in_count']}/${result['quantity']} tiket sudah check-in'),
              Text('Waktu server: ${result['checked_in_at']}'),
            ] else ...[
              const Text('Preview Tiket',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              if (preview != null) ...[
                const SizedBox(height: 16),
                Text('${preview['destination_name']}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Text(
                    'Tanggal: ${preview['visit_date']} (${preview['timezone']})'),
                Text(
                    'Tiket: ${preview['sequence']} dari ${preview['quantity']}'),
                Text('Nama pemesan: ${preview['booker_name']}'),
                Text(
                    'Pembayaran: ${preview['payment_status'] == 'paid' ? 'Lunas' : 'Belum terverifikasi'}'),
                Text(
                    'Booking: ${preview['booking_status'] == 'confirmed' ? 'Disetujui' : 'Belum disetujui'}'),
                Text(
                    'Status: ${preview['check_in_status'] == 'checked_in' ? 'Sudah check-in' : 'Belum check-in'}'),
              ],
              if (_state.loading)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator())),
            ],
            if (_state.error != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(_state.error!,
                      style: const TextStyle(color: Colors.red))),
            if (preview != null && result == null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: _state.canConfirm ? _state.confirm : null,
                  child: Text(_state.confirmUncertain
                      ? 'Coba Konfirmasi Lagi'
                      : 'Konfirmasi Check-in')),
            ],
            if (preview == null && result == null && !_state.loading)
              TextButton(
                  onPressed: _state.retryPreview,
                  child: const Text('Coba lagi')),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed:
                    _state.loading || _state.confirmUncertain ? null : _rescan,
                child: Text(
                    result == null ? 'Scan Ulang' : 'Scan Tiket Berikutnya')),
          ]));
    }
    return Column(children: [
      const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
              'Arahkan kamera ke QR tiket pengunjung. Internet diperlukan untuk memverifikasi tiket.')),
      Expanded(
          child: ClipRect(
              child: MobileScanner(
                  controller: _camera,
                  onDetect: _detect,
                  errorBuilder: (_, error) => _permissionError()))),
      if (_cameraError != null)
        Padding(padding: const EdgeInsets.all(12), child: Text(_cameraError!)),
      Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
              onPressed: _start, child: const Text('Aktifkan Kamera'))),
    ]);
  }

  Widget _permissionError() => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Izinkan akses kamera untuk memindai QR tiket.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center),
            TextButton(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                },
                child: const Text('Buka Pengaturan')),
            TextButton(onPressed: _start, child: const Text('Coba lagi')),
          ])));
}
