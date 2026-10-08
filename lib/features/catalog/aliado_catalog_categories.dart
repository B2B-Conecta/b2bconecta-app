/// Primera opción del filtro. No es una categoría de producto.
const kAliadoCatalogAllCategoriesLabel = 'Todos';

/// Varias escrituras de la misma categoría (singular, plural o un typo corto).
class AliadoCatalogCategoryGroup {
  const AliadoCatalogCategoryGroup({
    required this.label,
    required this.values,
  });

  /// Texto que ve el aliado en el filtro.
  final String label;

  /// Valores reales de `products.category` que entran en el grupo.
  final List<String> values;
}

/// Agrupa categorías parecidas y deja una etiqueta por grupo.
List<AliadoCatalogCategoryGroup> groupAliadoCatalogCategories(
  List<String> raw,
) {
  final values = <String>[];
  for (final item in raw) {
    final label = item.trim();
    if (label.isEmpty || values.contains(label)) continue;
    values.add(label);
  }
  if (values.isEmpty) return const [];

  final parent = List<int>.generate(values.length, (i) => i);
  int find(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  void union(int a, int b) {
    final pa = find(a);
    final pb = find(b);
    if (pa != pb) parent[pb] = pa;
  }

  final keys = [for (final value in values) catalogCategoryKey(value)];
  final folded = [for (final value in values) _foldCategory(value)];
  for (var i = 0; i < values.length; i++) {
    for (var j = i + 1; j < values.length; j++) {
      if (keys[i] == keys[j] ||
          catalogCategoryTypoClose(keys[i], keys[j]) ||
          catalogCategoryTypoClose(folded[i], folded[j])) {
        union(i, j);
      }
    }
  }

  final buckets = <int, List<String>>{};
  for (var i = 0; i < values.length; i++) {
    buckets.putIfAbsent(find(i), () => []).add(values[i]);
  }

  final groups = [
    for (final bucket in buckets.values)
      AliadoCatalogCategoryGroup(
        label: _pickCategoryLabel(bucket),
        values: List<String>.unmodifiable(bucket),
      ),
  ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return groups;
}

/// `Todos` y luego las categorías publicadas, sin repetir el texto exacto.
List<String> aliadoCatalogCategoryChoices({
  required List<String> categories,
  String? selected,
}) {
  final out = <String>[kAliadoCatalogAllCategoriesLabel];
  void add(String raw) {
    final label = raw.trim();
    if (label.isEmpty || label == kAliadoCatalogAllCategoriesLabel) return;
    if (out.contains(label)) return;
    out.add(label);
  }

  final sorted = <String>[
    for (final raw in categories)
      if (raw.trim().isNotEmpty) raw.trim(),
  ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  for (final label in sorted) {
    add(label);
  }
  if (selected != null) add(selected);
  return out;
}

/// Clave comparable: sin acentos, en singular aproximado.
String catalogCategoryKey(String raw) {
  final folded = _foldCategory(raw);
  if (folded.isEmpty) return '';
  return folded.split(' ').map(_stemCategoryToken).join(' ');
}

/// Un solo carácter de diferencia, en palabras lo bastante largas.
bool catalogCategoryTypoClose(String a, String b) {
  if (a.isEmpty || b.isEmpty || a == b) return false;
  final diff = (a.length - b.length).abs();
  if (diff > 1) return false;
  final shorter = a.length < b.length ? a.length : b.length;
  if (shorter < 5) return false;
  return _editDistance(a, b) <= 1;
}

String _foldCategory(String raw) {
  var text = raw.trim().toLowerCase();
  const from = 'áéíóúüàèìòùâêîôûäëïöãõ';
  const to = 'aeiouuaeiouaeiouaeioao';
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  text = buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text;
}

String _stemCategoryToken(String word) {
  if (word.length < 4) return word;
  if (word.endsWith('ciones') && word.length > 7) {
    return word.substring(0, word.length - 2);
  }
  if (word.endsWith('iones') && word.length > 6) {
    return word.substring(0, word.length - 2);
  }
  if (word.endsWith('es') && word.length > 4) {
    final base = word.substring(0, word.length - 2);
    final last = base[base.length - 1];
    if ('bcdfghjklmnpqrstvwxyz'.contains(last)) return base;
  }
  if (word.endsWith('s') && !word.endsWith('ss')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

String _pickCategoryLabel(List<String> variants) {
  final ranked = [...variants]..sort((a, b) {
      final byScore = _categoryLabelScore(b).compareTo(_categoryLabelScore(a));
      if (byScore != 0) return byScore;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
  return ranked.first;
}

int _categoryLabelScore(String value) {
  final text = value.trim();
  if (text.isEmpty) return 0;
  var score = text.length;
  final first = text[0];
  final titled = first.toUpperCase() == first && text != text.toUpperCase();
  if (titled) score += 20;
  if (text == text.toLowerCase()) score += 4;
  return score;
}

int _editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a[i] == b[j] ? 0 : 1;
      final insert = current[j] + 1;
      final delete = previous[j + 1] + 1;
      final replace = previous[j] + cost;
      var best = insert < delete ? insert : delete;
      if (replace < best) best = replace;
      current[j + 1] = best;
    }
    previous = current;
  }
  return previous[b.length];
}
