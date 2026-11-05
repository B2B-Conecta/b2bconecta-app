import 'package:motolink_pro_app/features/inventory/product_images.dart';

/// Fila lista para mostrar nombre/SKU/cantidad/precio (desglose en UI).
class PedidoProductoLineUi {
  const PedidoProductoLineUi({
    required this.nombre,
    this.sku,
    required this.cantidad,
    required this.precioRef,
    this.imageUrl,
  });

  final String nombre;
  final String? sku;
  final int cantidad;
  final double precioRef;
  final String? imageUrl;

  factory PedidoProductoLineUi.fromOrderItem(OrderItemModel o) {
    final n = o.productName?.trim();
    return PedidoProductoLineUi(
      nombre: (n != null && n.isNotEmpty) ? n : 'Producto',
      sku: o.productSku,
      cantidad: o.cantidad,
      precioRef: o.precioLineTotal,
      imageUrl: productCoverImageUrl(o.productImageUrls),
    );
  }
}

/// Línea de `order_items` (pedido multi-importador).
class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.subOrderId,
    required this.productId,
    required this.importadorId,
    required this.cantidad,
    required this.precioUnitarioProveedor,
    required this.precioUnitarioAliado,
    required this.precioLineTotal,
    required this.precioBaseAliadoLine,
    this.productName,
    this.productSku,
    this.productImageUrls = const <String>[],
  });

  final String id;
  final String subOrderId;
  final String productId;
  final String importadorId;
  final int cantidad;
  final double precioUnitarioProveedor;
  final double precioUnitarioAliado;
  final double precioLineTotal;
  final double precioBaseAliadoLine;
  final String? productName;
  final String? productSku;
  final List<String> productImageUrls;

  /// Montos en REF (USD); BS solo en UI vía [precioLineTotalBs] con tasa snapshot.
  double precioLineTotalBs(double tasaBcv) => precioLineTotal * tasaBcv;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? prod;
    final pr = json['products'];
    if (pr is Map) {
      prod = Map<String, dynamic>.from(pr);
    }
    final sku = prod?['sku']?.toString().trim();
    return OrderItemModel(
      id: json['id']?.toString() ?? '',
      subOrderId: json['sub_order_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      importadorId: json['importador_id']?.toString() ?? '',
      cantidad: _asInt(json['cantidad']),
      precioUnitarioProveedor: _asDouble(json['precio_unitario_proveedor']),
      precioUnitarioAliado: _asDouble(json['precio_unitario_aliado']),
      precioLineTotal: _asDouble(json['precio_line_total']),
      precioBaseAliadoLine: _asDouble(json['precio_base_aliado_line']),
      productName: _nullableText(prod?['name']),
      productSku: (sku != null && sku.isNotEmpty) ? sku : null,
      productImageUrls: parseProductImageUrlsJson(
        prod?['image_urls'],
        legacyImageUrl: prod?['image_url']?.toString(),
      ),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String? _nullableText(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
