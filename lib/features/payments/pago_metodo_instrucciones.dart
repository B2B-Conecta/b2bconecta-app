/// Instrucciones de pago del importador por método (`profiles.pago_metodo_instrucciones`).
abstract final class PagoMetodoInstrucciones {
  static Map<String, String> parseMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is! Map) return {};
    final out = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim();
      final val = entry.value?.toString().trim() ?? '';
      if (key.isNotEmpty && val.isNotEmpty) {
        out[key] = val;
      }
    }
    return out;
  }

  static String? forMetodo(Map<String, String>? map, String? metodo) {
    if (map == null || map.isEmpty) return null;
    final m = metodo?.trim();
    if (m == null || m.isEmpty) return null;
    final text = map[m]?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static Map<String, dynamic> toJson(Map<String, String> map) {
    final out = <String, dynamic>{};
    for (final e in map.entries) {
      final k = e.key.trim();
      final v = e.value.trim();
      if (k.isNotEmpty && v.isNotEmpty) {
        out[k] = v;
      }
    }
    return out;
  }
}
