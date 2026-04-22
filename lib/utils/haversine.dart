import 'dart:math' as math;

/// Distancia en línea recta (km) entre dos puntos WGS84.
abstract final class Haversine {
  static const double _earthRadiusKm = 6371.0;

  /// `null` si falta alguna coordenada.
  static double? distanceKm(
    double? lat1,
    double? lon1,
    double? lat2,
    double? lon2,
  ) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }
    final rLat1 = lat1 * math.pi / 180;
    final rLat2 = lat2 * math.pi / 180;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) *
            math.cos(rLat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }
}
