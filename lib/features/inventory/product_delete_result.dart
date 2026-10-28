import 'package:supabase_flutter/supabase_flutter.dart';

/// Motivo por el que un SKU no se pudo borrar.
enum ProductDeleteBlockReason {
  /// Referenciado en `replacement_orders` (historial de postventa).
  replacementHistory,

  /// Otra FK de integridad (sin cascade).
  foreignKey,

  /// Error no clasificado.
  other,
}

/// Producto que el borrado no pudo quitar.
class ProductDeleteBlockedItem {
  const ProductDeleteBlockedItem({
    required this.id,
    required this.label,
    required this.reason,
  });

  final String id;
  final String label;
  final ProductDeleteBlockReason reason;
}

/// Resultado de borrar uno o varios productos (éxitos + bloqueados).
class ProductDeleteBatchResult {
  const ProductDeleteBatchResult({
    this.deletedIds = const [],
    this.blocked = const [],
  });

  final List<String> deletedIds;
  final List<ProductDeleteBlockedItem> blocked;

  int get deletedCount => deletedIds.length;
  int get blockedCount => blocked.length;
  bool get hasDeleted => deletedIds.isNotEmpty;
  bool get hasBlocked => blocked.isNotEmpty;
  bool get isEmpty => deletedIds.isEmpty && blocked.isEmpty;
  bool get allSucceeded => hasDeleted && !hasBlocked;
  bool get allBlocked => !hasDeleted && hasBlocked;
  bool get isMixed => hasDeleted && hasBlocked;

  List<String> get blockedIds => [for (final item in blocked) item.id];
}

/// Clasifica errores Postgres/PostgREST de borrado de inventario.
abstract final class ProductDeleteErrors {
  static const foreignKeyCode = '23503';

  static String _blob(Object error) {
    if (error is PostgrestException) {
      return '${error.code} ${error.message} ${error.details} ${error.hint}'
          .toLowerCase();
    }
    return error.toString().toLowerCase();
  }

  static bool isForeignKeyViolation(Object error) {
    if (error is PostgrestException) {
      if (error.code?.trim() == foreignKeyCode) return true;
    }
    final blob = _blob(error);
    return blob.contains(foreignKeyCode) ||
        blob.contains('foreign key') ||
        blob.contains('violates foreign key');
  }

  static ProductDeleteBlockReason classify(Object error) {
    if (!isForeignKeyViolation(error)) return ProductDeleteBlockReason.other;
    final blob = _blob(error);
    if (blob.contains('replacement_orders')) {
      return ProductDeleteBlockReason.replacementHistory;
    }
    return ProductDeleteBlockReason.foreignKey;
  }

  /// Texto corto por ítem bloqueado (lista en el diálogo).
  static String reasonLabel(ProductDeleteBlockReason reason) {
    return switch (reason) {
      ProductDeleteBlockReason.replacementHistory =>
        'Tiene historial de pedidos de reemplazo / postventa',
      ProductDeleteBlockReason.foreignKey =>
        'Está vinculado a registros históricos del sistema',
      ProductDeleteBlockReason.other => 'No se pudo eliminar',
    };
  }
}
