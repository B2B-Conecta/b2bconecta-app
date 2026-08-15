import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'promo_campaign_model.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

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
    if (c.filtersImporter) {
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

    final bannerHeight = widget.compact ? 96.0 : 132.0;
    final horizontalPadding = widget.compact ? 0.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: bannerHeight,
            child: PageView.builder(
              controller: _pageController,
              itemCount: items.length,
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
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.fieldFill,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
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
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  campaign.imagePublicUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.fieldFill,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, size: 40),
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
                  if (campaign.filtersImporter) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onFilterImporter?.call();
                        },
                        child: const Text('Ver proveedor'),
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
                          onFilterImporter: c.filtersImporter
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
                                fit: BoxFit.cover,
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
