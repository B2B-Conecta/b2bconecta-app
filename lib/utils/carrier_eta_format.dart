/// Formateo legible de ETA y tarifas de transportistas.
abstract final class CarrierEtaFormat {
  static String etaLabel(double? hours) {
    if (hours == null || hours <= 0) return 'Consultar ETA';
    if (hours < 1) {
      final mins = (hours * 60).round();
      return '~$mins min';
    }
    if (hours < 48) {
      final h = hours.round();
      return h == 1 ? '~1 hora' : '~$h horas';
    }
    final days = (hours / 24).ceil();
    return days == 1 ? '~1 día' : '~$days días';
  }

  static String distanceLabel(double? km) {
    if (km == null) return 'Distancia no calculada';
    if (km < 1) return '< 1 km';
    return '${km.toStringAsFixed(km >= 100 ? 0 : 1)} km';
  }

  static String feeLabel(double? usd) {
    if (usd == null || usd <= 0) return 'Sin tarifa estimada';
    return '~\$${usd.toStringAsFixed(2)} USD';
  }
}
