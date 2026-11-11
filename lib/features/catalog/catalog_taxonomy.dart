/// Familias visibles en el catálogo y opciones de clasificación de inventario.
const catalogTaxonomy = <String, List<String>>{
  'Cauchos y ruedas': ['Cauchos', 'Tripas', 'Rodamientos de rueda'],
  'Frenos': ['Pastillas', 'Bandas', 'Discos', 'Manillas de freno'],
  'Transmisión': [
    'Cadenas',
    'Coronas',
    'Piñones',
    'Kits de relación',
    'Embragues',
    'Tensores'
  ],
  'Eléctrico e iluminación': [
    'Baterías',
    'Bujías',
    'Bobinas',
    'CDI',
    'Reguladores y rectificadores',
    'Luces',
    'Fusibles y relés',
    'Arranque'
  ],
  'Motor': [
    'Pistones y anillos',
    'Árboles de levas',
    'Juntas y retenes de motor'
  ],
  'Lubricantes y mantenimiento': [
    'Aceites',
    'Grasas',
    'Aditivos',
    'Limpiadores',
    'Filtros de aceite'
  ],
  'Suspensión': ['Amortiguadores', 'Horquillas', 'Retenes de horquilla'],
  'Admisión y combustible': [
    'Filtros de aire',
    'Tapas de tanque',
    'Carburadores e inyección',
    'Cables de acelerador'
  ],
  'Escape': ['Tubos de escape', 'Silenciadores'],
  'Accesorios': [
    'Cascos',
    'Visores',
    'Protección',
    'Espejos',
    'Puños',
    'Soportes',
    'Baúles',
    'Fundas',
    'Asientos'
  ],
};

String categoryPath(String family, String subcategory) =>
    '$family / $subcategory';

String categoryFamily(String path) => path.split(' / ').first;

String categoryLeaf(String path) => path.split(' / ').last;

String catalogCategoryDisplayLabel(String path) {
  const tireFamily = 'Cauchos y ruedas';
  if (categoryFamily(path) != tireFamily) return path;
  final leaf = categoryLeaf(path);
  return leaf == tireFamily || leaf == 'Cauchos'
      ? 'Cauchos'
      : categoryPath('Cauchos', leaf);
}

String _categoryKey(String value) => value
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

final _canonicalByKey = <String, String>{
  for (final family in catalogTaxonomy.entries) ...{
    _categoryKey(family.key): family.key,
    for (final child in family.value)
      _categoryKey(categoryPath(family.key, child)):
          categoryPath(family.key, child),
  },
};

const _aliases = <String, String>{
  'cauchos y tripas': 'Cauchos y ruedas',
  'ruedas': 'Cauchos y ruedas',
  'freno': 'Frenos',
  'transmisiones': 'Transmisión',
  'motores': 'Motor',
  'electrico': 'Eléctrico e iluminación',
  'electricidad': 'Eléctrico e iluminación',
  'iluminacion': 'Eléctrico e iluminación',
  'lubricacion': 'Lubricantes y mantenimiento',
  'cascos y proteccion': 'Accesorios',
  'accesorio': 'Accesorios',
  'accesorios universal': 'Accesorios',
  'accesorios universales': 'Accesorios',
  'caucho': 'Cauchos y ruedas / Cauchos',
  'cauchos': 'Cauchos y ruedas / Cauchos',
  'neumatico': 'Cauchos y ruedas / Cauchos',
  'neumaticos': 'Cauchos y ruedas / Cauchos',
  'tripa': 'Cauchos y ruedas / Tripas',
  'tripas': 'Cauchos y ruedas / Tripas',
  'camara': 'Cauchos y ruedas / Tripas',
  'camaras': 'Cauchos y ruedas / Tripas',
  'rodamiento de rueda': 'Cauchos y ruedas / Rodamientos de rueda',
  'rodamientos de rueda': 'Cauchos y ruedas / Rodamientos de rueda',
  'pastilla': 'Frenos / Pastillas',
  'pastillas': 'Frenos / Pastillas',
  'pastillas de freno': 'Frenos / Pastillas',
  'banda': 'Frenos / Bandas',
  'bandas': 'Frenos / Bandas',
  'bandas de freno': 'Frenos / Bandas',
  'disco de freno': 'Frenos / Discos',
  'discos de freno': 'Frenos / Discos',
  'manilla de freno': 'Frenos / Manillas de freno',
  'cadena': 'Transmisión / Cadenas',
  'cadenas': 'Transmisión / Cadenas',
  'corona': 'Transmisión / Coronas',
  'coronas': 'Transmisión / Coronas',
  'pinon': 'Transmisión / Piñones',
  'pinones': 'Transmisión / Piñones',
  'pi on': 'Transmisión / Piñones',
  'pi ones': 'Transmisión / Piñones',
  'kit de relacion': 'Transmisión / Kits de relación',
  'kits de relacion': 'Transmisión / Kits de relación',
  'kites de relaciones': 'Transmisión / Kits de relación',
  'embrague': 'Transmisión / Embragues',
  'embragues': 'Transmisión / Embragues',
  'tensor': 'Transmisión / Tensores',
  'tensores': 'Transmisión / Tensores',
  'bateria': 'Eléctrico e iluminación / Baterías',
  'baterias': 'Eléctrico e iluminación / Baterías',
  'bujia': 'Eléctrico e iluminación / Bujías',
  'bujias': 'Eléctrico e iluminación / Bujías',
  'bobina': 'Eléctrico e iluminación / Bobinas',
  'bobinas': 'Eléctrico e iluminación / Bobinas',
  'arranque': 'Eléctrico e iluminación / Arranque',
  'piston': 'Motor / Pistones y anillos',
  'pistones': 'Motor / Pistones y anillos',
  'anillo': 'Motor / Pistones y anillos',
  'anillos': 'Motor / Pistones y anillos',
  'arboleva': 'Motor / Árboles de levas',
  'arbol de levas': 'Motor / Árboles de levas',
  'aceite': 'Lubricantes y mantenimiento / Aceites',
  'aceites': 'Lubricantes y mantenimiento / Aceites',
  'lubricante': 'Lubricantes y mantenimiento / Aceites',
  'lubricantes': 'Lubricantes y mantenimiento / Aceites',
  'amortiguador': 'Suspensión / Amortiguadores',
  'amortiguadores': 'Suspensión / Amortiguadores',
  'filtro de aire': 'Admisión y combustible / Filtros de aire',
  'filtros de aire': 'Admisión y combustible / Filtros de aire',
  'tapa tanque': 'Admisión y combustible / Tapas de tanque',
  'tapa de tanque': 'Admisión y combustible / Tapas de tanque',
  'silenciador': 'Escape / Silenciadores',
  'silenciadores': 'Escape / Silenciadores',
  'casco': 'Accesorios / Cascos',
  'cascos': 'Accesorios / Cascos',
  'asiento': 'Accesorios / Asientos',
  'asientos': 'Accesorios / Asientos',
};

final _productRules = <(RegExp, String)>[
  (RegExp(r'\b(cauchos?|neumaticos?)\b'), 'Cauchos y ruedas / Cauchos'),
  (RegExp(r'\b(tripas?|camaras? de aire)\b'), 'Cauchos y ruedas / Tripas'),
  (
    RegExp(r'\brodamientos?\b.*\brueda\b'),
    'Cauchos y ruedas / Rodamientos de rueda'
  ),
  (RegExp(r'\bpastillas?\b'), 'Frenos / Pastillas'),
  (RegExp(r'\bbandas?\b.*\b(freno|rallo)\b'), 'Frenos / Bandas'),
  (RegExp(r'\bdisco\b.*\b(freno|ebc|flotante)\b'), 'Frenos / Discos'),
  (RegExp(r'\bmanillas?\b.*\bfreno\b'), 'Frenos / Manillas de freno'),
  (RegExp(r'\bkits?\b.*\brelacion\b'), 'Transmisión / Kits de relación'),
  (RegExp(r'\bembragues?\b'), 'Transmisión / Embragues'),
  (
    RegExp(r'\btensores?\b.*\bcadena\b|\btensor\b.*\bcadena\b'),
    'Transmisión / Tensores'
  ),
  (RegExp(r'\bbaterias?\b'), 'Eléctrico e iluminación / Baterías'),
  (RegExp(r'\bbujias?\b'), 'Eléctrico e iluminación / Bujías'),
  (RegExp(r'\bbobinas?\b'), 'Eléctrico e iluminación / Bobinas'),
  (RegExp(r'\bcdi\b'), 'Eléctrico e iluminación / CDI'),
  (
    RegExp(r'\b(reguladores?|rectificadores?|regulador|rectificador)\b'),
    'Eléctrico e iluminación / Reguladores y rectificadores'
  ),
  (
    RegExp(r'\b(led|stop|faro|luces|bombillo|luz)\b'),
    'Eléctrico e iluminación / Luces'
  ),
  (
    RegExp(r'\b(fusibles?|reles?)\b'),
    'Eléctrico e iluminación / Fusibles y relés'
  ),
  (RegExp(r'\barranque\b'), 'Eléctrico e iluminación / Arranque'),
  (
    RegExp(r'\bfiltros?\b.*\baceite\b'),
    'Lubricantes y mantenimiento / Filtros de aceite'
  ),
  (
    RegExp(r'\blimpiadores?\b|\blimpiador\b'),
    'Lubricantes y mantenimiento / Limpiadores'
  ),
  (RegExp(r'\baceites?\b'), 'Lubricantes y mantenimiento / Aceites'),
  (RegExp(r'\bgrasas?\b'), 'Lubricantes y mantenimiento / Grasas'),
  (RegExp(r'\baditivos?\b'), 'Lubricantes y mantenimiento / Aditivos'),
  (RegExp(r'\bretenes?\b.*\bhorquilla\b'), 'Suspensión / Retenes de horquilla'),
  (
    RegExp(r'\b(amortiguador(es)?|mortiguador)\b'),
    'Suspensión / Amortiguadores'
  ),
  (RegExp(r'\bhorquillas?\b'), 'Suspensión / Horquillas'),
  (
    RegExp(r'\bfiltros?\b.*\b(aire|espuma)\b'),
    'Admisión y combustible / Filtros de aire'
  ),
  (
    RegExp(r'\btapas?\b.*\btanque\b'),
    'Admisión y combustible / Tapas de tanque'
  ),
  (
    RegExp(r'\b(carburador(es)?|inyector(es)?)\b'),
    'Admisión y combustible / Carburadores e inyección'
  ),
  (
    RegExp(r'\bcables?\b.*\bacelerador\b'),
    'Admisión y combustible / Cables de acelerador'
  ),
  (RegExp(r'\bsilenciador(es)?\b'), 'Escape / Silenciadores'),
  (RegExp(r'\bescapes?\b'), 'Escape / Tubos de escape'),
  (RegExp(r'\bcascos?\b'), 'Accesorios / Cascos'),
  (RegExp(r'\bvisores?\b|\bvisor\b'), 'Accesorios / Visores'),
  (RegExp(r'\b(espejos?|retrovisores?)\b'), 'Accesorios / Espejos'),
  (RegExp(r'\b(punos?|grips?)\b'), 'Accesorios / Puños'),
  (RegExp(r'\basientos?\b'), 'Accesorios / Asientos'),
  (
    RegExp(r'\b(piston(es)?|anillos? de piston)\b'),
    'Motor / Pistones y anillos'
  ),
  (RegExp(r'\b(arboleva|arbol de levas)\b'), 'Motor / Árboles de levas'),
  (RegExp(r'\bcadenas?\b'), 'Transmisión / Cadenas'),
  (RegExp(r'\bcoronas?\b'), 'Transmisión / Coronas'),
  (RegExp(r'\bpinon(es)?\b'), 'Transmisión / Piñones'),
];

/// Resolves published category values and old links without changing their filters.
String? canonicalCatalogCategory(String? category) {
  final key = _categoryKey(category ?? '');
  return _canonicalByKey[key] ?? _aliases[key];
}

/// Resolves an old import label and refines broad categories using the item name.
/// Explicit canonical paths win. Unrecognised inputs can be reviewed by the seller.
String? classifyCatalogProduct(String? category, String name) {
  final canonical = canonicalCatalogCategory(category);
  if (canonical != null && categoryFamily(canonical) != canonical)
    return canonical;
  final key = _categoryKey(name);
  for (final (pattern, path) in _productRules) {
    if (pattern.hasMatch(key)) return path;
  }
  return canonical;
}
