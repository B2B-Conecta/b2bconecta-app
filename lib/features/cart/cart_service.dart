import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'importer_min_order.dart';
import 'cart_draft_storage.dart';

/// Línea del carrito. Sus precios y disponibilidad se actualizan al restaurar.
class CartLine {
  CartLine({
    required this.part,
    required this.quantity,
    required this.precioUnitarioAliadoRef,
  });

  final PartModel part;
  int quantity;

  /// Precio unitario REF (se recalcula al cambiar cantidad: volumen vs promo).
  double precioUnitarioAliadoRef;
}

/// Carrito multi-importador (agrupa por importador en la UI).
class CartService extends ChangeNotifier {
  CartService();

  static final CartService instance = CartService();

  String? _accountKey;
  CartDraftStorage? _storage;
  Future<PartModel?> Function(String)? _loadProduct;
  Future<void> _pendingWrite = Future.value();
  int _generation = 0;
  bool restoring = false;
  String? storageMessage;
  String? restoreMessage;
  bool get canEdit => !restoring && _restoreFailed == false;
  bool _restoreFailed = false;
  int get accountRevision => _generation;
  bool invalidDraft = false;

  /// Isolated by environment and user; changing accounts immediately clears RAM.
  Future<void> openAccount({
    required String? accountKey,
    required CartDraftStorage storage,
    required Future<PartModel?> Function(String) loadProduct,
    bool retry = false,
  }) async {
    if (_accountKey == accountKey && !retry) return;
    final generation = ++_generation;
    _accountKey = accountKey;
    _storage = storage;
    _loadProduct = loadProduct;
    _lines.clear();
    _promoCampaignByImportadorId.clear();
    storageMessage = null;
    restoreMessage = null;
    _restoreFailed = false;
    invalidDraft = false;
    restoring = accountKey != null;
    notifyListeners();
    if (accountKey == null) return;
    try {
      await _pendingWrite;
      final raw = await storage.read(accountKey);
      if (generation != _generation) return;
      if (raw != null) {
        final draft = jsonDecode(raw) as Map<String, dynamic>;
        if (draft['version'] != 1 || draft['lines'] is! List) {
          throw const FormatException('Carrito incompatible');
        }
        final entries = (draft['lines'] as List).take(200);
        var adjusted = false;
        final restored = <CartLine>[];
        final seen = <String>{};
        for (final entry in entries) {
          final id = entry['id'] as String;
          final quantity = entry['quantity'] as int;
          if (id.isEmpty || quantity < 1 || !seen.add(id)) continue;
          final part = await loadProduct(id);
          if (generation != _generation) return;
          if (part == null ||
              !part.isActive ||
              part.ownerId == null ||
              part.stockForSale < part.minOrderQtyEffective) {
            adjusted = true;
            continue;
          }
          final qty =
              quantity.clamp(part.minOrderQtyEffective, part.stockForSale);
          adjusted = adjusted || qty != quantity;
          restored.add(CartLine(
              part: part,
              quantity: qty,
              precioUnitarioAliadoRef:
                  part.precioUnitarioParaAliado(quantity: qty)));
        }
        if (generation != _generation) return;
        _lines.addAll(restored);
        final campaigns = draft['campaigns'];
        if (campaigns is Map) {
          for (final entry in campaigns.entries) {
            if (entry.key is String &&
                entry.value is String &&
                _lines.any((line) => line.part.ownerId == entry.key)) {
              _promoCampaignByImportadorId[entry.key as String] =
                  entry.value as String;
            }
          }
        }
        if (adjusted) {
          restoreMessage =
              'Actualizamos tu carrito según la disponibilidad. Revisa las cantidades y los precios.';
        }
      }
    } on FormatException {
      if (generation != _generation) return;
      invalidDraft = true;
      _restoreFailed = true;
      storageMessage =
          'El carrito guardado no se puede leer. Puedes iniciar uno nuevo.';
    } on TypeError {
      if (generation != _generation) return;
      invalidDraft = true;
      _restoreFailed = true;
      storageMessage =
          'El carrito guardado no se puede leer. Puedes iniciar uno nuevo.';
    } catch (_) {
      if (generation != _generation) return;
      _restoreFailed = true;
      storageMessage =
          'No pudimos recuperar tu carrito. Reintenta para conservar tus productos.';
    } finally {
      if (generation == _generation) {
        restoring = false;
        notifyListeners();
      }
    }
  }

  Future<void> retryRestore() async {
    final storage = _storage;
    final loader = _loadProduct;
    if (storage == null || loader == null || restoring) return;
    await openAccount(
        accountKey: _accountKey,
        storage: storage,
        loadProduct: loader,
        retry: true);
  }

  void discardInvalidDraft() {
    if (!invalidDraft || restoring) return;
    invalidDraft = false;
    _restoreFailed = false;
    storageMessage = null;
    clear();
  }

  void _changed() {
    notifyListeners();
    final key = _accountKey;
    final storage = _storage;
    if (key == null || storage == null || !canEdit) return;
    final value = jsonEncode({
      'version': 1,
      'lines': [
        for (final line in _lines)
          {'id': line.part.id, 'quantity': line.quantity}
      ],
      'campaigns': promoAttributionPayloadForCheckout(),
    });
    final generation = _generation;
    _pendingWrite = _pendingWrite.then((_) async {
      await storage.write(key, value);
      if (generation == _generation && storageMessage != null) {
        storageMessage = null;
        notifyListeners();
      }
    }).catchError((Object _) {
      if (generation != _generation) return;
      storageMessage =
          'Tu carrito sigue abierto, pero no se pudo guardar en este dispositivo.';
      notifyListeners();
    });
  }

  Future<void> get saved => _pendingWrite;

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
    if (!canEdit) return;
    final imp = importadorId.trim();
    final camp = campaignId.trim();
    if (imp.isEmpty || camp.isEmpty) return;
    _promoCampaignByImportadorId[imp] = camp;
    _changed();
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
    if (!canEdit) return;
    if (_promoCampaignByImportadorId.isEmpty) return;
    _promoCampaignByImportadorId.clear();
    _changed();
  }

  int get itemCount => _lines.fold<int>(0, (s, e) => s + e.quantity);

  bool get isEmpty => _lines.isEmpty;

  /// Agrupa líneas por nombre de negocio del importador.
  Map<String, List<CartLine>> get linesGroupedByImporterName {
    final map = <String, List<CartLine>>{};
    for (final line in _lines) {
      final name = line.part.ownerBusinessName?.trim().isNotEmpty == true
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

  /// Stable identity prevents merging distinct businesses with the same name.
  Map<String, List<CartLine>> get supplierGroups {
    final groups = <String, List<CartLine>>{};
    for (final line in _lines) {
      final id = line.part.ownerId?.trim();
      final key = id == null || id.isEmpty ? 'product:${line.part.id}' : id;
      groups.putIfAbsent(key, () => []).add(line);
    }
    return groups;
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
    if (!canEdit || !part.isActive || delta < 1) return;
    final maxStock = part.stockForSale;
    final minQty = part.minOrderQtyEffective;
    if (maxStock < minQty) return;
    final idx = _lines.indexWhere((l) => l.part.id == part.id);
    if (idx >= 0) {
      final existing = _lines[idx];
      final next = existing.quantity + delta;
      existing.quantity = next > maxStock ? maxStock : next;
      if (existing.quantity < minQty) existing.quantity = minQty;
      existing.precioUnitarioAliadoRef =
          existing.part.precioUnitarioParaAliado(quantity: existing.quantity);
    } else {
      var q = delta < minQty ? minQty : delta;
      if (q > maxStock) q = maxStock;
      final cascada = part.precioUnitarioParaAliado(quantity: q);
      _lines.add(
        CartLine(
          part: part,
          quantity: q,
          precioUnitarioAliadoRef:
              cascada > 0 ? cascada : precioUnitarioAliadoRef,
        ),
      );
    }
    _changed();
  }

  void removeProduct(String productId) {
    if (!canEdit) return;
    _lines.removeWhere((l) => l.part.id == productId);
    _changed();
  }

  void setQuantity(String productId, int qty) {
    if (!canEdit) return;
    final idx = _lines.indexWhere((l) => l.part.id == productId);
    if (idx < 0) return;
    final line = _lines[idx];
    final maxStock = line.part.stockForSale;
    final minQty = line.part.minOrderQtyEffective;
    if (qty < 1) {
      _lines.removeAt(idx);
      _changed();
      return;
    }
    var next = qty < minQty ? minQty : qty;
    line.quantity = next > maxStock ? maxStock : next;
    line.precioUnitarioAliadoRef =
        line.part.precioUnitarioParaAliado(quantity: line.quantity);
    _changed();
  }

  void clear() {
    if (!canEdit) return;
    _lines.clear();
    _promoCampaignByImportadorId.clear();
    _changed();
  }

  /// Suma en REF (fuente de verdad); BS solo en UI con tasa.
  double totalRef() => cartLinesSubtotalRef(_lines);

  List<ImporterMinOrderProgress> importerMinOrderProgress() =>
      importerMinOrderProgressFor(supplierGroups.entries);

  bool get meetsAllImporterMinOrders =>
      importerMinOrderProgress().every((e) => e.meets);
}
