/// Búsqueda de inventario del importador (nombre, SKU y otros detalles).
abstract final class InventorySearch {
  /// Campos de `products` incluidos en el OR de búsqueda.
  static const searchableColumns = <String>[
    'name',
    'sku',
    'description',
    'compatibility',
    'category',
    'parent_sku',
    'variant_attribute_name',
    'variant_attribute_value',
  ];

  /// Limpia el texto para PostgREST `.or()` / `ilike` sin destruir SKUs.
  ///
  /// Conserva `_`, `-` y `.` (comunes en códigos). Quita `%` (comodín ILIKE),
  /// comas y paréntesis (rompen el filtro `or`).
  static String sanitize(String input) {
    return input
        .replaceAll('%', ' ')
        .replaceAll('*', ' ')
        .replaceAll(RegExp(r'[(),]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Cláusula `or` de PostgREST, o `null` si no hay término útil.
  ///
  /// El patrón va entre comillas para que SKUs con `.` no partan el filtro.
  static String? postgrestOrFilter(String? searchQuery) {
    final safe = sanitize(searchQuery ?? '');
    if (safe.isEmpty) return null;
    final escaped = safe.replaceAll('"', '');
    final pattern = '"%$escaped%"';
    return [
      for (final column in searchableColumns) '$column.ilike.$pattern',
    ].join(',');
  }
}
