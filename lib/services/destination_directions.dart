import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/business_repository.dart';

Uri? destinationDirectionsUri(Destination destination) =>
    !destination.hasCoordinates
        ? null
        : Uri.https('www.google.com', '/maps/dir/', {
            'api': '1',
            'destination': '${destination.latitude},${destination.longitude}',
          });

Future<bool> openDestinationDirections(Destination destination) async {
  final uri = destinationDirectionsUri(destination);
  if (uri == null) return false;
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Explicit Maps first; Android selects a browser package for fallback.
      final result = await const MethodChannel('id.wisatadaerahku.app/maps')
          .invokeMethod<String>('openDirections', {
        'latitude': destination.latitude,
        'longitude': destination.longitude,
      });
      return result == 'maps' || result == 'browser';
    }
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('Directions launch failed: $error');
    return false;
  }
}
