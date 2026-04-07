/// Fila de `transaction_requests` con joins opcionales (producto, aliado, importador).
class TransactionRequestModel {
  const TransactionRequestModel({
    required this.id,
    required this.aliadoId,
    required this.productId,
    required this.ownerId,
    required this.status,
    required this.cantidad,
    required this.precioUnitarioProveedor,
    required this.precioUnitarioAliado,
    required this.precioTotal,
    this.notasAdmin,
    this.createdAt,
    this.productName,
    this.productSku,
    this.aliadoBusinessName,
    this.aliadoRif,
    this.aliadoCreditScore,
    this.ownerBusinessName,
  });

  final String id;
  final String aliadoId;
  final String productId;
  final String ownerId;
  final String status;
  final int cantidad;
  final double precioUnitarioProveedor;
  final double precioUnitarioAliado;
  final double precioTotal;
  final String? notasAdmin;
  final DateTime? createdAt;
  final String? productName;
  final String? productSku;
  final String? aliadoBusinessName;
  final String? aliadoRif;
  final int? aliadoCreditScore;
  final String? ownerBusinessName;

  factory TransactionRequestModel.fromJson(Map<String, dynamic> json) {
    final products = json['products'];
    String? productName;
    String? productSku;
    if (products is Map) {
      final pm = Map<String, dynamic>.from(products);
      productName = pm['name']?.toString();
      final s = pm['sku']?.toString().trim();
      productSku = (s != null && s.isNotEmpty) ? s : null;
    }

    Map<String, dynamic>? aliadoMap;
    final aliadoRaw = json['aliado'];
    if (aliadoRaw is Map) {
      aliadoMap = Map<String, dynamic>.from(aliadoRaw);
    }

    Map<String, dynamic>? ownerMap;
    final ownerRaw = json['owner'];
    if (ownerRaw is Map) {
      ownerMap = Map<String, dynamic>.from(ownerRaw);
    }

    int? credit;
    final cs = aliadoMap?['credit_score'];
    if (cs is int) {
      credit = cs;
    } else if (cs != null) {
      credit = int.tryParse(cs.toString());
    }

    return TransactionRequestModel(
      id: json['id']?.toString() ?? '',
      aliadoId: json['aliado_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      ownerId: json['owner_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pendiente',
      cantidad: _asInt(json['cantidad']),
      precioUnitarioProveedor: _asDouble(json['precio_unitario_proveedor']),
      precioUnitarioAliado: _asDouble(json['precio_unitario_aliado']),
      precioTotal: _asDouble(json['precio_total']),
      notasAdmin: _nullableText(json['notas_admin']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      productName: productName,
      productSku: productSku,
      aliadoBusinessName: _nullableText(aliadoMap?['business_name']),
      aliadoRif: _nullableText(aliadoMap?['rif']),
      aliadoCreditScore: credit,
      ownerBusinessName: _nullableText(ownerMap?['business_name']),
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
