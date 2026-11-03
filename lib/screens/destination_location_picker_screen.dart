import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../data/business_repository.dart';
import '../services/auth_session.dart';
import '../widgets/destination_location_map_preview.dart';

class DestinationLocationDraft {
  final LatLng point;
  final String address;
  const DestinationLocationDraft(this.point, this.address);
}

class DestinationLocationPickerScreen extends StatefulWidget {
  final LatLng? initialPoint;
  final String initialAddress;
  final BusinessRepository repository;
  final AuthSession session;
  const DestinationLocationPickerScreen(
      {super.key,
      this.initialPoint,
      required this.initialAddress,
      required this.repository,
      required this.session});

  @override
  State<DestinationLocationPickerScreen> createState() =>
      _DestinationLocationPickerScreenState();
}

class _DestinationLocationPickerScreenState
    extends State<DestinationLocationPickerScreen> {
  final _map = MapController();
  late final _address = TextEditingController(text: widget.initialAddress);
  late LatLng? _point = widget.initialPoint;
  late final _sessionGeneration = widget.session.sessionGeneration;
  Timer? _debounce;
  int _requestGeneration = 0;
  bool _manualAddress = false, _findingAddress = false, _findingGps = false;
  bool _sessionRejected = false;
  String? _notice;

  bool get _currentSession =>
      widget.session.isCurrentGeneration(_sessionGeneration) &&
      (widget.session.role ?? 0) >= 1;

  void _selectPoint(LatLng point) {
    if (!_currentSession || _sessionRejected) return;
    if (!point.latitude.isFinite ||
        !point.longitude.isFinite ||
        point.latitude.abs() > 90 ||
        point.longitude.abs() > 180) {
      return;
    }
    if (_point == point) return;
    _debounce?.cancel();
    final generation = ++_requestGeneration;
    setState(() {
      _point = point;
      _address.clear();
      _manualAddress = false;
      _findingAddress = true;
      _notice = 'Mencari alamat...';
    });
    _debounce = Timer(
        const Duration(milliseconds: 1100), () => _reverse(point, generation));
  }

  Future<void> _reverse(LatLng point, int generation) async {
    try {
      final address = await widget.repository
          .reverseGeocode(point.latitude, point.longitude);
      if (!mounted || generation != _requestGeneration || !_currentSession) {
        return;
      }
      setState(() {
        if (!_manualAddress) _address.text = address?.trim() ?? '';
        _notice = _manualAddress
            ? 'Alamat manual dipertahankan. Periksa kesesuaiannya dengan pin.'
            : _address.text.isEmpty
                ? 'Alamat perlu diisi manual'
                : 'Alamat ditemukan';
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _sessionRejected = error is ApiException &&
            (error.status == 401 || error.status == 403);
        _notice = _sessionRejected || !_currentSession
            ? 'Sesi atau izin berubah. Tutup pemilih dan masuk kembali.'
            : 'Alamat perlu diisi manual. Layanan alamat belum tersedia.';
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _findingAddress = false);
      }
    }
  }

  Future<void> _locate() async {
    if (_findingGps || !_currentSession) return;
    setState(() => _findingGps = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ApiException(
            'GPS tidak aktif. Titik tetap dapat dipilih di peta.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const ApiException(
            'Izin lokasi ditolak. Pilih titik di peta secara manual.');
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 12)));
      if (!mounted || !_currentSession) return;
      _map.move(LatLng(position.latitude, position.longitude), 15);
      _message('Kamera menuju lokasi Anda. Ketuk peta untuk menentukan pin.');
    } catch (error) {
      if (mounted) {
        _message(error is ApiException
            ? error.message
            : 'Lokasi perangkat belum tersedia. Pilih titik di peta secara manual.');
      }
    } finally {
      if (mounted) setState(() => _findingGps = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _debounce?.cancel();
    _requestGeneration++;
    _address.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        textTheme:
            GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
            title: const Text('Pilih Lokasi Destinasi',
                style: TextStyle(fontSize: 18)),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF102D59)),
        body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
          return Column(children: [
            if (!keyboardOpen)
              Expanded(
                  child: Stack(children: [
                DestinationLocationMap(
                    point: _point, controller: _map, onTap: _selectPoint),
                Positioned(
                    top: 12,
                    right: 12,
                    child: FilledButton.tonalIcon(
                        onPressed: _findingGps ? null : _locate,
                        icon: const Icon(Icons.my_location, size: 20),
                        label: Text(
                            _findingGps ? 'Mencari GPS...' : 'Lokasi Saya'))),
              ])),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: keyboardOpen
                      ? constraints.maxHeight
                      : constraints.maxHeight * .55),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            _point == null
                                ? 'Ketuk peta untuk memilih titik lokasi.'
                                : 'Koordinat: ${_point!.latitude.toStringAsFixed(7)}, ${_point!.longitude.toStringAsFixed(7)}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF64748B))),
                        const SizedBox(height: 8),
                        Text(
                            _notice ??
                                (_point == null
                                    ? 'Belum dipilih'
                                    : 'Lokasi siap disimpan'),
                            style: const TextStyle(fontSize: 12)),
                        if (_findingAddress) const LinearProgressIndicator(),
                        const SizedBox(height: 12),
                        TextField(
                            key: const ValueKey('picker-address'),
                            controller: _address,
                            maxLength: 255,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                                labelText: 'Alamat Lengkap',
                                hintText:
                                    'Alamat otomatis atau isi secara manual'),
                            onChanged: (_) => setState(() {
                                  _manualAddress = true;
                                  _notice =
                                      'Alamat manual. Periksa kesesuaiannya dengan pin.';
                                })),
                        const SizedBox(height: 8),
                        FilledButton(
                            onPressed: _point == null ||
                                    _sessionRejected ||
                                    !_currentSession
                                ? null
                                : () {
                                    Navigator.pop(
                                        context,
                                        DestinationLocationDraft(
                                            _point!, _address.text.trim()));
                                  },
                            child: const Text('Gunakan Lokasi Ini')),
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Batal')),
                      ])),
            ),
          ]);
        })),
      ));
}
