import 'package:flutter/material.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields_section.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'aliado_catalog_layout.dart';
import 'aliado_catalog_web_panel.dart';
import 'catalog_cart_price.dart';
import 'catalog_cart_button.dart';
import 'favorite_heart_button.dart';
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
      this.webChrome = false,
      this.showDistanceChips = false,
      this.showSupplier = true,
      this.adaptiveColors = false,
      this.storefront = false,
      this.onTap,
      this.onImporterTap});
  final PartModel part;
  final ProfileModel profile;
  final bool compact;

  /// Proporción y botón de la grilla de escritorio. El móvil deja esto en falso.
  final bool webChrome;
  final bool showDistanceChips;
  final bool showSupplier;
  final bool adaptiveColors;
  final bool storefront;
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
    const supplierBlue = Color(0xFF004BDD);
    const navy = Color(0xFF0A1F44);
    final theme = B2BThemeExtension.of(context);
    return Material(
        color: webChrome ? theme.surfaceCard : AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
                color: webChrome ? theme.borderSubtle : AppColors.divider)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Builder(builder: (context) {
            final details = Padding(
                padding: storefront ? const EdgeInsets.fromLTRB(8, 6, 8, 0) : const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Tooltip(
                          message: part.nombre,
                          excludeFromSemantics: true,
                          child: Text(part.nombre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: storefront ? 15 : compact ? 13.5 : 14.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  color: adaptiveColors ? theme.textPrimary : AppColors.black))),
                      SizedBox(height: storefront ? 4 : 8),
                      CatalogCartPrice(
                          part: part, compact: true, catalogGrid: true,
                          usdColor: adaptiveColors && brightness == Brightness.dark
                              ? const Color(0xFF69DB92) : null,
                          bsColor: adaptiveColors ? theme.textSecondary : null),
                      const SizedBox(height: 8),
                      ProductStockSummary(part: part, minimumColor: adaptiveColors ? theme.textSecondary : null),
                      if (hasCustomFields) ...[
                        const SizedBox(height: 4),
                        ProductCustomFieldsAliadoChips(
                            customFields: part.customFields),
                      ],
                      if (showDistanceChips) ...[
                        const SizedBox(height: 4),
                        Text(_distanceChipLabel(part),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                height: 1.2,
                                color: AppColors.textSecondary)),
                      ],
                    ]));
            final footer = Padding(
                padding: storefront ? const EdgeInsets.fromLTRB(8, 0, 8, 8) : const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showSupplier) const SizedBox(height: 8),
                      if (showSupplier) Tooltip(
                          message: onImporterTap == null
                              ? supplier
                              : 'Ver catálogo de $supplier',
                          child: InkWell(
                              onTap: onImporterTap,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(children: [
                                    const LucideIcon(LucideGlyph.store,
                                        size: 14, color: supplierBlue),
                                    const SizedBox(width: 5),
                                    Flexible(
                                        child: Text(supplier,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: false,
                                            style: TextStyle(
                                                fontSize: 12,
                                                height: 1.2,
                                                fontWeight: FontWeight.w700,
                                                color: onImporterTap == null
                                                    ? navy
                                                    : supplierBlue))),
                                    if (hasRating) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.star_rounded,
                                          size: 15,
                                          color: Colors.amber.shade600),
                                      const SizedBox(width: 2),
                                      Text(
                                          part.ownerRatingAvg!
                                              .toStringAsFixed(1),
                                          softWrap: false,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.black)),
                                    ],
                                  ])))),
                      if (profile.isAliado) ...[
                        const SizedBox(height: 10),
                        if (webChrome)
                          AliadoCatalogWebAddButton(part: part, profile: profile)
                        else
                          CatalogCartButton(part: part, profile: profile, storefront: storefront),
                      ] else if (onTap != null) ...[
                        const SizedBox(height: 10),
                        FilledButton(
                            onPressed: onTap,
                            style: FilledButton.styleFrom(
                                minimumSize: Size(0, scaler.scale(42)),
                                backgroundColor: supplierBlue,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999)),
                                textStyle: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700)),
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
                      if (webChrome)
                        _webPhoto(
                          B2BThemeExtension.of(context),
                          shippingIncluded: shippingIncluded,
                        )
                      else
                      Padding(
                          padding: storefront ? const EdgeInsets.fromLTRB(4, 4, 4, 0) : const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: AspectRatio(
                              aspectRatio: storefront ? 1.15 : AliadoCatalogLayout.cardImageAspect,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: ColoredBox(
                                      color: storefront ? AppColors.card : AppColors.photoFrameFor(brightness),
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

  /// Cabecera web: la foto usa el mismo fondo que la tarjeta y un divisor sutil.
  Widget _webPhoto(B2BThemeExtension theme, {required bool shippingIncluded}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        border: Border(bottom: BorderSide(color: theme.borderSubtle)),
      ),
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Hero(
                tag: ProductDetailScreen.heroImageTag(part),
                child: _productPhoto(),
              ),
            ),
            if (part.isCatalogVerified || part.isCatalogFeatured)
              Positioned(
                top: 8,
                left: 8,
                right: 52,
                child: ImporterCatalogSealsRow(
                  verified: part.isCatalogVerified,
                  featured: part.isCatalogFeatured,
                  compact: true,
                  spacing: 4,
                ),
              ),
            if (profile.isAliado)
              Positioned(
                top: 2,
                right: 2,
                child: FavoriteHeartButton(productId: part.id),
              ),
            if (part.hasWarranty)
              Positioned(
                top: part.isCatalogVerified || part.isCatalogFeatured ? 32 : 8,
                left: 8,
                right: 52,
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: ProductWarrantySeal(compact: true),
                ),
              ),
            if (shippingIncluded || part.variantChoices.isNotEmpty)
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (part.variantChoices.isNotEmpty)
                      _VariantOptionsChip(count: part.variantChoices.length),
                    if (shippingIncluded) const _ShippingIncludedChip(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _productPhoto() {
    final url = part.coverImageUrl?.trim();
    if (url == null || url.isEmpty) {
      return webChrome
          ? const SizedBox.expand()
          : const _PhotoPlaceholder();
    }
    return Image.network(
      url,
      fit: webChrome || storefront ? BoxFit.contain : BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => webChrome
          ? const SizedBox.expand()
          : const _PhotoPlaceholder(failed: true),
      loadingBuilder: (_, image, progress) => progress == null
          ? image
          : webChrome
              ? const SizedBox.expand()
              : const _PhotoPlaceholder(loading: true),
    );
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
