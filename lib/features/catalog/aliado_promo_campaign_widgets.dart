import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'catalog_product_price_display.dart';
import 'part_model.dart';
import 'promo_campaign_model.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'product_catalog_pricing.dart';

Future<void> launchPromoCampaignExternalUrl(
  BuildContext context,
  PromoCampaignModel campaign,
) async {
  final raw = campaign.externalUrl?.trim();
  if (raw == null || raw.isEmpty) return;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace del anuncio no válido.')),
    );
    return;
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el enlace.')),
    );
  }
}

/// Carrusel de banners promocionales (E1.2) en catálogo aliado.
class AliadoPromoBannerCarousel extends StatefulWidget {
  const AliadoPromoBannerCarousel({
    super.key,
    required this.campaigns,
    this.onPromoCampaignSelected,
    this.compact = false,
  });

  final List<PromoCampaignModel> campaigns;
  final ValueChanged<PromoCampaignModel>? onPromoCampaignSelected;
  final bool compact;

  @override
  State<AliadoPromoBannerCarousel> createState() =>
      _AliadoPromoBannerCarouselState();
}

class _AliadoPromoBannerCarouselState extends State<AliadoPromoBannerCarousel> {
  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onTap(PromoCampaignModel c) async {
    if (c.filtersImporter || c.opensStore || c.opensProduct) {
      widget.onPromoCampaignSelected?.call(c);
      return;
    }
    if (c.opensExternalUrl) {
      await launchPromoCampaignExternalUrl(context, c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.campaigns;
    if (items.isEmpty) return const SizedBox.shrink();

    // Tope bajo en desktop: creativo completo (contain) sin comerse el catálogo.
    final horizontalPadding = widget.compact ? 0.0 : 16.0;
    final maxBannerHeight = widget.compact ? 96.0 : 128.0;
    final minBannerHeight = widget.compact ? 72.0 : 100.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Preferencia panorámica (~3.5:1), limitada para no comerse el catálogo.
          final idealHeight = width / 3.5;
          final bannerHeight =
              idealHeight.clamp(minBannerHeight, maxBannerHeight).toDouble();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: bannerHeight,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: items.length,
                  // Evita que el PageView “robe” el scroll vertical del catálogo.
                  physics: items.length <= 1
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, index) {
                    final c = items[index];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: c.isTappable ? () => _onTap(c) : null,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              c.imagePublicUrl,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.fieldFill,
                                alignment: Alignment.center,
                                child:
                                    const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                            Positioned(
                              left: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  c.badgeLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            if (c.isTappable)
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    c.promoLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (items.length > 1) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    items.length,
                    (i) => Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page
                            ? AppColors.brand
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Diálogo promocional reutilizable (automático o bajo demanda del aliado).
Future<void> showAliadoPromoPopupDialog({
  required BuildContext context,
  required PromoCampaignModel campaign,
  VoidCallback? onDismissed,
  VoidCallback? onFilterImporter,
}) async {
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.48,
                ),
                child: ColoredBox(
                  color: AppColors.fieldFill,
                  child: Image.network(
                    campaign.imagePublicUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => Container(
                      height: 180,
                      color: AppColors.fieldFill,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          campaign.badgeLabel,
                          style: TextStyle(
                            color: campaign.isThirdParty
                                ? AppColors.brandBlue
                                : AppColors.brand,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        campaign.isPopup ? 'Pop-up' : 'Banner',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    campaign.promoLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ),
                  if (campaign.filtersImporter ||
                      campaign.opensStore ||
                      campaign.opensProduct) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onFilterImporter?.call();
                        },
                        child: Text(campaign.destinationCtaLabel),
                      ),
                    ),
                  ] else if (campaign.opensExternalUrl) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await launchPromoCampaignExternalUrl(
                            context,
                            campaign,
                          );
                        },
                        child: const Text('Más información'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  onDismissed?.call();
}

/// Muestra pop-up promocional (máx. 1 cada 24 h por campaña).
Future<void> showAliadoPromoPopupIfDue({
  required BuildContext context,
  required PromoCampaignModel campaign,
  required VoidCallback onDismissed,
  VoidCallback? onFilterImporter,
}) {
  return showAliadoPromoPopupDialog(
    context: context,
    campaign: campaign,
    onDismissed: onDismissed,
    onFilterImporter: onFilterImporter,
  );
}

/// Listado bajo demanda: el aliado puede reabrir promociones cerradas.
Future<void> showAliadoActivePromotionsSheet({
  required BuildContext context,
  required List<PromoCampaignModel> campaigns,
  ValueChanged<PromoCampaignModel>? onPromoCampaignSelected,
}) async {
  if (campaigns.isEmpty) return;

  final sorted = List<PromoCampaignModel>.from(campaigns)
    ..sort((a, b) => b.priority.compareTo(a.priority));

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      final maxListHeight = MediaQuery.of(ctx).size.height * 0.5;
      return Padding(
        padding: EdgeInsets.fromLTRB(0, 12, 0, bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Promociones activas',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Puede volver a ver las campañas publicitarias cuando quiera.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxListHeight),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = sorted[i];
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (!context.mounted) return;
                        await showAliadoPromoPopupDialog(
                          context: context,
                          campaign: c,
                          onFilterImporter: c.filtersImporter ||
                                  c.opensStore ||
                                  c.opensProduct
                              ? () => onPromoCampaignSelected?.call(c)
                              : null,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(11),
                              ),
                              child: Image.network(
                                c.imagePublicUrl,
                                width: 72,
                                height: 72,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 72,
                                  height: 72,
                                  color: AppColors.fieldFill,
                                  child: const Icon(Icons.image_outlined),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.promoLabel,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.isPopup ? 'Pop-up' : 'Banner',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: Icon(
                                Icons.chevron_right,
                                color: AppColors.brand,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Sheet para elegir entre varios productos de una valla (imagen + precio promo).
Future<PartModel?> showAliadoPromoProductsSheet({
  required BuildContext context,
  required PromoCampaignModel campaign,
  required List<PartModel> parts,
}) {
  if (parts.isEmpty) return Future<PartModel?>.value(null);

  return showModalBottomSheet<PartModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.62;
      final discountLabel = ProductCatalogPricing.campaignDiscountChipEs(
        campaign.discountPercent,
      );

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Productos de la promoción',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          campaign.promoLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (discountLabel != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6E5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE8A317).withOpacity(0.45),
                      ),
                    ),
                    child: Text(
                      discountLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8A5A00),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: parts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final p = parts[i];
                    return _PromoProductPickTile(
                      part: p,
                      onTap: () => Navigator.pop(ctx, p),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PromoProductPickTile extends StatelessWidget {
  const _PromoProductPickTile({
    required this.part,
    required this.onTap,
  });

  final PartModel part;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sku = (part.sku ?? '').trim();
    final cover = part.coverImageUrl?.trim();

    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: cover != null && cover.isNotEmpty
                      ? Image.network(
                          cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                        )
                      : _thumbPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      part.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    if (sku.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'SKU $sku',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    CatalogProductPriceDisplay(
                      listPriceUsd: part.precio,
                      salePriceUsd: part.salePriceUsd,
                      discountRules: part.discountRules,
                      campaignDiscountPercent:
                          part.activeCampaignDiscountPercent,
                      catalogGrid: true,
                      compact: true,
                      showPromotionChips: true,
                      ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.brand,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return ColoredBox(
      color: AppColors.fieldFill,
      child: Icon(
        Icons.precision_manufacturing_outlined,
        color: AppColors.textSecondary.withOpacity(0.55),
        size: 28,
      ),
    );
  }
}
