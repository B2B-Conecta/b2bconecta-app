import 'package:motolink_pro_app/features/catalog/aliado_catalog_categories.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica.dart';

/// Insumos que suelen comprarse junto a una categoría del carrito.
///
/// Las claves y los destinos son raíces comparables con [catalogCategoryKey]
/// (sin acento y en singular). Ejemplo: cauchos o llantas → lubricantes y válvulas.
const Map<String, List<String>> cartComplementTargets = {
  'caucho': ['lubricante', 'valvula', 'camara', 'aceite'],
  'llanta': ['lubricante', 'valvula', 'camara', 'aceite'],
  'neumatico': ['lubricante', 'valvula', 'camara', 'aceite'],
  'motor': ['aceite', 'lubricante', 'filtro', 'bujia'],
  'aceite': ['filtro', 'motor'],
  'lubricante': ['filtro', 'motor', 'caucho'],
  'freno': ['pastilla', 'disco', 'liquido'],
  'pastilla': ['disco', 'liquido', 'freno'],
  'disco': ['pastilla', 'liquido', 'freno'],
  'bateria': ['cargador', 'borne'],
  'cadena': ['pinon', 'lubricante'],
  'filtro': ['aceite', 'lubricante'],
  'bujia': ['bobina', 'cable'],
  'amortiguador': ['resorte', 'reten'],
  'escape': ['empaque', 'abrazadera'],
};

/// Pedido que el carrusel usa para pedir candidatos al catálogo.
class CartSuggestionQuery {
  const CartSuggestionQuery({
    required this.productIds,
    required this.skus,
    required this.categoryFragments,
  });

  /// SKUs e ids que ya están en el pedido. No se vuelven a sugerir.
  final List<String> productIds;
  final List<String> skus;

  /// Raíces de categorías complementarias (`lubricante`, `valvula`, …).
  final List<String> categoryFragments;

  factory CartSuggestionQuery.fromParts(List<PartModel> cartParts) {
    final ids = <String>[];
    final skus = <String>[];
    for (final part in cartParts) {
      if (part.id.isNotEmpty) ids.add(part.id);
      final sku = part.sku?.trim();
      if (sku != null && sku.isNotEmpty) skus.add(sku);
    }
    return CartSuggestionQuery(
      productIds: ids,
      skus: skus,
      categoryFragments: complementFragmentsFor(cartParts),
    );
  }
}

/// Raíces complementarias, listas para un `ilike` corto (mínimo 5 letras).
List<String> complementFragmentsFor(List<PartModel> cartParts) {
  final out = <String>[];
  for (final target in complementTargetsFor(cartParts)) {
    if (target.length < 5 || out.contains(target)) continue;
    out.add(target);
    if (out.length >= 8) break;
  }
  return out;
}

Set<String> complementTargetsFor(List<PartModel> cartParts) {
  final targets = <String>{};
  for (final part in cartParts) {
    final key = _searchKey(part);
    for (final entry in cartComplementTargets.entries) {
      if (!_tokenHits(key, entry.key)) continue;
      targets.addAll(entry.value);
    }
  }
  return targets;
}

/// Proveedor con volumen reciente, reputación alta o destacado de catálogo.
bool cartSupplierIsLeading(PartModel part) {
  if (part.isCatalogFeatured) return true;
  final orders = part.ownerCatalogPaidOrders30d ?? 0;
  if (orders >= 8) return true;
  final rating = part.ownerRatingAvg ?? 0;
  return orders >= 3 && rating >= 4.2;
}

double cartSupplierScore(PartModel part) {
  final orders = (part.ownerCatalogPaidOrders30d ?? 0).toDouble();
  final rating = (part.ownerRatingAvg ?? 0) * 20;
  final featured = part.isCatalogFeatured ? 40 : 0;
  final verified = part.isCatalogVerified ? 12 : 0;
  return orders + rating + featured + verified;
}

enum CartSuggestionKind { complement, leadingSupplier }

class CartSuggestion {
  const CartSuggestion({
    required this.part,
    required this.kind,
    required this.differentSupplier,
    required this.leadingSupplier,
    this.logisticsNote,
  });

  final PartModel part;
  final CartSuggestionKind kind;
  final bool differentSupplier;
  final bool leadingSupplier;

  /// Aviso cuando el producto abre otro grupo de proveedor.
  final String? logisticsNote;
}

/// Complementos primero. Dentro de cada grupo, el proveedor con mejor
/// cumplimiento y más pedidos pagados queda delante.
List<CartSuggestion> rankCartSuggestions({
  required List<PartModel> cartParts,
  required List<PartModel> candidates,
  int limit = 8,
}) {
  final cap = limit < 1 ? 1 : limit;
  final cartIds = <String>{
    for (final part in cartParts)
      if (part.id.isNotEmpty) part.id,
  };
  final cartSkus = <String>{
    for (final part in cartParts)
      if ((part.sku?.trim().isNotEmpty ?? false) &&
          (part.ownerId?.trim().isNotEmpty ?? false))
        '${part.ownerId!.trim()}::${part.sku!.trim().toLowerCase()}',
  };
  final owners = <String>{
    for (final part in cartParts)
      if (part.ownerId?.trim().isNotEmpty ?? false) part.ownerId!.trim(),
  };
  final targets = complementTargetsFor(cartParts);
  final ranked = <_ScoredSuggestion>[];
  final seen = <String>{};

  for (final part in candidates) {
    if (part.id.isEmpty || !seen.add(part.id)) continue;
    if (cartIds.contains(part.id)) continue;
    final sku = part.sku?.trim().toLowerCase();
    final owner = part.ownerId?.trim();
    if (sku != null &&
        sku.isNotEmpty &&
        owner != null &&
        owner.isNotEmpty &&
        cartSkus.contains('$owner::$sku')) {
      continue;
    }
    if (!part.isActive || !part.stockCoversMinOrder) continue;
    final complementary = targets.isNotEmpty && _matchesTarget(part, targets);
    final leading = cartSupplierIsLeading(part);
    if (!complementary && !leading) continue;
    final different = owner == null || owner.isEmpty || !owners.contains(owner);
    ranked.add(
      _ScoredSuggestion(
        suggestion: CartSuggestion(
          part: part,
          kind: complementary
              ? CartSuggestionKind.complement
              : CartSuggestionKind.leadingSupplier,
          differentSupplier: different,
          leadingSupplier: leading,
          logisticsNote: different
              ? otherSupplierBadge(part)
              : sameSupplierBadge(part),
        ),
        complementary: complementary,
        leading: leading,
        score: cartSupplierScore(part),
      ),
    );
  }

  ranked.sort((a, b) {
    final byComplement =
        (b.complementary ? 1 : 0).compareTo(a.complementary ? 1 : 0);
    if (byComplement != 0) return byComplement;
    final byLeading = (b.leading ? 1 : 0).compareTo(a.leading ? 1 : 0);
    if (byLeading != 0) return byLeading;
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.suggestion.part.id.compareTo(b.suggestion.part.id);
  });

  return [
    for (final row in ranked.take(cap)) row.suggestion,
  ];
}

class _ScoredSuggestion {
  const _ScoredSuggestion({
    required this.suggestion,
    required this.complementary,
    required this.leading,
    required this.score,
  });

  final CartSuggestion suggestion;
  final bool complementary;
  final bool leading;
  final double score;
}

/// Badge corto (máx. 2 líneas) cuando el producto abre otro grupo de proveedor.
String otherSupplierBadge(PartModel part) {
  final envio = EnvioPolitica.normalize(part.ownerEnvioTipo);
  final flete = switch (envio) {
    EnvioPolitica.incluido => 'Pedido aparte · Flete incluido',
    EnvioPolitica.aparte => 'Pedido aparte · Flete adicional',
    _ => 'Pedido aparte · Puede sumar envío',
  };
  if (!part.hasOwnerMinOrderAmount) return flete;
  return '$flete · Mín. propio';
}

/// Badge cuando el producto entra en el mismo proveedor del carrito.
String sameSupplierBadge(PartModel part) {
  final envio = EnvioPolitica.normalize(part.ownerEnvioTipo);
  return switch (envio) {
    EnvioPolitica.incluido => 'Mismo proveedor · Flete incluido',
    EnvioPolitica.aparte => 'Mismo proveedor · Flete unificado',
    _ => 'Mismo proveedor · Pedido unificado',
  };
}

String _searchKey(PartModel part) {
  return catalogCategoryKey('${part.category ?? ''} ${part.nombre}');
}

bool _matchesTarget(PartModel part, Set<String> targets) {
  final key = _searchKey(part);
  for (final target in targets) {
    if (_tokenHits(key, target)) return true;
  }
  return false;
}

bool _tokenHits(String haystack, String needle) {
  if (needle.isEmpty) return false;
  for (final token in haystack.split(' ')) {
    if (token.isEmpty) continue;
    if (token == needle) return true;
    if (needle.length >= 5 && token.startsWith(needle)) return true;
    if (token.length >= 5 && needle.startsWith(token)) return true;
  }
  return false;
}
