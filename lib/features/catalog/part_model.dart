import 'package:motolink_pro_app/features/inventory/product_custom_fields.dart';
import 'package:motolink_pro_app/features/inventory/product_images.dart';
import 'package:motolink_pro_app/features/payments/broker_pricing.dart';
import 'product_catalog_pricing.dart';
import 'package:motolink_pro_app/features/inventory/product_min_order_qty.dart';
import 'package:motolink_pro_app/features/inventory/product_volume_tiers.dart';

/// Modelo de repuesto. Los datos provienen de la tabla Supabase `products`
/// (`owner_id` → `profiles.id`).
class PartModel {
  const PartModel({
    required this.id,
    this.ownerId,
    this.ownerBusinessName,
    this.ownerLogoStoragePath,
    this.ownerEstado,
    this.ownerCiudad,
    required this.nombre,
    this.descripcion,
    this.compatibilidad,
    required this.precio,
    required this.stock,
    this.minOrderQty = ProductMinOrderQty.platformFloor,
    this.imagenUrl,
    this.imageUrls = const [],
    this.sku,
    this.isActive = true,
    this.category,
    this.ownerLatitude,
    this.ownerLongitude,
    this.distanceKmFromReference,
    this.ownerRatingAvg,
    this.ownerRatingCount,
    this.ownerCatalogPaidOrders30d,
    this.salePriceUsd,
    this.discountRules,
    this.ownerPagoSoloDivisas = false,
    this.hasWarranty = false,
    this.customFields = const {},
  });

  final String id;

  /// FK `profiles.id` del importador dueño del stock.
  final String? ownerId;

  /// Nombre comercial del dueño (join `profiles`).
  final String? ownerBusinessName;

  /// Foto de perfil del importador (`profiles.logo_storage_path`).
  final String? ownerLogoStoragePath;

  /// Ubicación del importador (`profiles.estado` / `ciudad`).
  final String? ownerEstado;
  final String? ownerCiudad;

  final String nombre;
  final String? descripcion;
  final String? compatibilidad;

  /// Precio mayorista USD cargado por el importador (`products.price_usd`).
  final double precio;
  final int stock;

  /// Unidades mínimas para crear un pedido (`products.min_order_qty`, piso 5).
  final int minOrderQty;

  final String? imagenUrl;

  /// Hasta [kMaxProductImages] URLs (`products.image_urls`). Portada = índice 0.
  final List<String> imageUrls;

  /// Llave de negocio por importador (tabla `products.sku`).
  final String? sku;

  /// `false` = modo pausa (no visible para aliados).
  final bool isActive;

  final String? category;

  /// Coordenadas WGS84 del importador (`profiles`), si existen.
  final double? ownerLatitude;
  final double? ownerLongitude;

  /// Distancia al punto de referencia del aliado (GPS); la calcula el cliente al ordenar.
  final double? distanceKmFromReference;

  /// Reputación rolling del importador (`profiles.rating_avg_received_rolling100`, E2.1).
  final double? ownerRatingAvg;
  final int? ownerRatingCount;

  /// Pedidos pagados confirmados por el importador en ventana E1 (`profiles.catalog_paid_orders_30d`).
  final int? ownerCatalogPaidOrders30d;

  /// E4: precio mayorista promocional USD (`products.sale_price_usd`).
  final double? salePriceUsd;

  /// E4: tramos por volumen (`volume_tiers` con `min_units`).
  final Map<String, dynamic>? discountRules;

  /// Importador dueño: solo acepta pagos en divisas (sin descuento línea USD).
  final bool ownerPagoSoloDivisas;

  /// Importador habilitó garantía en este producto (`products.has_warranty`).
  final bool hasWarranty;

  /// Campos ERP adicionales (`products.custom_fields`).
  final Map<String, dynamic> customFields;

  /// URL de portada para listados (compat legacy + multi-foto).
  String? get coverImageUrl =>
      productCoverImageUrl(imageUrls, legacy: imagenUrl);

  bool get tieneOfertaDirecta => ProductCatalogPricing.hasDirectSale(
        listPriceUsd: precio,
        salePriceUsd: salePriceUsd,
      );

  List<ProductVolumeTier> get volumeTiers =>
      parseProductVolumeTiers(discountRules);

  int get minOrderQtyEffective => ProductMinOrderQty.resolve(minOrderQty);

  bool get stockCoversMinOrder => ProductMinOrderQty.stockCovers(
        stock: stock,
        minOrderQty: minOrderQty,
      );

  String get minOrderQtyLabelEs => 'Mín. $minOrderQtyEffective uds';

  /// Precio unitario para aliado sin markup broker (legacy; preferir [precioUnitarioParaAliado]).
  double get precioFinalUnitario => BrokerPricing.finalUnitPrice(precio);

  /// Precio de venta al aliado (cascada E4; sin tramo volumen si [quantity] = 1 en grid).
  double precioUnitarioParaAliado({int quantity = 1}) =>
      ProductCatalogPricing.aliadoUnitUsd(
        listPriceUsd: precio,
        salePriceUsd: salePriceUsd,
        discountRules: discountRules,
        quantity: quantity,
      );

  factory PartModel.fromJson(Map<String, dynamic> json) {
    // Tabla `products`: owner_id, name, description, compatibility, price_usd, stock, image_url.
    final nombreRaw = json['name'] ?? json['nombre'];
    final descripcionRaw = json['description'] ?? json['descripcion'];
    final compatibilidadRaw = json['compatibility'] ?? json['compatibilidad'];
    final precioRaw = json['price_usd'] ?? json['price'] ?? json['precio'];
    final saleRaw = json['sale_price_usd'];
    final imagenRaw = json['image_url'] ?? json['imagen_url'];
    final imageUrls = parseProductImageUrlsJson(
      json['image_urls'],
      legacyImageUrl: imagenRaw?.toString(),
    );

    final ownerBusinessName = _ownerBusinessNameFromProfiles(json['profiles']);
    final ownerLogoStoragePath =
        _ownerLogoStoragePathFromProfiles(json['profiles']);
    final loc = _ownerLocationFromProfiles(json['profiles']);
    final ownerLatLng = _ownerLatLngFromProfiles(json['profiles']);
    final rep = _ownerReputationFromProfiles(json['profiles']);
    final boost = _ownerCatalogBoostFromProfiles(json['profiles']);
    final soloDivisas = _ownerPagoSoloDivisasFromProfiles(json['profiles']);

    final isActiveRaw = json['is_active'];
    final isActive = isActiveRaw is bool
        ? isActiveRaw
        : (isActiveRaw == null ? true : isActiveRaw.toString() == 'true');

    final warrantyRaw = json['has_warranty'];
    final hasWarranty = warrantyRaw is bool
        ? warrantyRaw
        : warrantyRaw?.toString().toLowerCase() == 'true';

    return PartModel(
      id: json['id']?.toString() ?? '',
      ownerId: _nullableUuid(json['owner_id']),
      ownerBusinessName: ownerBusinessName,
      ownerLogoStoragePath: ownerLogoStoragePath,
      ownerEstado: loc.$1,
      ownerCiudad: loc.$2,
      ownerLatitude: ownerLatLng.$1,
      ownerLongitude: ownerLatLng.$2,
      ownerRatingAvg: rep.$1,
      ownerRatingCount: rep.$2,
      ownerCatalogPaidOrders30d: boost,
      ownerPagoSoloDivisas: soloDivisas,
      nombre: nombreRaw?.toString() ?? '',
      descripcion: _nullableText(descripcionRaw),
      compatibilidad: _nullableText(compatibilidadRaw),
      precio: _asDouble(precioRaw),
      salePriceUsd: _asNullableDouble(saleRaw),
      discountRules: _discountRulesFromJson(json['discount_rules']),
      stock: _asInt(json['stock']),
      minOrderQty: ProductMinOrderQty.resolve(_asInt(json['min_order_qty'])),
      imagenUrl: productCoverImageUrl(
        imageUrls,
        legacy: _nullableUrl(imagenRaw),
      ),
      imageUrls: imageUrls,
      sku: _nullableText(json['sku']),
      isActive: isActive,
      category: _nullableText(json['category']),
      distanceKmFromReference: null,
      hasWarranty: hasWarranty,
      customFields: parseProductCustomFieldsJson(json['custom_fields']),
    );
  }

  PartModel copyWith({
    String? id,
    String? ownerId,
    String? ownerBusinessName,
    String? ownerLogoStoragePath,
    String? ownerEstado,
    String? ownerCiudad,
    String? nombre,
    String? descripcion,
    String? compatibilidad,
    double? precio,
    int? stock,
    int? minOrderQty,
    String? imagenUrl,
    List<String>? imageUrls,
    String? sku,
    bool? isActive,
    String? category,
    double? ownerLatitude,
    double? ownerLongitude,
    double? distanceKmFromReference,
    double? ownerRatingAvg,
    int? ownerRatingCount,
    int? ownerCatalogPaidOrders30d,
    double? salePriceUsd,
    Map<String, dynamic>? discountRules,
    bool? ownerPagoSoloDivisas,
    bool? hasWarranty,
    Map<String, dynamic>? customFields,
  }) {
    return PartModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerBusinessName: ownerBusinessName ?? this.ownerBusinessName,
      ownerLogoStoragePath:
          ownerLogoStoragePath ?? this.ownerLogoStoragePath,
      ownerEstado: ownerEstado ?? this.ownerEstado,
      ownerCiudad: ownerCiudad ?? this.ownerCiudad,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      compatibilidad: compatibilidad ?? this.compatibilidad,
      precio: precio ?? this.precio,
      stock: stock ?? this.stock,
      minOrderQty: minOrderQty ?? this.minOrderQty,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      sku: sku ?? this.sku,
      isActive: isActive ?? this.isActive,
      category: category ?? this.category,
      ownerLatitude: ownerLatitude ?? this.ownerLatitude,
      ownerLongitude: ownerLongitude ?? this.ownerLongitude,
      distanceKmFromReference:
          distanceKmFromReference ?? this.distanceKmFromReference,
      ownerRatingAvg: ownerRatingAvg ?? this.ownerRatingAvg,
      ownerRatingCount: ownerRatingCount ?? this.ownerRatingCount,
      ownerCatalogPaidOrders30d:
          ownerCatalogPaidOrders30d ?? this.ownerCatalogPaidOrders30d,
      salePriceUsd: salePriceUsd ?? this.salePriceUsd,
      discountRules: discountRules ?? this.discountRules,
      ownerPagoSoloDivisas:
          ownerPagoSoloDivisas ?? this.ownerPagoSoloDivisas,
      hasWarranty: hasWarranty ?? this.hasWarranty,
      customFields: customFields ?? this.customFields,
    );
  }

  static double? _asNullableDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static Map<String, dynamic>? _discountRulesFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static int? _ownerCatalogBoostFromProfiles(dynamic profiles) {
    if (profiles == null) return null;
    Map<String, dynamic>? m;
    if (profiles is Map) {
      m = Map<String, dynamic>.from(profiles);
    } else if (profiles is List && profiles.isNotEmpty && profiles.first is Map) {
      m = Map<String, dynamic>.from(profiles.first as Map);
    }
    if (m == null) return null;
    final v = m['catalog_paid_orders_30d'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  static bool _ownerPagoSoloDivisasFromProfiles(dynamic profiles) {
    if (profiles == null) return false;
    Map<String, dynamic>? m;
    if (profiles is Map) {
      m = Map<String, dynamic>.from(profiles);
    } else if (profiles is List && profiles.isNotEmpty && profiles.first is Map) {
      m = Map<String, dynamic>.from(profiles.first as Map);
    }
    if (m == null) return false;
    final raw = m['pago_solo_divisas'];
    if (raw is bool) return raw;
    return raw?.toString().toLowerCase() == 'true';
  }

  static (double?, int?) _ownerReputationFromProfiles(dynamic profiles) {
    if (profiles == null) return (null, null);
    Map<String, dynamic>? m;
    if (profiles is Map) {
      m = Map<String, dynamic>.from(profiles);
    } else if (profiles is List && profiles.isNotEmpty && profiles.first is Map) {
      m = Map<String, dynamic>.from(profiles.first as Map);
    }
    if (m == null) return (null, null);
    double? avg;
    final a = m['rating_avg_received_rolling100'] ?? m['rating_avg_received'];
    if (a is num) {
      avg = a.toDouble();
    } else {
      avg = double.tryParse(a?.toString() ?? '');
    }
    int? cnt;
    final c =
        m['rating_count_received_rolling100'] ?? m['rating_count_received'];
    if (c is int) {
      cnt = c;
    } else if (c is num) {
      cnt = c.toInt();
    } else {
      cnt = int.tryParse(c?.toString() ?? '');
    }
    return (avg, cnt);
  }

  static String? _nullableUuid(dynamic v) {
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  /// PostgREST devuelve `profiles` como objeto anidado al hacer select con join.
  static String? _ownerBusinessNameFromProfiles(dynamic profiles) {
    return _profileFieldFromProfiles(profiles, 'business_name');
  }

  static String? _ownerLogoStoragePathFromProfiles(dynamic profiles) {
    return _profileFieldFromProfiles(profiles, 'logo_storage_path');
  }

  static String? _profileFieldFromProfiles(dynamic profiles, String field) {
    if (profiles == null) return null;
    if (profiles is Map) {
      final m = Map<String, dynamic>.from(profiles);
      return _nullableText(m[field]);
    }
    if (profiles is List && profiles.isNotEmpty) {
      final first = profiles.first;
      if (first is Map) {
        return _nullableText(Map<String, dynamic>.from(first)[field]);
      }
    }
    return null;
  }

  static (double?, double?) _ownerLatLngFromProfiles(dynamic profiles) {
    Map<String, dynamic>? m;
    if (profiles == null) return (null, null);
    if (profiles is Map) {
      m = Map<String, dynamic>.from(profiles);
    } else if (profiles is List && profiles.isNotEmpty) {
      final first = profiles.first;
      if (first is Map) m = Map<String, dynamic>.from(first);
    }
    if (m == null) return (null, null);
    final la = m['latitude'];
    final lo = m['longitude'];
    double? lat;
    double? lng;
    if (la is num) {
      lat = la.toDouble();
    } else if (la != null) {
      lat = double.tryParse(la.toString());
    }
    if (lo is num) {
      lng = lo.toDouble();
    } else if (lo != null) {
      lng = double.tryParse(lo.toString());
    }
    return (lat, lng);
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
