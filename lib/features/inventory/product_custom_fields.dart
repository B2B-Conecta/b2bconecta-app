/// Campos ERP adicionales en `products.custom_fields` (jsonb).
class ProductCustomFieldEntry {
  const ProductCustomFieldEntry({
    required this.key,
    required this.label,
    required this.value,
    this.visibleToAliado = false,
  });

  final String key;
  final String label;
  final String value;

  /// Si el aliado puede ver este campo en la ficha del producto.
  final bool visibleToAliado;
}

/// Clave reservada dentro de `custom_fields` (no es un dato de negocio).
const kAliadoVisibleCustomFieldKeys = '_aliado_visible_keys';

bool isReservedCustomFieldKey(String key) =>
    key.startsWith('_') || key == kAliadoVisibleCustomFieldKeys;

/// Etiqueta legible para mostrar en inventario / ficha de producto.
String formatProductCustomFieldLabel(String key) {
  var k = key.trim();
  if (k.startsWith('col_')) {
    k = k.substring(4);
  }
  if (k.isEmpty) return key;

  final words = k.split(RegExp(r'[_\s]+')).where((w) => w.isNotEmpty);
  return words
      .map(
        (w) => w.length == 1
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String slugProductCustomFieldKey(String label) {
  var k = label
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (k.isEmpty) {
    k = 'campo_extra';
  }
  return k;
}

Set<String> parseAliadoVisibleCustomFieldKeys(Map<String, dynamic>? fields) {
  if (fields == null || fields.isEmpty) return {};
  final raw = fields[kAliadoVisibleCustomFieldKeys];
  if (raw is! List) return {};
  return raw
      .map((e) => e.toString().trim())
      .where((k) => k.isNotEmpty && !isReservedCustomFieldKey(k))
      .toSet();
}

/// Valores de negocio sin metadatos reservados.
Map<String, dynamic> productCustomFieldValues(Map<String, dynamic>? fields) {
  if (fields == null || fields.isEmpty) return const {};
  final out = <String, dynamic>{};
  for (final e in fields.entries) {
    if (isReservedCustomFieldKey(e.key)) continue;
    final v = e.value;
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isEmpty) continue;
    out[e.key] = s;
  }
  return out;
}

Map<String, dynamic> parseProductCustomFieldsJson(dynamic raw) {
  if (raw == null) return const {};
  if (raw is! Map) return const {};
  return Map<String, dynamic>.from(raw);
}

Map<String, dynamic> buildCustomFieldsPayload({
  required Map<String, dynamic> values,
  required Set<String> aliadoVisibleKeys,
}) {
  final cleanValues = <String, dynamic>{};
  for (final e in values.entries) {
    if (isReservedCustomFieldKey(e.key)) continue;
    final v = e.value?.toString().trim() ?? '';
    if (v.isEmpty) continue;
    cleanValues[e.key] = v;
  }

  final visible = aliadoVisibleKeys
      .where((k) => cleanValues.containsKey(k))
      .toList()
    ..sort();

  if (visible.isEmpty) return cleanValues;
  return {
    ...cleanValues,
    kAliadoVisibleCustomFieldKeys: visible,
  };
}

List<ProductCustomFieldEntry> productCustomFieldsDisplayEntries(
  Map<String, dynamic>? fields, {
  int? limit,
  bool aliadoView = false,
}) {
  if (fields == null || fields.isEmpty) return const [];
  final visibleKeys = parseAliadoVisibleCustomFieldKeys(fields);
  final values = productCustomFieldValues(fields);
  final entries = <ProductCustomFieldEntry>[];

  for (final e in values.entries) {
    final visibleToAliado = visibleKeys.contains(e.key);
    if (aliadoView && !visibleToAliado) continue;

    entries.add(
      ProductCustomFieldEntry(
        key: e.key,
        label: formatProductCustomFieldLabel(e.key),
        value: e.value.toString(),
        visibleToAliado: visibleToAliado,
      ),
    );
  }

  entries.sort((a, b) => a.label.compareTo(b.label));
  if (limit != null && entries.length > limit) {
    return entries.sublist(0, limit);
  }
  return entries;
}

/// Columnas del archivo aún sin mapear a campos core.
List<String> unmappedFileHeaders({
  required List<String> headers,
  required Map<String, String?> coreColumnSelections,
  required Map<String, String?> customColumnSelections,
}) {
  final used = <String>{
    ...coreColumnSelections.values.whereType<String>(),
    ...customColumnSelections.values.whereType<String>(),
  };
  return headers.where((h) => h.isNotEmpty && !used.contains(h)).toList();
}
