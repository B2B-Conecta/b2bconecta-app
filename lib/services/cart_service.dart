import 'package:flutter/foundation.dart';

import '../models/part_model.dart';

/// Línea del carrito del aliado (solo en memoria hasta confirmar checkout).
class CartLine {
  CartLine({
    required this.part,
    required this.quantity,
    required this.precioUnitarioAliadoRef,
  });

  final PartModel part;
  int quantity;

  /// Precio unitario REF acordado al añadir (fase contado / cupo según perfil en ese momento).
  final double precioUnitarioAliadoRef;
}

/// Carrito multi-importador (agrupa por importador en la UI).
class CartService extends ChangeNotifier {
  CartService._();
  static final CartService instance = CartService._();

  final List<CartLine> _lines = [];

  List<CartLine> get lines => List.unmodifiable(_lines);

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

  void addOrIncrement(
    PartModel part, {
    required double precioUnitarioAliadoRef,
    int delta = 1,
  }) {
    final maxStock = part.stock;
    final idx = _lines.indexWhere((l) => l.part.id == part.id);
    if (idx >= 0) {
      final existing = _lines[idx];
      final next = existing.quantity + delta;
      existing.quantity = next > maxStock ? maxStock : next;
      if (existing.quantity < 1) existing.quantity = 1;
    } else {
      var q = delta < 1 ? 1 : delta;
      if (q > maxStock) q = maxStock;
      if (maxStock < 1) return;
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
    if (qty < 1) {
      _lines.removeAt(idx);
      notifyListeners();
      return;
    }
    line.quantity = qty > maxStock ? maxStock : qty;
    notifyListeners();
  }

  void clear() {
    _lines.clear();
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
