import 'package:shared_preferences/shared_preferences.dart';

import 'package:motolink_pro_app/features/catalog/aliado_catalog_categories.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/catalog_taxonomy.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields.dart';

/// Términos frecuentes del buscador web cuando el campo aún está vacío.
const kAliadoShellSuggestedSearches = <String>[
  'Pastillas de freno',
  'Cadena 428',
  'Bujía',
  'Aceite 4T',
];

/// Accesos directos de Inicio. El catálogo resuelve sus valores reales.
const kAliadoShellShortcutCategories = <String>[
  'Frenos',
  'Transmisión',
  'Accesorios',
  'Motor',
];

/// Comparación sin acentos ni mayúsculas. Cada carácter se reemplaza por uno.
String foldAliadoSearch(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    buffer.write(_folded[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

const _folded = <int, String>{
  0xE1: 'a',
  0xE0: 'a',
  0xE4: 'a',
  0xE2: 'a',
  0xE9: 'e',
  0xE8: 'e',
  0xEB: 'e',
  0xEA: 'e',
  0xED: 'i',
  0xEC: 'i',
  0xEF: 'i',
  0xEE: 'i',
  0xF3: 'o',
  0xF2: 'o',
  0xF6: 'o',
  0xF4: 'o',
  0xFA: 'u',
  0xF9: 'u',
  0xFC: 'u',
  0xFB: 'u',
  0xF1: 'n',
};

/// Fragmentos de [text] con la coincidencia de [query] marcada.
List<({String text, bool match})> aliadoSearchHighlightPieces(
  String text,
  String query,
) {
  final needle = foldAliadoSearch(query.trim());
  if (needle.isEmpty || text.isEmpty) {
    return [(text: text, match: false)];
  }
  final folded = foldAliadoSearch(text);
  final pieces = <({String text, bool match})>[];
  var start = 0;
  while (start < text.length) {
    final index = folded.indexOf(needle, start);
    if (index < 0) {
      pieces.add((text: text.substring(start), match: false));
      break;
    }
    if (index > start) {
      pieces.add((text: text.substring(start, index), match: false));
    }
    final end = index + needle.length;
    pieces.add((text: text.substring(index, end), match: true));
    start = end;
  }
  return pieces;
}

/// Marca visible para el aliado, si el producto la publica en campos extra.
String? aliadoPartBrand(PartModel part) {
  final values = productCustomFieldValues(part.customFields);
  for (final entry in values.entries) {
    final key = foldAliadoSearch(entry.key);
    if (key.contains('marca') ||
        key.contains('brand') ||
        key.contains('fabricante')) {
      final value = entry.value.toString().trim();
      if (value.isNotEmpty) return value;
    }
  }
  return null;
}

class AliadoShellCategoryHit {
  const AliadoShellCategoryHit({
    required this.label,
    required this.family,
    required this.values,
  });

  final String label;
  final String family;
  final List<String> values;
}

List<String> aliadoFamilyCategoryValues(String family) {
  final children = catalogTaxonomy[family] ?? const <String>[];
  return [
    family,
    for (final child in children) categoryPath(family, child),
  ];
}

AliadoShellCategoryHit aliadoShellFamilyHit(
  String family,
  List<AliadoCatalogCategoryGroup> groups,
) {
  for (final group in groups) {
    if (group.label == family) {
      return AliadoShellCategoryHit(
        label: family,
        family: family,
        values: group.values,
      );
    }
  }
  return AliadoShellCategoryHit(
    label: family,
    family: family,
    values: aliadoFamilyCategoryValues(family),
  );
}

/// Atajos fijos, o familias y subcategorías que contienen la consulta.
List<AliadoShellCategoryHit> aliadoShellCategoryHits({
  required String query,
  required List<AliadoCatalogCategoryGroup> groups,
}) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return [
      for (final name in kAliadoShellShortcutCategories)
        aliadoShellFamilyHit(name, groups),
    ];
  }
  final needle = foldAliadoSearch(trimmed);
  if (needle.length < 2) return const [];
  final hits = <AliadoShellCategoryHit>[];
  void add(AliadoShellCategoryHit hit) {
    if (hits.length >= 3) return;
    if (hits.any((item) => item.label == hit.label && item.family == hit.family)) {
      return;
    }
    hits.add(hit);
  }

  if (groups.isEmpty) {
    for (final family in catalogTaxonomy.keys) {
      if (foldAliadoSearch(family).contains(needle)) {
        add(aliadoShellFamilyHit(family, groups));
      }
    }
    for (final entry in catalogTaxonomy.entries) {
      for (final child in entry.value) {
        if (!foldAliadoSearch(child).contains(needle)) continue;
        add(AliadoShellCategoryHit(
          label: child,
          family: entry.key,
          values: [categoryPath(entry.key, child)],
        ));
      }
    }
    return hits;
  }

  for (final group in groups) {
    if (foldAliadoSearch(group.label).contains(needle)) {
      add(AliadoShellCategoryHit(
        label: group.label,
        family: group.label,
        values: group.values,
      ));
    }
    for (final child in group.children) {
      final leaf = categoryLeaf(child.label);
      if (!foldAliadoSearch(leaf).contains(needle) &&
          !foldAliadoSearch(child.label).contains(needle)) {
        continue;
      }
      add(AliadoShellCategoryHit(
        label: leaf,
        family: group.label,
        values: child.values,
      ));
    }
  }
  return hits;
}

List<ImporterOption> aliadoShellSupplierHits(
  String query,
  List<ImporterOption> importers,
) {
  final needle = foldAliadoSearch(query.trim());
  if (needle.length < 2) return const [];
  final hits = <ImporterOption>[];
  for (final importer in importers) {
    final haystack = foldAliadoSearch(
      '${importer.businessName} ${importer.estado ?? ''} ${importer.ciudad ?? ''}',
    );
    if (!haystack.contains(needle)) continue;
    hits.add(importer);
    if (hits.length == 3) break;
  }
  return hits;
}

/// Términos que completan lo escrito: frecuentes, taxonomía, nombre y marca.
List<String> aliadoShellCompletions({
  required String query,
  required List<PartModel> parts,
}) {
  final needle = foldAliadoSearch(query.trim());
  if (needle.isEmpty) return const [];
  final out = <String>[];
  void add(String raw) {
    final value = raw.trim();
    if (value.isEmpty || out.length >= 4) return;
    final folded = foldAliadoSearch(value);
    if (folded == needle || !folded.contains(needle)) return;
    if (out.any((item) => foldAliadoSearch(item) == folded)) return;
    out.add(value);
  }

  for (final term in kAliadoShellSuggestedSearches) {
    add(term);
  }
  for (final family in catalogTaxonomy.keys) {
    add(family);
  }
  for (final children in catalogTaxonomy.values) {
    for (final child in children) {
      add(child);
    }
  }
  for (final part in parts) {
    add(part.nombre);
    final brand = aliadoPartBrand(part);
    if (brand != null) add(brand);
  }
  return out;
}

enum AliadoShellSearchKind {
  recent,
  suggested,
  completion,
  product,
  supplier,
  category,
  seeAll,
}

class AliadoShellSearchItem {
  const AliadoShellSearchItem._({
    required this.kind,
    required this.label,
    this.part,
    this.supplier,
    this.category,
  });

  const AliadoShellSearchItem.recent(String query)
      : this._(kind: AliadoShellSearchKind.recent, label: query);

  const AliadoShellSearchItem.suggested(String query)
      : this._(kind: AliadoShellSearchKind.suggested, label: query);

  const AliadoShellSearchItem.completion(String query)
      : this._(kind: AliadoShellSearchKind.completion, label: query);

  AliadoShellSearchItem.product(PartModel part)
      : this._(
          kind: AliadoShellSearchKind.product,
          label: part.nombre,
          part: part,
        );

  AliadoShellSearchItem.supplier(ImporterOption supplier)
      : this._(
          kind: AliadoShellSearchKind.supplier,
          label: supplier.businessName,
          supplier: supplier,
        );

  AliadoShellSearchItem.category(AliadoShellCategoryHit category)
      : this._(
          kind: AliadoShellSearchKind.category,
          label: category.label,
          category: category,
        );

  const AliadoShellSearchItem.seeAll(String query)
      : this._(kind: AliadoShellSearchKind.seeAll, label: query);

  final AliadoShellSearchKind kind;
  final String label;
  final PartModel? part;
  final ImporterOption? supplier;
  final AliadoShellCategoryHit? category;
}

List<AliadoShellSearchItem> buildAliadoShellSearchItems({
  required String query,
  required List<String> recents,
  required List<String> completions,
  required List<PartModel> parts,
  required List<ImporterOption> suppliers,
  required List<AliadoShellCategoryHit> categories,
}) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) {
    return [
      for (final recent in recents) AliadoShellSearchItem.recent(recent),
      for (final term in kAliadoShellSuggestedSearches)
        AliadoShellSearchItem.suggested(term),
      for (final category in categories)
        AliadoShellSearchItem.category(category),
    ];
  }
  return [
    for (final term in completions) AliadoShellSearchItem.completion(term),
    for (final part in parts.take(5)) AliadoShellSearchItem.product(part),
    for (final supplier in suppliers.take(3))
      AliadoShellSearchItem.supplier(supplier),
    for (final category in categories.take(3))
      AliadoShellSearchItem.category(category),
    AliadoShellSearchItem.seeAll(trimmed),
  ];
}

/// Búsquedas recientes del buscador web. Si el almacenamiento falla, queda en memoria.
class AliadoRecentSearchStore {
  AliadoRecentSearchStore({this.max = 6, List<String>? seed})
      : _cache = List<String>.from(seed ?? const []);

  static const storageKey = 'aliado_web_shell_recent_searches';

  final int max;
  List<String> _cache;

  List<String> get current => List<String>.unmodifiable(_cache);

  Future<List<String>> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cache = prefs.getStringList(storageKey) ?? _cache;
    } catch (_) {}
    return current;
  }

  Future<void> remember(String query) async {
    final value = query.trim();
    if (value.isEmpty) return;
    final folded = foldAliadoSearch(value);
    _cache = [
      value,
      for (final item in _cache)
        if (foldAliadoSearch(item) != folded) item,
    ].take(max).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(storageKey, _cache);
    } catch (_) {}
  }

  Future<void> clear() async {
    _cache = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {}
  }
}
