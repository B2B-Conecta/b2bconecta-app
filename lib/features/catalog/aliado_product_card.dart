import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields_section.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'aliado_catalog_categories.dart';
import 'aliado_catalog_layout.dart';
import 'catalog_cart_price.dart';
import 'catalog_cart_button.dart';
import 'favorite_heart_button.dart';
import 'importer_catalog_logo.dart';
import 'importer_catalog_seals.dart';
import 'part_model.dart';
import 'product_stock_summary.dart';
import 'product_detail_screen.dart';
import 'product_warranty_seal.dart';

String _distanceChipLabel(PartModel part) {
  final km = part.distanceKmFromReference;
  if (km == null) return 'Distancia no disponible';
  if (km < 1) return 'A ${(km * 1000).round()} m';
  return 'A ${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}

/// Product-first hierarchy with the existing pricing and supplier actions.
class AliadoProductCard extends StatelessWidget {
  const AliadoProductCard(
      {super.key,
      required this.part,
      required this.profile,
      this.compact = false,
      this.showDistanceChips = false,
      this.onTap,
      this.onImporterTap});
  final PartModel part;
  final ProfileModel profile;
  final bool compact;
  final bool showDistanceChips;
  final VoidCallback? onTap;
  final VoidCallback? onImporterTap;

  @override
  Widget build(BuildContext context) {
    // Dependencia de Theme: al cambiar claro/oscuro se redibuja la tarjeta/foto.
    final brightness = Theme.of(context).brightness;
    AppColors.brightness = brightness;
    final scaler = MediaQuery.textScalerOf(context);
    final importer = (part.ownerBusinessName ?? '').trim();
    final supplier = importer.isEmpty ? 'Sin proveedor' : importer;
    final hasRating =
        part.ownerRatingAvg != null && (part.ownerRatingCount ?? 0) > 0;
    final hasCustomFields = productCustomFieldsDisplayEntries(part.customFields,
            aliadoView: true, limit: 2)
        .isNotEmpty;
    final shippingIncluded =
        EnvioPolitica.normalize(part.ownerEnvioTipo) == EnvioPolitica.incluido;
    final radius = BorderRadius.circular(AliadoCatalogLayout.cardRadius);
    final accent = Theme.of(context).colorScheme.primary;
    final location = [part.ownerEstado, part.ownerCiudad]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .join(' · ');
    return Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: radius, side: BorderSide(color: AppColors.divider)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Builder(builder: (context) {
            final details = Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Tooltip(
                          message: part.nombre,
                          excludeFromSemantics: true,
                          child: ConstrainedBox(
                              constraints:
                                  BoxConstraints(minHeight: scaler.scale(36)),
                              child: Text(part.nombre,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 15,
                                      height: 1.2,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)))),
                      const SizedBox(height: 6),
                      CatalogCartPrice(part: part),
                      const SizedBox(height: 6),
                      ProductStockSummary(part: part),
                      if (hasCustomFields) ...[
                        const SizedBox(height: 6),
                        ProductCustomFieldsAliadoChips(
                            customFields: part.customFields),
                      ],
                      if (showDistanceChips) ...[
                        const SizedBox(height: 6),
                        Text(_distanceChipLabel(part),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                height: 1.2,
                                color: AppColors.textSecondary)),
                      ] else if (!compact && location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                height: 1.2,
                                color: AppColors.textSecondary)),
                      ],
                    ]));
            final footer = Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(height: 8, color: AppColors.divider),
                      Tooltip(
                          message: onImporterTap == null
                              ? supplier
                              : 'Ver catálogo de $supplier',
                          child: InkWell(
                              onTap: onImporterTap,
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                  height: scaler
                                      .scale(40)
                                      .clamp(44, double.infinity),
                                  child: Row(children: [
                                    ImporterCatalogLogo(
                                        storagePath: part.ownerLogoStoragePath,
                                        size: 16,
                                        fallback: Icon(
                                            Icons.storefront_outlined,
                                            size: 16,
                                            color: AppColors.textSecondary)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          if (part.category
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true)
                                            Text(
                                                formatCatalogCategoryLabel(
                                                    part.category!),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    height: 1.2,
                                                    color: AppColors
                                                        .textSecondary)),
                                          Text(supplier,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  height: 1.2,
                                                  fontWeight: FontWeight.w500,
                                                  color: onImporterTap == null
                                                      ? AppColors.textSecondary
                                                      : accent)),
                                        ])),
                                    if (hasRating) ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.star_rounded,
                                          size: 14,
                                          color: Colors.amber.shade800),
                                      const SizedBox(width: 2),
                                      Text(
                                          part.ownerRatingAvg!
                                              .toStringAsFixed(1),
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary)),
                                    ],
                                  ])))),
                      if (profile.isAliado) ...[
                        const SizedBox(height: 4),
                        CatalogCartButton(part: part, profile: profile),
                      ] else if (onTap != null) ...[
                        const SizedBox(height: 4),
                        FilledButton(
                            onPressed: onTap,
                            style: FilledButton.styleFrom(
                                minimumSize: Size(0, scaler.scale(44)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                textStyle: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            child: Semantics(
                                label: 'Ver repuesto: ${part.nombre}',
                                child: const ExcludeSemantics(
                                    child: Text('Ver repuesto')))),
                      ],
                    ]));
            return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: AspectRatio(
                              aspectRatio: AliadoCatalogLayout.cardImageAspect,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: ColoredBox(
                                      color: AppColors.photoFrameFor(brightness),
                                      child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Hero(
                                                tag: ProductDetailScreen
                                                    .heroImageTag(part),
                                                child: _productPhoto()),
                                            if (part.isCatalogVerified ||
                                                part.isCatalogFeatured)
                                              Positioned(
                                                  top: 8,
                                                  left: 8,
                                                  right: 52,
                                                  child: ImporterCatalogSealsRow(
                                                      verified: part
                                                          .isCatalogVerified,
                                                      featured: part
                                                          .isCatalogFeatured,
                                                      compact: true,
                                                      spacing: 4)),
                                            if (profile.isAliado)
                                              Positioned(
                                                  top: 2,
                                                  right: 2,
                                                  child: FavoriteHeartButton(
                                                      productId: part.id)),
                                            if (part.hasWarranty)
                                              Positioned(
                                                  top: part.isCatalogVerified ||
                                                          part.isCatalogFeatured
                                                      ? 32
                                                      : 8,
                                                  left: 8,
                                                  right: 52,
                                                  child: const Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child:
                                                          ProductWarrantySeal(
                                                              compact: true))),
                                            if (shippingIncluded ||
                                                part.variantChoices.isNotEmpty)
                                              Positioned(
                                                  left: 6,
                                                  right: 6,
                                                  bottom: 6,
                                                  child: Wrap(
                                                      spacing: 4,
                                                      runSpacing: 4,
                                                      children: [
                                                        if (part.variantChoices
                                                            .isNotEmpty)
                                                          _VariantOptionsChip(
                                                              count: part
                                                                  .variantChoices
                                                                  .length),
                                                        if (shippingIncluded)
                                                          const _ShippingIncludedChip(),
                                                      ])),
                                          ]))))),
                      details,
                    ],
                  ),
                  footer,
                ]);
          }),
        ));
  }

  Widget _productPhoto() {
    final url = part.coverImageUrl?.trim();
    if (url == null || url.isEmpty) return const _PhotoPlaceholder();
    return Padding(
        padding: const EdgeInsets.all(10),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) =>
              const _PhotoPlaceholder(failed: true),
          loadingBuilder: (_, image, progress) => progress == null
              ? image
              : const _PhotoPlaceholder(loading: true),
        ));
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.loading = false, this.failed = false});
  final bool loading;
  final bool failed;
  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return ColoredBox(
        color: AppColors.surfaceTintedFor(b),
        child: Center(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      failed
                          ? Icons.broken_image_outlined
                          : Icons.image_outlined,
                      size: 30,
                      color: AppColors.textMutedFor(b)),
                  const SizedBox(height: 6),
                  Text(
                      loading
                          ? 'Cargando foto…'
                          : failed
                              ? 'No se pudo cargar la foto'
                              : 'Foto no disponible',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: AppColors.textSecondaryFor(b))),
                ]))));
  }
}

class _VariantOptionsChip extends StatelessWidget {
  const _VariantOptionsChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        '$count opciones',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          height: 1.1,
        ),
      ),
    );
  }
}

class _ShippingIncludedChip extends StatelessWidget {
  const _ShippingIncludedChip();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.local_shipping_outlined,
            size: 12, color: AppColors.successGreen),
        const SizedBox(width: 4),
        Flexible(
            child: Text('Envío incluido',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary))),
      ]));
}
