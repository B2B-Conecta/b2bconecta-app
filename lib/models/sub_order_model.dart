import 'order_item_model.dart';
import 'sub_order_status.dart';

/// Sub-pedido bajo un `transaction_requests` maestro.
class SubOrderModel {
  const SubOrderModel({
    required this.id,
    required this.parentOrderId,
    required this.importadorId,
    required this.status,
    required this.montoSubtotal,
    required this.itemsCount,
    this.proveedorFacturaStoragePath,
    this.proveedorFacturaFileName,
    this.proveedorFacturaSubmittedAt,
    this.transitEtaDays,
    this.transitEtaHours,
    this.transitEtaSetAt,
    this.importadorBusinessName,
    this.importadorRif,
    this.importadorPhone,
    this.importadorEstado,
    this.importadorCiudad,
    this.importadorDireccion,
    this.importadorFiscalMapsUrl,
    this.importadorLatitude,
    this.importadorLongitude,
    this.recogidaAlmacenAt,
    this.orderItems = const [],
  });

  final String id;
  final String parentOrderId;
  final String importadorId;
  final String status;
  final double montoSubtotal;
  final int itemsCount;
  final String? proveedorFacturaStoragePath;
  final String? proveedorFacturaFileName;
  final DateTime? proveedorFacturaSubmittedAt;
  final int? transitEtaDays;
  final int? transitEtaHours;
  final DateTime? transitEtaSetAt;
  final String? importadorBusinessName;
  final String? importadorRif;
  final String? importadorPhone;
  final String? importadorEstado;
  final String? importadorCiudad;
  final String? importadorDireccion;
  final String? importadorFiscalMapsUrl;
  final double? importadorLatitude;
  final double? importadorLongitude;
  final DateTime? recogidaAlmacenAt;
  final List<OrderItemModel> orderItems;

  bool get recogioEnAlmacen => recogidaAlmacenAt != null;

  bool get hasProveedorFactura =>
      proveedorFacturaStoragePath != null &&
      proveedorFacturaStoragePath!.trim().isNotEmpty;

  double montoSubtotalBs(double tasaBcv) => montoSubtotal * tasaBcv;

  factory SubOrderModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? imp;
    final ir = json['importador'];
    if (ir is Map) {
      imp = Map<String, dynamic>.from(ir);
    }

    final sid = json['id']?.toString() ?? '';
    final itemsRaw = json['order_items'];
    final items = <OrderItemModel>[];
    if (itemsRaw is List) {
      for (final e in itemsRaw) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          m.putIfAbsent('sub_order_id', () => sid);
          items.add(OrderItemModel.fromJson(m));
        }
      }
    }

    return SubOrderModel(
      id: json['id']?.toString() ?? '',
      parentOrderId: json['parent_order_id']?.toString() ?? '',
      importadorId: json['importador_id']?.toString() ?? '',
      status: json['status']?.toString() ?? SubOrderStatus.pendiente,
      montoSubtotal: _asDouble(json['monto_subtotal']),
      itemsCount: _asInt(json['items_count']),
      proveedorFacturaStoragePath:
          _nullableText(json['proveedor_factura_storage_path']),
      proveedorFacturaFileName:
          _nullableText(json['proveedor_factura_file_name']),
      proveedorFacturaSubmittedAt: _parseDate(json['proveedor_factura_submitted_at']),
      transitEtaDays: _asNullableInt(json['transit_eta_days']),
      transitEtaHours: _asNullableInt(json['transit_eta_hours']),
      transitEtaSetAt: _parseDate(json['transit_eta_set_at']),
      importadorBusinessName: _nullableText(imp?['business_name']),
      importadorRif: _nullableText(imp?['rif']),
      importadorPhone: _nullableText(imp?['phone']),
      importadorEstado: _nullableText(imp?['estado']),
      importadorCiudad: _nullableText(imp?['ciudad']),
      importadorDireccion: _nullableText(imp?['direccion']),
      importadorFiscalMapsUrl: _nullableText(imp?['fiscal_maps_url']),
      importadorLatitude: _asDoubleNullable(imp?['latitude']),
      importadorLongitude: _asDoubleNullable(imp?['longitude']),
      recogidaAlmacenAt:
          _parseDate(json['transportista_recogida_almacen_at']),
      orderItems: items,
    );
  }

  static double? _asDoubleNullable(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int? _asNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static String? _nullableText(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
