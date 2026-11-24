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
      incluido =>
        '$nombre: el flete suele ir incluido. El proveedor lo confirma en el pedido.',
      _ =>
        '$nombre: el flete puede ser un cobro adicional. El proveedor indicará el monto en USD/Bs en el pedido.',
    };
    if (minimoGratis == null || minimoGratis <= 0) return base;
    return '$base Envío gratis desde ${formatRefAmount(minimoGratis)} USD.';
  }

  /// Ficha web del minorista, según el estado de su tienda.
  static EnvioFichaMinorista evaluarCobertura({
    required String? tipo,
    double? minimoGratis,
    bool gratisTodos = false,
    List<String> gratisEstados = const [],
    String? estadoComprador,
    double? subtotalUsd,
  }) {
    if (normalize(tipo) == noDefinido) {
      return const EnvioFichaMinorista(
        vista: EnvioCoberturaVista.sinPolitica,
        texto: 'Este proveedor aún no definió su política de envío.',
      );
    }
    final base = normalize(tipo) == incluido
        ? 'Envío incluido.'
        : 'Cobro adicional de envío.';
    final hasGratis = minimoGratis != null &&
        minimoGratis > 0 &&
        (gratisTodos || gratisEstados.isNotEmpty);
    if (!hasGratis) {
      return EnvioFichaMinorista(
        vista: EnvioCoberturaVista.politica,
        texto: base,
      );
    }
    final amount = formatRefAmount(minimoGratis);
    final estado = estadoComprador?.trim() ?? '';
    if (gratisTodos) {
      final where =
          estado.isEmpty ? 'en todos los estados' : 'en tu estado ($estado)';
      return EnvioFichaMinorista(
        vista: EnvioCoberturaVista.gratisAqui,
        texto: _conProgreso(
          'Envío gratis desde $amount USD $where.',
          minimoGratis,
          subtotalUsd,
        ),
      );
    }
    if (estado.isEmpty) {
      return EnvioFichaMinorista(
        vista: EnvioCoberturaVista.sinUbicacion,
        texto:
            'Envío gratis desde $amount USD en ${_resumenEstados(gratisEstados)}. En los demás estados el flete tiene un costo adicional.',
      );
    }
    if (estadoIncluido(estado, gratisEstados)) {
      return EnvioFichaMinorista(
        vista: EnvioCoberturaVista.gratisAqui,
        texto: _conProgreso(
          'Tu estado ($estado) tiene envío gratis desde $amount USD.',
          minimoGratis,
          subtotalUsd,
        ),
      );
    }
    return EnvioFichaMinorista(
      vista: EnvioCoberturaVista.costoAdicional,
      texto:
          'Tu tienda está en $estado, fuera del envío gratis de este proveedor. El flete tiene un costo adicional.',
    );
  }

  static bool estadoIncluido(String estado, List<String> lista) {
    final key = _foldEstado(estado);
    if (key.isEmpty) return false;
    for (final item in lista) {
      if (_foldEstado(item) == key) return true;
    }
    return false;
  }

  static String _foldEstado(String raw) {
    const from = 'áéíóúüñ';
    const to = 'aeiouun';
    final buffer = StringBuffer();
    for (final char in raw.trim().toLowerCase().split('')) {
      final index = from.indexOf(char);
      buffer.write(index >= 0 ? to[index] : char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _resumenEstados(List<String> estados) {
    if (estados.length <= 3) return estados.join(', ');
    return '${estados.take(2).join(', ')} y ${estados.length - 2} más';
  }

  static String _conProgreso(String base, double minimo, double? subtotal) {
    if (subtotal == null) return base;
    if (subtotal + 0.0001 >= minimo) {
      return '$base Tu pedido ya cubre ese monto.';
    }
    final falta = minimo - subtotal;
    return '$base Te faltan ${formatRefAmount(falta)} USD para el envío gratis.';
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

enum EnvioCoberturaVista {
  sinPolitica,
  politica,
  gratisAqui,
  costoAdicional,
  sinUbicacion,
}

class EnvioFichaMinorista {
  const EnvioFichaMinorista({required this.vista, required this.texto});

  final EnvioCoberturaVista vista;
  final String texto;

  String get etiqueta {
    switch (vista) {
      case EnvioCoberturaVista.sinPolitica:
        return 'Sin definir';
      case EnvioCoberturaVista.politica:
        return texto.startsWith('Cobro') ? 'Cobro adicional' : 'Envío incluido';
      case EnvioCoberturaVista.gratisAqui:
        return 'Envío gratis';
      case EnvioCoberturaVista.costoAdicional:
        return 'Costo adicional';
      case EnvioCoberturaVista.sinUbicacion:
        return 'Según tu estado';
    }
  }
}
