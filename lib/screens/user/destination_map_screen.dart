import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../data/business_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/destination_location_map_preview.dart';

class DestinationMapScreen extends StatefulWidget {
  final Destination destination;
  const DestinationMapScreen({super.key, required this.destination});

  @override
  State<DestinationMapScreen> createState() => _DestinationMapScreenState();
}

class _DestinationMapScreenState extends State<DestinationMapScreen>
    with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final _cameraAnimation = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350));
  LatLng? _userPoint;
  bool _findingLocation = false;
  int _locationRequest = 0;

  LatLng? get _destination => widget.destination.hasCoordinates
      ? LatLng(widget.destination.latitude!, widget.destination.longitude!)
      : null;

  void _moveTo(LatLng point) {
    _cameraAnimation.stop();
    if (MediaQuery.disableAnimationsOf(context)) {
      _map.move(point, 15);
      return;
    }
    final start = _map.camera.center;
    final zoom = _map.camera.zoom;
    void animate() {
      final progress = Curves.easeInOut.transform(_cameraAnimation.value);
      _map.move(
          LatLng(start.latitude + (point.latitude - start.latitude) * progress,
              start.longitude + (point.longitude - start.longitude) * progress),
          zoom + (15 - zoom) * progress);
    }

    _cameraAnimation.addListener(animate);
    _cameraAnimation
        .forward(from: 0)
        .whenCompleteOrCancel(() => _cameraAnimation.removeListener(animate));
  }

  Future<void> _locate() async {
    if (!mounted || _findingLocation) return;
    final request = ++_locationRequest;
    bool current() => mounted && request == _locationRequest;
    setState(() => _findingLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!current()) return;
      if (!enabled) {
        _message(
            'GPS tidak aktif. Aktifkan lokasi perangkat untuk melanjutkan.',
            action: 'Aktifkan Lokasi',
            settings: Geolocator.openLocationSettings);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (!current()) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!current()) return;
      }
      if (permission == LocationPermission.deniedForever) {
        _message(
            'Izin lokasi diblokir. Izinkan lokasi melalui pengaturan aplikasi.',
            action: 'Buka Pengaturan',
            settings: Geolocator.openAppSettings);
        return;
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        _message('Izin lokasi ditolak. Peta destinasi tetap dapat digunakan.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 12)));
      if (!current()) return;
      if (position.isMocked ||
          !position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude.abs() > 90 ||
          position.longitude.abs() > 180) {
        _message('Lokasi perangkat belum valid. Periksa GPS lalu coba lagi.');
        return;
      }
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _userPoint = point);
      _moveTo(point);
    } on TimeoutException {
      if (current()) {
        _message('Pencarian lokasi terlalu lama. Coba lagi di area terbuka.');
      }
    } on LocationServiceDisabledException {
      if (current()) {
        _message(
            'GPS tidak aktif. Aktifkan lokasi perangkat untuk melanjutkan.',
            action: 'Aktifkan Lokasi',
            settings: Geolocator.openLocationSettings);
      }
    } catch (_) {
      if (current()) {
        _message(
            'Lokasi perangkat belum tersedia. Periksa GPS lalu coba lagi.');
      }
    } finally {
      if (current()) setState(() => _findingLocation = false);
    }
  }

  void _message(String message,
      {String action = 'Coba Lagi', Future<bool> Function()? settings}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
              label: action,
              onPressed: () async {
                if (!mounted) return;
                if (settings == null) {
                  _locate();
                  return;
                }
                try {
                  final opened = await settings();
                  if (!opened && mounted) {
                    _message(
                        'Pengaturan belum dapat dibuka. Buka melalui perangkat.');
                  }
                } catch (_) {
                  if (mounted) {
                    _message(
                        'Pengaturan belum dapat dibuka. Buka melalui perangkat.');
                  }
                }
              })));
  }

  void _resetDestination() {
    ++_locationRequest;
    setState(() => _findingLocation = false);
    _moveTo(_destination!);
  }

  @override
  void dispose() {
    ++_locationRequest;
    _cameraAnimation.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = _destination;
    return Theme(
        data: AppColors.visitorTheme,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.dark),
            child: Scaffold(
                appBar: AppBar(
                    title: const Text('Lokasi Destinasi',
                        style: TextStyle(fontSize: 18))),
                body: point == null
                    ? const Center(
                        child: Text('Lokasi destinasi belum tersedia'))
                    : SafeArea(
                        top: false,
                        child: Stack(children: [
                          Positioned.fill(
                              child: DestinationLocationMap(
                                  point: point,
                                  controller: _map,
                                  interactive: true,
                                  userPoint: _userPoint,
                                  destinationName: widget.destination.name)),
                          Positioned(
                              right: 16,
                              bottom: 48,
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FloatingActionButton(
                                        heroTag: null,
                                        tooltip: _findingLocation
                                            ? 'Mencari lokasi Anda'
                                            : 'Lokasi Saya',
                                        onPressed:
                                            _findingLocation ? null : _locate,
                                        backgroundColor: AppColors.surface,
                                        foregroundColor: AppColors.blue,
                                        child: _findingLocation
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2))
                                            : const Icon(PhosphorIconsRegular
                                                .crosshair)),
                                    const SizedBox(height: 12),
                                    FloatingActionButton(
                                        heroTag: null,
                                        tooltip: 'Kembali ke Destinasi',
                                        onPressed: _resetDestination,
                                        backgroundColor: AppColors.surface,
                                        foregroundColor: AppColors.blue,
                                        child: const Icon(
                                            PhosphorIconsRegular.mapPin)),
                                  ])),
                        ])))));
  }
}
