import 'package:flutter/foundation.dart';

import 'package:motolink_pro_app/features/catalog/part_model.dart';

/// Línea del carrito del aliado (solo en memoria hasta confirmar checkout).
class CartLine {
  CartLine({
    required this.part,
    required this.quantity,
    required this.precioUnitarioAliadoRef,
  });

  final PartModel part;
  int quantity;

  /// Precio unitario REF acordado al añadir al carrito.
  final double precioUnitarioAliadoRef;
}

/// Carrito multi-importador (agrupa por importador en la UI).
class CartService extends ChangeNotifier {
  CartService._();
  static final CartService instance = CartService._();

  final List<CartLine> _lines = [];
  final Map<String, String> _promoCampaignByImportadorId = {};

  List<CartLine> get lines => List.unmodifiable(_lines);

  /// Campaña promocional (E1.2) asociada al pedido por importador, vía CTA del catálogo.
  Map<String, String> get promoCampaignByImportadorId =>
      Map.unmodifiable(_promoCampaignByImportadorId);

  void setPromoAttribution({
    required String importadorId,
    required String campaignId,
  }) {
    final imp = importadorId.trim();
    final camp = campaignId.trim();
    if (imp.isEmpty || camp.isEmpty) return;
    _promoCampaignByImportadorId[imp] = camp;
    notifyListeners();
  }

  String? promoCampaignIdForImportador(String? importadorId) {
    final id = importadorId?.trim();
    if (id == null || id.isEmpty) return null;
    return _promoCampaignByImportadorId[id];
  }

  bool importadorHasPromoAttribution(String? importadorId) =>
      promoCampaignIdForImportador(importadorId) != null;

  /// Mapa listo para RPC checkout (`importador_id` → `campaign_id`).
  Map<String, String> promoAttributionPayloadForCheckout() {
    final owners = _lines
        .map((l) => l.part.ownerId?.trim())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toSet();
    final out = <String, String>{};
    for (final oid in owners) {
      final cid = _promoCampaignByImportadorId[oid];
      if (cid != null && cid.isNotEmpty) out[oid] = cid;
    }
    return out;
  }

  void clearPromoAttributions() {
    if (_promoCampaignByImportadorId.isEmpty) return;
    _promoCampaignByImportadorId.clear();
    notifyListeners();
  }

  int get itemCount => _lines.fold<int>(0, (s, e) => s + e.quantity);

  bool get isEmpty => _lines.isEmpty;

  /// Agrupa líneas por nombre de negocio del importador.
  Map<String, List<CartLine>> get linesGroupedByImporterName {
    final map = <String, List<CartLine>>{};
    for (final line in _lines) {
      final name =
          line.part.ownerBusinessName?.trim().isNotEmpty == true
              ? line.part.ownerBusinessName!.trim()
              : 'Importador';
      map.putIfAbsent(name, () => []).add(line);
    }
    return map;
  }

  /// Agrupa líneas por `ownerId` del importador (checkout logística).
  Map<String, List<CartLine>> get linesGroupedByImportadorId {
    final map = <String, List<CartLine>>{};
    for (final line in _lines) {
      final id = line.part.ownerId?.trim();
      if (id == null || id.isEmpty) continue;
      map.putIfAbsent(id, () => []).add(line);
    }
    return map;
  }

  String importadorDisplayName(String importadorId) {
    for (final line in _lines) {
      if (line.part.ownerId == importadorId) {
        final name = line.part.ownerBusinessName?.trim();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return 'Importador';
  }

  void addOrIncrement(
    PartModel part, {
    required double precioUnitarioAliadoRef,
    int delta = 1,
  }) {
    final maxStock = part.stock;
    final minQty = part.minOrderQtyEffective;
    if (maxStock < minQty) return;
    final idx = _lines.indexWhere((l) => l.part.id == part.id);
    if (idx >= 0) {
      final existing = _lines[idx];
      final next = existing.quantity + delta;
      existing.quantity = next > maxStock ? maxStock : next;
      if (existing.quantity < minQty) existing.quantity = minQty;
    } else {
      var q = delta < minQty ? minQty : delta;
      if (q > maxStock) q = maxStock;
      _lines.add(
        CartLine(
          part: part,
          quantity: q,
          precioUnitarioAliadoRef: precioUnitarioAliadoRef,
        ),
      );
    }
    notifyListeners();
  }

  void removeProduct(String productId) {
    _lines.removeWhere((l) => l.part.id == productId);
    notifyListeners();
  }

  void setQuantity(String productId, int qty) {
    final idx = _lines.indexWhere((l) => l.part.id == productId);
    if (idx < 0) return;
    final line = _lines[idx];
    final maxStock = line.part.stock;
    final minQty = line.part.minOrderQtyEffective;
    if (qty < 1) {
      _lines.removeAt(idx);
      notifyListeners();
      return;
    }
    var next = qty < minQty ? minQty : qty;
    line.quantity = next > maxStock ? maxStock : next;
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    _promoCampaignByImportadorId.clear();
    notifyListeners();
  }

  /// Suma en REF (fuente de verdad); BS solo en UI con tasa.
  double totalRef() {
    var s = 0.0;
    for (final l in _lines) {
      s += l.precioUnitarioAliadoRef * l.quantity;
    }
    return s;
  }
}
