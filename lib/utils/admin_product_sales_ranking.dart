import '../models/transaction_request_model.dart';

/// Agregado de ventas por producto para reportes admin.
class AdminProductSalesStat {
  const AdminProductSalesStat({
    required this.productKey,
    required this.productId,
    required this.productName,
    this.productSku,
    this.importerName,
    required this.orderCount,
    required this.unitsSold,
    required this.totalRefUsd,
  });

  final String productKey;
  final String productId;
  final String productName;
  final String? productSku;
  final String? importerName;
  final int orderCount;
  final int unitsSold;
  final double totalRefUsd;
}

String adminProductSalesKey(TransactionRequestModel r) {
  final id = r.productId.trim();
  if (id.isNotEmpty) return id;
  final sku = r.productSku?.trim() ?? '';
  final name = r.productName?.trim() ?? '';
  return '$sku|$name|${r.ownerId}';
}

/// Agrupa pedidos por producto y ordena por unidades vendidas (desc).
List<AdminProductSalesStat> aggregateProductSales(
  List<TransactionRequestModel> rows,
) {
  final map = <String, _MutableProductSales>{};

  for (final r in rows) {
    final key = adminProductSalesKey(r);
    final entry = map.putIfAbsent(
      key,
      () => _MutableProductSales(
        productKey: key,
        productId: r.productId,
        productName: r.productName?.trim().isNotEmpty == true
            ? r.productName!.trim()
            : 'Producto',
        productSku: r.productSku?.trim(),
        importerName: r.ownerBusinessName?.trim(),
      ),
    );
    entry.orderCount++;
    entry.unitsSold += r.cantidad;
    entry.totalRefUsd += r.precioTotal;
    if (entry.productSku == null || entry.productSku!.isEmpty) {
      final sku = r.productSku?.trim();
      if (sku != null && sku.isNotEmpty) entry.productSku = sku;
    }
    if (entry.importerName == null || entry.importerName!.isEmpty) {
      final imp = r.ownerBusinessName?.trim();
      if (imp != null && imp.isNotEmpty) entry.importerName = imp;
    }
  }

  final out = map.values
      .map(
        (m) => AdminProductSalesStat(
          productKey: m.productKey,
          productId: m.productId,
          productName: m.productName,
          productSku: m.productSku,
          importerName: m.importerName,
          orderCount: m.orderCount,
          unitsSold: m.unitsSold,
          totalRefUsd: m.totalRefUsd,
        ),
      )
      .toList()
    ..sort((a, b) {
      final byUnits = b.unitsSold.compareTo(a.unitsSold);
      if (byUnits != 0) return byUnits;
      return b.totalRefUsd.compareTo(a.totalRefUsd);
    });
  return out;
}

Set<String> topProductKeys(
  List<TransactionRequestModel> rows, {
  required int limit,
}) {
  if (limit <= 0) return {};
  final stats = aggregateProductSales(rows);
  return stats.take(limit).map((s) => s.productKey).toSet();
}

class _MutableProductSales {
  _MutableProductSales({
    required this.productKey,
    required this.productId,
    required this.productName,
    this.productSku,
    this.importerName,
  });

  final String productKey;
  final String productId;
  final String productName;
  String? productSku;
  String? importerName;
  int orderCount = 0;
  int unitsSold = 0;
  double totalRefUsd = 0;
}
