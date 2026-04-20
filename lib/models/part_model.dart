import '../utils/broker_pricing.dart';

/// Modelo de repuesto. Los datos provienen de la tabla Supabase `products`
/// (`owner_id` → `profiles.id`).
class PartModel {
  const PartModel({
    required this.id,
    this.ownerId,
    this.ownerBusinessName,
    this.ownerEstado,
    this.ownerCiudad,
    required this.nombre,
    this.descripcion,
    this.compatibilidad,
    required this.precio,
    required this.stock,
    this.imagenUrl,
    this.sku,
    this.isActive = true,
    this.category,
  });

  final String id;

  /// FK `profiles.id` del importador dueño del stock.
  final String? ownerId;

  /// Nombre comercial del dueño (join `profiles`).
  final String? ownerBusinessName;

  /// Ubicación del importador (`profiles.estado` / `ciudad`).
  final String? ownerEstado;
  final String? ownerCiudad;

  final String nombre;
  final String? descripcion;
  final String? compatibilidad;

  /// Precio mayorista USD cargado por el importador (`products.price_usd`).
  final double precio;
  final int stock;
  final String? imagenUrl;

  /// Llave de negocio por importador (tabla `products.sku`).
  final String? sku;

  /// `false` = modo pausa (no visible para aliados).
  final bool isActive;

  final String? category;

  /// Precio unitario final MotoLink (mayorista + comisión broker).
  double get precioFinalUnitario => BrokerPricing.finalUnitPrice(precio);

  /// Precio de venta al aliado: mismo que [precioFinalUnitario] salvo en fase contado (descuento promocional).
  double precioUnitarioParaAliado({required bool faseContado}) =>
      BrokerPricing.unitPriceForAliado(precio, faseContado: faseContado);

  factory PartModel.fromJson(Map<String, dynamic> json) {
    // Tabla `products`: owner_id, name, description, compatibility, price_usd, stock, image_url.
    final nombreRaw = json['name'] ?? json['nombre'];
    final descripcionRaw = json['description'] ?? json['descripcion'];
    final compatibilidadRaw = json['compatibility'] ?? json['compatibilidad'];
    final precioRaw = json['price_usd'] ?? json['price'] ?? json['precio'];
    final imagenRaw = json['image_url'] ?? json['imagen_url'];

    final ownerBusinessName = _ownerBusinessNameFromProfiles(json['profiles']);
    final loc = _ownerLocationFromProfiles(json['profiles']);

    final isActiveRaw = json['is_active'];
    final isActive = isActiveRaw is bool
        ? isActiveRaw
        : (isActiveRaw == null ? true : isActiveRaw.toString() == 'true');

    return PartModel(
      id: json['id']?.toString() ?? '',
      ownerId: _nullableUuid(json['owner_id']),
      ownerBusinessName: ownerBusinessName,
      ownerEstado: loc.$1,
      ownerCiudad: loc.$2,
      nombre: nombreRaw?.toString() ?? '',
      descripcion: _nullableText(descripcionRaw),
      compatibilidad: _nullableText(compatibilidadRaw),
      precio: _asDouble(precioRaw),
      stock: _asInt(json['stock']),
      imagenUrl: _nullableUrl(imagenRaw),
      sku: _nullableText(json['sku']),
      isActive: isActive,
      category: _nullableText(json['category']),
    );
  }

  PartModel copyWith({
    String? id,
    String? ownerId,
    String? ownerBusinessName,
    String? ownerEstado,
    String? ownerCiudad,
    String? nombre,
    String? descripcion,
    String? compatibilidad,
    double? precio,
    int? stock,
    String? imagenUrl,
    String? sku,
    bool? isActive,
    String? category,
  }) {
    return PartModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerBusinessName: ownerBusinessName ?? this.ownerBusinessName,
      ownerEstado: ownerEstado ?? this.ownerEstado,
      ownerCiudad: ownerCiudad ?? this.ownerCiudad,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      compatibilidad: compatibilidad ?? this.compatibilidad,
      precio: precio ?? this.precio,
      stock: stock ?? this.stock,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      sku: sku ?? this.sku,
      isActive: isActive ?? this.isActive,
      category: category ?? this.category,
    );
  }

  static String? _nullableUuid(dynamic v) {
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  /// PostgREST devuelve `profiles` como objeto anidado al hacer select con join.
  static String? _ownerBusinessNameFromProfiles(dynamic profiles) {
    if (profiles == null) return null;
    if (profiles is Map) {
      final m = Map<String, dynamic>.from(profiles);
      return _nullableText(m['business_name']);
    }
    if (profiles is List && profiles.isNotEmpty) {
      final first = profiles.first;
      if (first is Map) {
        return _nullableText(
          Map<String, dynamic>.from(first)['business_name'],
        );
      }
    }
    return null;
  }

  static (String?, String?) _ownerLocationFromProfiles(dynamic profiles) {
    if (profiles == null) return (null, null);
    Map<String, dynamic>? m;
    if (profiles is Map) {
      m = Map<String, dynamic>.from(profiles);
    } else if (profiles is List && profiles.isNotEmpty) {
      final first = profiles.first;
      if (first is Map) m = Map<String, dynamic>.from(first);
    }
    if (m == null) return (null, null);
    return (_nullableText(m['estado']), _nullableText(m['ciudad']));
  }

  static String? _nullableText(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _nullableUrl(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
