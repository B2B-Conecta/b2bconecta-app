/// Modelo de repuesto. Los datos provienen de la tabla Supabase `products`
/// (columnas típicas en inglés: name, price, stock, image_url).
class PartModel {
  const PartModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.compatibilidad,
    required this.precio,
    required this.stock,
    this.imagenUrl,
  });

  final String id;
  final String nombre;
  final String? descripcion;
  final String? compatibilidad;
  final double precio;
  final int stock;
  final String? imagenUrl;

  factory PartModel.fromJson(Map<String, dynamic> json) {
    // Tabla `products`: name, description, compatibility, price_usd, stock, image_url.
    final nombreRaw = json['name'] ?? json['nombre'];
    final descripcionRaw = json['description'] ?? json['descripcion'];
    final compatibilidadRaw = json['compatibility'] ?? json['compatibilidad'];
    final precioRaw = json['price_usd'] ?? json['price'] ?? json['precio'];
    final imagenRaw = json['image_url'] ?? json['imagen_url'];

    return PartModel(
      id: json['id']?.toString() ?? '',
      nombre: nombreRaw?.toString() ?? '',
      descripcion: _nullableText(descripcionRaw),
      compatibilidad: _nullableText(compatibilidadRaw),
      precio: _asDouble(precioRaw),
      stock: _asInt(json['stock']),
      imagenUrl: _nullableUrl(imagenRaw),
    );
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
