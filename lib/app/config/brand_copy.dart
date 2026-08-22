/// Copia visible de marca. El package sigue siendo `motolink_pro_app`.
abstract final class BrandCopy {
  static const name = 'B2B Conecta';

  /// Reemplaza el nombre legado en textos de UI, notificaciones y push.
  static String display(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll('MotoLink', name)
        .replaceAll('Motolink', name)
        .replaceAll('MOTOLINK', name);
  }
}
