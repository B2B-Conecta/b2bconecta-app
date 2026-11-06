import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:motolink_pro_app/features/logistics/envio_politica.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica_badge.dart';
import 'catalog_product_price_display.dart';
import 'part_model.dart';
import 'promo_campaign_model.dart';
import 'promo_banner_layout.dart';
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

/// Remove generic campaign labels only when separated from the actual title.
/// Paid third-party placements retain their advertising disclosure.
String promoBannerCaption(PromoCampaignModel campaign) {
  if (campaign.isThirdParty) {
    final advertiser = campaign.advertiserName?.trim() ?? '';
    return advertiser.isEmpty ? 'Publicidad' : 'Publicidad · $advertiser';
  }
  var title = campaign.promoLabel.trim();
  final prefix = RegExp(r'^(promoci[oó]n|publicidad|anuncio)\s*[-–—:·|]\s*',
      caseSensitive: false);
  final suffix = RegExp(r'\s*[-–—:·|]\s*(promoci[oó]n|publicidad|anuncio)$',
      caseSensitive: false);
  String previous;
  do {
    previous = title;
    title = title.replaceFirst(prefix, '').replaceFirst(suffix, '').trim();
  } while (title != previous);
  return title.isEmpty ? campaign.badgeLabel : title;
}

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
    this.fit = BoxFit.cover,
    this.mobileUrl,
    this.onLoadFailed,
  });

  final String url;
  final BoxFit fit;
  final String? mobileUrl;
  final ValueChanged<String>? onLoadFailed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final logicalWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final cacheWidth = (logicalWidth * dpr).clamp(480.0, 1440.0).round();
        final resolved =
            constraints.maxWidth < PromoBannerSpec.breakpoint &&
                    mobileUrl?.trim().isNotEmpty == true
                ? mobileUrl!
                : url;
        return Image.network(
          resolved,
          width: double.infinity,
          height: double.infinity,
          fit: fit,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _PromoBannerPlaceholder(progress: progress);
          },
          errorBuilder: (_, __, ___) {
            final notify = onLoadFailed;
            if (notify != null) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => notify(resolved));
            }
            return const Center(
              child: Icon(Icons.broken_image_outlined, size: 40),
            );
          },
        );
      },
    );
  }
}

class _PromoBannerPlaceholder extends StatelessWidget {
  const _PromoBannerPlaceholder({this.progress});

  final ImageChunkEvent? progress;

  @override
  Widget build(BuildContext context) {
    final total = progress?.expectedTotalBytes;
    final loaded = progress?.cumulativeBytesLoaded ?? 0;
    final value = total != null && total > 0 ? loaded / total : null;
    return ColoredBox(
      color: AppColors.brandBlueContainer.withOpacity(.55),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            value: value,
            color: AppColors.brand,
          ),
        ),
      ),
    );
  }
}

/// Carrusel de vallas publicadas (banner y pop-up) en el catálogo.
class AliadoPromoBannerCarousel extends StatefulWidget {
  const AliadoPromoBannerCarousel({
    super.key,
    required this.campaigns,
    this.onPromoCampaignSelected,
    this.onViewAll,
    this.compact = false,
    this.padding,
  });

  final List<PromoCampaignModel> campaigns;
  final ValueChanged<PromoCampaignModel>? onPromoCampaignSelected;
  final VoidCallback? onViewAll;
  final bool compact;
  final EdgeInsetsGeometry? padding;

  @override
  State<AliadoPromoBannerCarousel> createState() =>
      _AliadoPromoBannerCarouselState();
}

class _AliadoPromoBannerCarouselState extends State<AliadoPromoBannerCarousel> {
  late final PageController _pageController;
  Timer? _autoplay;
  bool _interacting = false;
  int _page = 0;
  final Set<String> _failedImages = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _autoplay = Timer.periodic(const Duration(seconds: 4), (_) => _advance());
  }

  @override
  void didUpdateWidget(covariant AliadoPromoBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.campaigns.length) {
      _page = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _advance() {
    if (!mounted || widget.campaigns.length <= 1) return;
    if (_interacting || MediaQuery.disableAnimationsOf(context)) return;
    if (!_pageController.hasClients) return;
    final next = (_page + 1) % widget.campaigns.length;
    _goToPage(next);
  }

  void _goToPage(int page, {bool animate = true}) {
    if (!_pageController.hasClients) return;
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(page);
    } else {
      _pageController.animateToPage(page,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic);
    }
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

    final current = items[_page];
    final horizontalPadding = widget.compact ? 0.0 : 16.0;
    return Padding(
      padding: widget.padding ??
          EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          String selectedImage(PromoCampaignModel campaign) {
            final preferred = campaign.imageUrlForWidth(constraints.maxWidth);
            return _failedImages.contains(preferred)
                ? campaign.imagePublicUrl
                : preferred;
          }

          final frame = promoBannerFrameSize(constraints.maxWidth);
          final hasViewAll = items.length > 1 && widget.onViewAll != null;
          final compactAccess = frame.width < PromoBannerSpec.breakpoint;
          final indicatorInset =
              hasViewAll ? (compactAccess ? 62.0 : 132.0) : 12.0;
          return Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: frame.width,
              child: AspectRatio(
                aspectRatio:
                    PromoBannerSpec.aspectForWidth(constraints.maxWidth),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: MouseRegion(
                    onEnter: (_) => _interacting = true,
                    onExit: (_) => _interacting = false,
                    child: Listener(
                      onPointerDown: (_) => _interacting = true,
                      onPointerUp: (_) => _interacting = false,
                      onPointerCancel: (_) => _interacting = false,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            itemCount: items.length,
                            allowImplicitScrolling: true,
                            physics: items.length <= 1
                                ? const NeverScrollableScrollPhysics()
                                : const PageScrollPhysics(),
                            onPageChanged: (i) => setState(() => _page = i),
                            itemBuilder: (context, index) {
                              final c = items[index];
                              return Semantics(
                                label: '${promoBannerCaption(c)}. '
                                    '${promoActivePeriodLabel(c.startsAt, c.endsAt)}',
                                button: c.isTappable,
                                child: InkWell(
                                  onTap: c.isTappable ? () => _onTap(c) : null,
                                  child: ExcludeSemantics(
                                    child: PromoCreativeImage(
                                      url: selectedImage(c),
                                      fit: BoxFit.cover,
                                      onLoadFailed: (failedUrl) {
                                        if (_failedImages.contains(failedUrl)) {
                                          return;
                                        }
                                        setState(
                                            () => _failedImages.add(failedUrl));
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        if (current.isThirdParty)
                          Positioned(
                            top: 8,
                            left: 10,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(.45),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  child: Text('Publicidad',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 10)),
                                ),
                              ),
                            ),
                          ),
                        if (items.length > 1)
                          Positioned(
                            bottom: 6,
                            left: indicatorInset,
                            right: indicatorInset,
                            child: Center(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: 12,
                                      bottom: 12,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(.22),
                                          borderRadius:
                                              BorderRadius.circular(24),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children:
                                          List.generate(items.length, (i) {
                                        final selected = i == _page;
                                        return Semantics(
                                          button: true,
                                          selected: selected,
                                          label:
                                              'Promoción ${i + 1} de ${items.length}',
                                          onTap: () =>
                                              _goToPage(i, animate: false),
                                          child: InkWell(
                                            excludeFromSemantics: true,
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            onTap: () => _goToPage(i,
                                                animate: FocusManager.instance
                                                        .highlightMode !=
                                                    FocusHighlightMode
                                                        .traditional),
                                            child: SizedBox(
                                              width: 44,
                                              height: 44,
                                              child: Center(
                                                child: AnimatedContainer(
                                                  duration: MediaQuery
                                                          .disableAnimationsOf(
                                                              context)
                                                      ? Duration.zero
                                                      : const Duration(
                                                          milliseconds: 180),
                                                  curve: Curves.easeOutCubic,
                                                  width: selected ? 24 : 7,
                                                  height: 7,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    color: Colors.white
                                                        .withOpacity(
                                                            selected ? 1 : .55),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (hasViewAll)
                          Positioned(
                            bottom: 6,
                            right: 8,
                            child: Tooltip(
                              message:
                                  'Ver todas las promociones (${items.length})',
                              child: Semantics(
                                label:
                                    'Ver todas las promociones (${items.length})',
                                button: true,
                                onTap: widget.onViewAll,
                                excludeSemantics: true,
                                child: TextButton(
                                  onPressed: widget.onViewAll,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor:
                                        Colors.black.withOpacity(.38),
                                    minimumSize: const Size(44, 44),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: compactAccess ? 10 : 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(22)),
                                  ),
                                  child: compactAccess
                                      ? const Icon(Icons.grid_view_rounded,
                                          size: 18)
                                      : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Ver todas',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            SizedBox(width: 6),
                                            Icon(Icons.north_east_rounded,
                                                size: 15),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
                child: AspectRatio(
                  aspectRatio: PromoBannerSpec.aspectForWidth(
                    MediaQuery.sizeOf(ctx).width,
                  ),
                  child: ColoredBox(
                    color: AppColors.fieldFill,
                    child: PromoCreativeImage(
                      url: campaign.imagePublicUrl,
                      mobileUrl: campaign.mobileImagePublicUrl,
                      fit: BoxFit.cover,
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
                                    mobileUrl: c.mobileImagePublicUrl,
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
