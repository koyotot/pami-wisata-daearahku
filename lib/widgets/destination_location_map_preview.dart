import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const destinationTileUrl = String.fromEnvironment('MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
const destinationMapAttribution = String.fromEnvironment('MAP_ATTRIBUTION',
    defaultValue: '© OpenStreetMap contributors');

/// The picker and both previews share the same tiles, attribution and pin.
class DestinationLocationMap extends StatefulWidget {
  final LatLng? point;
  final MapController? controller;
  final ValueChanged<LatLng>? onTap;
  const DestinationLocationMap(
      {super.key, this.point, this.controller, this.onTap});

  @override
  State<DestinationLocationMap> createState() => _DestinationLocationMapState();
}

class _DestinationLocationMapState extends State<DestinationLocationMap> {
  bool _tileFailed = false;

  @override
  Widget build(BuildContext context) => Stack(children: [
        FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
            initialCenter: widget.point ?? const LatLng(-2.5, 118),
            initialZoom: widget.point == null ? 3 : 15,
            maxZoom: 19,
            interactionOptions: InteractionOptions(
                flags: widget.onTap == null
                    ? InteractiveFlag.none
                    : InteractiveFlag.all & ~InteractiveFlag.rotate),
            onTap: widget.onTap == null
                ? null
                : (_, point) => widget.onTap!(point),
          ),
          children: [
            // flutter_map 8.3 uses persistent, HTTP-header-aware native caching.
            TileLayer(
              urlTemplate: destinationTileUrl,
              userAgentPackageName: 'id.wisatadaerahku.app',
              panBuffer: 0,
              tileDisplay: const TileDisplay.instantaneous(),
              errorTileCallback: (_, __, ___) {
                if (_tileFailed) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _tileFailed = true);
                });
              },
            ),
            if (widget.point != null)
              MarkerLayer(markers: [
                Marker(
                  point: widget.point!,
                  width: 44,
                  height: 48,
                  alignment: Alignment.topCenter,
                  child: Semantics(
                    label: 'Titik lokasi destinasi',
                    child: const Icon(Icons.location_on,
                        color: Color(0xFF1976D2), size: 44),
                  ),
                ),
              ]),
          ],
        ),
        if (_tileFailed)
          const Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: IgnorePointer(
                  child: ColoredBox(
                      color: Colors.white,
                      child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                              'Peta belum dapat dimuat. Koordinat tetap tersedia.',
                              style: TextStyle(fontSize: 12)))))),
        const Positioned(
          right: 0,
          left: 0,
          bottom: 0,
          child: IgnorePointer(
              child: ColoredBox(
                  color: Colors.white,
                  child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(destinationMapAttribution,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 11, color: Colors.black87))))),
        ),
      ]);
}
