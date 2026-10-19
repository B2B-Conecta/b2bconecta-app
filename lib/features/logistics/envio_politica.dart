import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';

/// Política de flete del proveedor (`profiles.envio_tipo`).
abstract final class EnvioPolitica {
  static const incluido = 'INCLUIDO';
  static const aparte = 'APARTE';
  static const noDefinido = 'NO_DEFINIDO';

  static String normalize(dynamic raw) {
    switch (raw?.toString().trim().toUpperCase()) {
      case incluido:
        return incluido;
      case aparte:
        return aparte;
      default:
        return noDefinido;
    }
  }

  static bool muestraBadge(String? tipo) {
    switch (normalize(tipo)) {
      case incluido:
      case aparte:
        return true;
      default:
        return false;
    }
  }

  static List<String> parseNombres(dynamic raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      final name = item.toString().trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (!seen.add(key)) continue;
      out.add(name);
    }
    return out;
  }

  static String badgeCorto(String? tipo) {
    switch (normalize(tipo)) {
      case incluido:
        return 'Envío incluido';
      case aparte:
        return 'Cobro adicional';
      default:
        return '';
    }
  }

  static String badgeLargo(String? tipo) {
    switch (normalize(tipo)) {
      case incluido:
        return 'Envío incluido';
      case aparte:
        return 'Cobro adicional';
      default:
        return '';
    }
  }

  static String? notaConfirmacion({
    required String? tipo,
    required String proveedor,
    double? minimoGratis,
  }) {
    final code = normalize(tipo);
    if (code == noDefinido) return null;
    final nombre = proveedor.trim().isEmpty ? 'Este proveedor' : proveedor.trim();
    final base = switch (code) {
      incluido => '$nombre: el flete va incluido en la factura.',
      _ => '$nombre: el flete es un cobro adicional, aparte de la factura.',
    };
    if (minimoGratis == null || minimoGratis <= 0) return base;
    return '$base Envío gratis desde ${formatRefAmount(minimoGratis)} USD.';
  }

  static String ayudaProveedor(String? tipo) {
    switch (normalize(tipo)) {
      case incluido:
        return 'La vitrina muestra envío incluido. El flete va en la factura.';
      case aparte:
        return 'La vitrina avisa que el flete es un cobro adicional.';
      default:
        return 'Sin política. La vitrina no muestra información de envío.';
    }
  }
}
