import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Ubicación del dispositivo para ordenar el catálogo por proximidad (aliados).
abstract final class GeolocatorService {
  /// `null` si permiso denegado, servicio desactivado o error.
  static Future<({double lat, double lng})?> getCurrentLatLng() async {
    try {
      var enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return null;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (e, st) {
      debugPrint('GeolocatorService: $e\n$st');
      return null;
    }
  }
}
