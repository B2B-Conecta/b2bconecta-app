import 'package:motolink_pro_app/features/cart/min_order_currency.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo.dart';

/// Ficha pública de un mayorista activo (`aliado_importer_store_profile`).
class ImporterStoreProfile {
  const ImporterStoreProfile({
    required this.id,
    this.businessName,
    this.rif,
    this.phone,
    this.estado,
    this.ciudad,
    this.direccion,
    this.fiscalMapsUrl,
    this.logoStoragePath,
    this.ratingAvg,
    this.ratingCount,
    this.minOrderAmountRef = 0,
    this.minOrderCurrency = MinOrderCurrency.ref,
    this.catalogFeaturedUntil,
    this.catalogVerifiedAt,
    this.pagoSoloDivisas = false,
    this.acceptedPagoMetodos = const [],
  });

  final String id;
  final String? businessName;
  final String? rif;
  final String? phone;
  final String? estado;
  final String? ciudad;
  final String? direccion;
  final String? fiscalMapsUrl;
  final String? logoStoragePath;
  final double? ratingAvg;
  final int? ratingCount;
  final double minOrderAmountRef;
  final MinOrderCurrency minOrderCurrency;
  final DateTime? catalogFeaturedUntil;
  final DateTime? catalogVerifiedAt;
  final bool pagoSoloDivisas;
  final List<String> acceptedPagoMetodos;

  bool get isCatalogFeatured {
    final until = catalogFeaturedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  bool get isCatalogVerified => catalogVerifiedAt != null;

  String get displayName {
    final n = businessName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Mayorista';
  }

  String get locationLine {
    final e = estado?.trim();
    final c = ciudad?.trim();
    if ((e == null || e.isEmpty) && (c == null || c.isEmpty)) return '';
    if (e != null && e.isNotEmpty && c != null && c.isNotEmpty) {
      return '$e · $c';
    }
    return e ?? c ?? '';
  }

  bool get hasMinOrder => minOrderAmountRef > 0;

  String get minOrderLabelEs =>
      'Pedido mín. ${formatMinOrderAmount(minOrderAmountRef, minOrderCurrency)}';

  List<String> get pagoMetodoLabelsEs {
    final codes = PagoMetodo.filterByImporterAccepted(
      acceptedPagoMetodos,
      pagoSoloDivisas: pagoSoloDivisas,
    );
    return codes.map(PagoMetodo.labelEs).toList();
  }

  factory ImporterStoreProfile.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '');
    }

    int? asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '');
    }

    List<String> metodos(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return ImporterStoreProfile(
      id: json['id']?.toString() ?? '',
      businessName: json['business_name']?.toString(),
      rif: json['rif']?.toString(),
      phone: json['phone']?.toString(),
      estado: json['estado']?.toString(),
      ciudad: json['ciudad']?.toString(),
      direccion: json['direccion']?.toString(),
      fiscalMapsUrl: json['fiscal_maps_url']?.toString(),
      logoStoragePath: json['logo_storage_path']?.toString(),
      ratingAvg: asDouble(json['rating_avg_received_rolling100']),
      ratingCount: asInt(json['rating_count_received_rolling100']),
      minOrderAmountRef: asDouble(json['min_order_amount_ref']) ?? 0,
      minOrderCurrency: MinOrderCurrency.parse(
        json['min_order_currency']?.toString(),
      ),
      catalogFeaturedUntil: json['catalog_featured_until'] != null
          ? DateTime.tryParse(json['catalog_featured_until'].toString())
          : null,
      catalogVerifiedAt: json['catalog_verified_at'] != null
          ? DateTime.tryParse(json['catalog_verified_at'].toString())
          : null,
      pagoSoloDivisas: json['pago_solo_divisas'] == true,
      acceptedPagoMetodos: metodos(json['accepted_pago_metodos']),
    );
  }
}

/// Aislamiento de vitrina: el producto tiene que ser de ese mayorista y estar activo.
bool catalogPartBelongsToImporterStore({
  required String importerId,
  required String? ownerId,
  required bool isActive,
}) {
  final owner = ownerId?.trim() ?? '';
  final want = importerId.trim();
  if (want.isEmpty || owner.isEmpty) return false;
  return owner == want && isActive;
}

/// Descarta filas que no coincidan con el mayorista, visibilidad o categoría.
List<PartModel> constrainCatalogPartsToFilters(
  Iterable<PartModel> parts,
  CatalogFilters filters,
) {
  final owners = filters.effectiveOwnerIds.toSet();
  final cat = filters.category?.trim();
  return parts.where((p) {
    if (owners.isNotEmpty) {
      final oid = p.ownerId?.trim() ?? '';
      if (!owners.contains(oid)) return false;
    }
    if (filters.onlyActiveProducts && !p.isActive) return false;
    if (cat != null && cat.isNotEmpty && (p.category ?? '').trim() != cat) {
      return false;
    }
    return true;
  }).toList();
}

List<PartModel> retainImporterStoreCatalogParts({
  required String importerId,
  required Iterable<PartModel> parts,
  String? category,
}) {
  return constrainCatalogPartsToFilters(
    parts,
    CatalogFilters.importerStore(importerId: importerId, category: category),
  );
}
