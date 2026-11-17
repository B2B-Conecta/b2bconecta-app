import 'package:flutter/material.dart';

import 'promo_campaign_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'aliado_promo_campaign_widgets.dart';

String _formatPromoRange(DateTime start, DateTime end) {
  return promoActivePeriodLabel(start, end);
}

/// Badge en pedido importador: solicitado bajo campaña promocional.
class ImporterPedidoPromoChip extends StatelessWidget {
  const ImporterPedidoPromoChip({
    super.key,
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  factory ImporterPedidoPromoChip.fromRequest(
    TransactionRequestModel request, {
    bool compact = false,
  }) {
    return ImporterPedidoPromoChip(
      label: request.promoCampaignEtiqueta,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.brand.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.brand.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: compact ? 14 : 15,
            color: AppColors.brand,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'Pedido bajo promoción · $label',
              style: TextStyle(
                fontSize: compact ? 10.5 : 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carrusel de vallas publicitarias de terceros (importador / ambos).
class ImporterThirdPartyAdsCarousel extends StatefulWidget {
  const ImporterThirdPartyAdsCarousel({super.key, this.padding});

  /// Si es null, el carrusel usa su margen habitual.
  final EdgeInsetsGeometry? padding;

  @override
  State<ImporterThirdPartyAdsCarousel> createState() =>
      _ImporterThirdPartyAdsCarouselState();
}

class _ImporterThirdPartyAdsCarouselState
    extends State<ImporterThirdPartyAdsCarousel> {
  late Future<List<PromoCampaignModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.fetchActivePromoCampaignsForImportadorAds();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PromoCampaignModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final ads = snapshot.data ?? const <PromoCampaignModel>[];
        if (ads.isEmpty) return const SizedBox.shrink();
        return AliadoPromoBannerCarousel(
          campaigns: ads,
          padding: widget.padding,
        );
      },
    );
  }
}

/// Banner importador: campañas activas en catálogo aliado.
class ImporterActivePromoBanner extends StatefulWidget {
  const ImporterActivePromoBanner({super.key, this.padding});

  /// Si es null, el aviso usa su margen habitual.
  final EdgeInsetsGeometry? padding;

  @override
  State<ImporterActivePromoBanner> createState() =>
      _ImporterActivePromoBannerState();
}

class _ImporterActivePromoBannerState extends State<ImporterActivePromoBanner> {
  late Future<List<PromoCampaignModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.fetchActivePromoCampaignsForImportador();
  }

  Future<void> _reload() async {
    setState(() {
      _future = SupabaseService.fetchActivePromoCampaignsForImportador();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PromoCampaignModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final campaigns = snapshot.data ?? const <PromoCampaignModel>[];
        final theme = B2BThemeExtension.of(context);
        final countLabel = campaigns.isEmpty
            ? 'Sin promociones activas'
            : campaigns.length == 1
                ? '1 promoción activa'
                : '${campaigns.length} promociones activas';
        final detail = campaigns.isEmpty
            ? 'Cuando publique una campaña, las tiendas la verán en el catálogo.'
            : '«${campaigns.first.promoLabel}»';

        return Padding(
          padding: widget.padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Material(
            color: theme.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.brand.withOpacity(0.45)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showDetailSheet(context, campaigns),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LucideIcon(
                      LucideGlyph.megaphone,
                      color: theme.brand,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Promociones activas',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: theme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            countLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.brand,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: theme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            campaigns.isEmpty
                                ? 'Ver promociones'
                                : 'Editar o revisar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                    LucideIcon(
                      LucideGlyph.chevronRight,
                      size: 18,
                      color: theme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDetailSheet(
    BuildContext context,
    List<PromoCampaignModel> campaigns,
  ) async {
    final theme = B2BThemeExtension.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
    Widget buildBody(BuildContext ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Sus promociones activas',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  campaigns.isEmpty
                      ? 'No hay campañas vigentes. Puede publicarlas desde el panel de promociones.'
                      : 'Mientras estén vigentes, los pedidos que una tienda minorista solicite '
                          'tras usar «Ver proveedor» en su campaña se marcarán como '
                          '«Pedido bajo promoción».',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ...campaigns.map((c) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            c.imagePublicUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: theme.inputFill,
                              child: LucideIcon(
                                LucideGlyph.image,
                                size: 18,
                                color: theme.textMuted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.promoLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: theme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c.isPopup ? 'Pop-up' : 'Banner'} · '
                                '${_formatPromoRange(c.startsAt, c.endsAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _reload();
                    },
                    child: const Text('Actualizar'),
                  ),
                ),
              ],
            ),
          ),
        );
    }

    if (wide) {
      await showDialog<void>(
        context: context,
        barrierColor: theme.textPrimary.withOpacity(0.45),
        builder: (ctx) => Dialog(
          backgroundColor: theme.dialogSurface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
            ),
            child: SingleChildScrollView(child: buildBody(ctx)),
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.dialogSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: buildBody,
    );
  }
}

/// Promo en pedido agrupado: alguna línea bajo campaña.
ImporterPedidoPromoChip? importerPromoChipForLines(
  List<TransactionRequestModel> lines,
) {
  for (final r in lines) {
    if (r.bajoPromocionCatalogo) {
      return ImporterPedidoPromoChip.fromRequest(r, compact: true);
    }
  }
  return null;
}
