import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:motolink_pro_app/features/logistics/envio_politica.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica_badge.dart';
import 'catalog_product_price_display.dart';
import 'part_model.dart';
import 'promo_campaign_model.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'product_catalog_pricing.dart';

const _promoMonthShort = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _promoDayMonth(DateTime d, {required bool withYear}) {
  final monthDay = '${d.day} ${_promoMonthShort[d.month - 1]}';
  return withYear ? '$monthDay ${d.year}' : monthDay;
}

/// Rango de la valla, en una frase corta.
String promoActivePeriodLabel(DateTime start, DateTime end) {
  final a = DateTime(start.year, start.month, start.day);
  final b = DateTime(end.year, end.month, end.day);
  if (a == b) return 'Solo el ${_promoDayMonth(a, withYear: false)}';
  if (a.year == b.year && a.month == b.month) {
    return 'Del ${a.day} al ${b.day} ${_promoMonthShort[a.month - 1]}';
  }
  if (a.year == b.year) {
    return 'Del ${_promoDayMonth(a, withYear: false)} al ${_promoDayMonth(b, withYear: false)}';
  }
  return 'Del ${_promoDayMonth(a, withYear: true)} al ${_promoDayMonth(b, withYear: true)}';
}

/// Cuánto le queda a la valla, contado desde [now].
String promoPeriodCountdownLabel(
  DateTime start,
  DateTime end, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  final daysLeft = endDay.difference(today).inDays;
  final endText = _promoDayMonth(endDay, withYear: endDay.year != today.year);

  if (startDay == endDay) {
    if (daysLeft <= 0) return 'Solo hoy';
    return 'Solo el $endText';
  }
  if (daysLeft <= 0) return 'Termina hoy';
  if (daysLeft == 1) return 'Termina mañana';
  if (daysLeft <= 14) return 'Quedan $daysLeft días';
  return 'Hasta el $endText';
}

/// Frase corta sobre la foto de la valla.
String promoPeriodOnPhotoLabel(
  DateTime start,
  DateTime end, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final today = DateTime(clock.year, clock.month, clock.day);
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  final daysLeft = endDay.difference(today).inDays;
  final endText = _promoDayMonth(endDay, withYear: endDay.year != today.year);
  if (startDay == endDay && daysLeft <= 0) return 'Solo hoy';
  if (daysLeft <= 0) return 'Termina hoy';
  if (daysLeft == 1) return 'Termina mañana';
  return 'Hasta el $endText';
}

/// Aclara que el precio o la valla dependen de esas fechas.
String promoPeriodFootnote(PromoCampaignModel campaign) {
  if (campaign.hasProductDiscount) {
    return 'El descuento aplica solo mientras esta valla esté vigente.';
  }
  return 'Esta valla se muestra solo en estas fechas.';
}

/// Pastilla de vigencia para banners, pop-ups y la lista de promociones.
class PromoActivePeriodChip extends StatelessWidget {
  const PromoActivePeriodChip({
    super.key,
    required this.startsAt,
    required this.endsAt,
    this.onPhoto = false,
  });

  final DateTime startsAt;
  final DateTime endsAt;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final fg = onPhoto ? Colors.white : AppColors.brand;
    final headline = onPhoto
        ? promoPeriodOnPhotoLabel(startsAt, endsAt)
        : promoPeriodCountdownLabel(startsAt, endsAt);
    final range = promoActivePeriodLabel(startsAt, endsAt);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: onPhoto
            ? Colors.black.withOpacity(0.62)
            : AppColors.brandBlueContainer,
        borderRadius: BorderRadius.circular(12),
        border: onPhoto
            ? null
            : Border.all(color: AppColors.brand.withOpacity(0.16)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: onPhoto ? 8 : 10,
          vertical: onPhoto ? 4 : 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.calendar_month_outlined, size: 14, color: fg),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: onPhoto ? 11 : 12,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!onPhoto && headline != range) ...[
                  const SizedBox(height: 1),
                  Text(
                    range,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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

/// Creativo de valla. Alto fijo en el padre: en móvil la imagen sin medida
/// colapsa a 0 mientras carga y el pop-up queda en blanco.
class PromoCreativeImage extends StatelessWidget {
  const PromoCreativeImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
  });

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final logicalWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final cacheWidth = (logicalWidth * dpr).clamp(480.0, 1440.0).round();
        return Image.network(
          url,
          width: double.infinity,
          height: double.infinity,
          fit: fit,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            );
          },
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 40),
          ),
        );
      },
    );
  }
}

/// Carrusel de vallas publicadas (banner y pop-up) en el catálogo.
class AliadoPromoBannerCarousel extends StatefulWidget {
  const AliadoPromoBannerCarousel({
    super.key,
    required this.campaigns,
    this.onPromoCampaignSelected,
    this.compact = false,
    this.padding,
  });

  final List<PromoCampaignModel> campaigns;
  final ValueChanged<PromoCampaignModel>? onPromoCampaignSelected;
  final bool compact;
  final EdgeInsetsGeometry? padding;

  @override
  State<AliadoPromoBannerCarousel> createState() =>
      _AliadoPromoBannerCarouselState();
}

class _AliadoPromoBannerCarouselState extends State<AliadoPromoBannerCarousel> {
  late final PageController _pageController;
  Timer? _autoplay;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _autoplay = Timer.periodic(const Duration(seconds: 4), (_) => _advance());
  }

  @override
  void didUpdateWidget(covariant AliadoPromoBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.campaigns.length == oldWidget.campaigns.length) return;
    if (_page < widget.campaigns.length) return;
    _page = 0;
    if (_pageController.hasClients) _pageController.jumpToPage(0);
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _advance() {
    if (!mounted || widget.campaigns.length <= 1) return;
    if (!_pageController.hasClients) return;
    final next = (_page + 1) % widget.campaigns.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
    );
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

    // En web el carrusel es más alto para que el creativo se lea.
    final horizontalPadding = widget.compact ? 0.0 : 16.0;
    final maxBannerHeight = widget.compact ? 240.0 : 168.0;
    final minBannerHeight = widget.compact ? 150.0 : 112.0;

    return Padding(
      padding: widget.padding ??
          EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Preferencia panorámica (~3.5:1), limitada para no comerse el catálogo.
          final idealHeight = width / (widget.compact ? 3.2 : 3.5);
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
                  allowImplicitScrolling: true,
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
                            ColoredBox(color: AppColors.fieldFill),
                            PromoCreativeImage(url: c.imagePublicUrl),
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
                            Positioned(
                              left: 8,
                              bottom: 8,
                              right: c.isTappable ? 128 : 8,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: PromoActivePeriodChip(
                                  startsAt: c.startsAt,
                                  endsAt: c.endsAt,
                                  onPhoto: true,
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
                        color:
                            i == _page ? AppColors.brand : Colors.grey.shade400,
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: (MediaQuery.sizeOf(ctx).height * 0.42)
                      .clamp(180.0, 320.0),
                  width: double.infinity,
                  child: ColoredBox(
                    color: AppColors.fieldFill,
                    child: PromoCreativeImage(url: campaign.imagePublicUrl),
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
                    const SizedBox(height: 8),
                    PromoActivePeriodChip(
                      startsAt: campaign.startsAt,
                      endsAt: campaign.endsAt,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      promoPeriodFootnote(campaign),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: AppColors.textSecondary,
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
                style:
                    TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
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
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: ColoredBox(
                                  color: AppColors.fieldFill,
                                  child: PromoCreativeImage(
                                    url: c.imagePublicUrl,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                                    const SizedBox(height: 6),
                                    PromoActivePeriodChip(
                                      startsAt: c.startsAt,
                                      endsAt: c.endsAt,
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
      final discountLabel = campaign.productDiscountPercents.isEmpty
          ? ProductCatalogPricing.campaignDiscountChipEs(
              campaign.discountPercent,
            )
          : null;

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
                        const SizedBox(height: 6),
                        PromoActivePeriodChip(
                          startsAt: campaign.startsAt,
                          endsAt: campaign.endsAt,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          promoPeriodFootnote(campaign),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: AppColors.textSecondary,
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
                      quantity: part.minOrderQtyEffective,
                      ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
                      discountRules: part.discountRules,
                      campaignDiscountPercent:
                          part.activeCampaignDiscountPercent,
                      catalogGrid: true,
                      compact: true,
                      showPromotionChips: true,
                    ),
                    if (EnvioPolitica.muestraBadge(part.ownerEnvioTipo)) ...[
                      const SizedBox(height: 6),
                      EnvioPoliticaBadge(
                        tipo: part.ownerEnvioTipo,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
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
