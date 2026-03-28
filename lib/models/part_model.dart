/// Modelo de repuesto. Los datos provienen de la tabla Supabase `products`
/// (`owner_id` → `profiles.id`).
class PartModel {
  const PartModel({
    required this.id,
    this.ownerId,
    this.ownerBusinessName,
    required this.nombre,
    this.descripcion,
    this.compatibilidad,
    required this.precio,
    required this.stock,
    this.imagenUrl,
  });

  final String id;

  /// FK `profiles.id` del importador dueño del stock.
  final String? ownerId;

  /// Nombre comercial del dueño (join `profiles`).
  final String? ownerBusinessName;
  final String nombre;
  final String? descripcion;
  final String? compatibilidad;
  final double precio;
  final int stock;
  final String? imagenUrl;

  factory PartModel.fromJson(Map<String, dynamic> json) {
    // Tabla `products`: owner_id, name, description, compatibility, price_usd, stock, image_url.
    final nombreRaw = json['name'] ?? json['nombre'];
    final descripcionRaw = json['description'] ?? json['descripcion'];
    final compatibilidadRaw = json['compatibility'] ?? json['compatibilidad'];
    final precioRaw = json['price_usd'] ?? json['price'] ?? json['precio'];
    final imagenRaw = json['image_url'] ?? json['imagen_url'];

    final ownerBusinessName = _ownerBusinessNameFromProfiles(json['profiles']);

    return PartModel(
      id: json['id']?.toString() ?? '',
      ownerId: _nullableUuid(json['owner_id']),
      ownerBusinessName: ownerBusinessName,
      nombre: nombreRaw?.toString() ?? '',
      descripcion: _nullableText(descripcionRaw),
      compatibilidad: _nullableText(compatibilidadRaw),
      precio: _asDouble(precioRaw),
      stock: _asInt(json['stock']),
      imagenUrl: _nullableUrl(imagenRaw),
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
