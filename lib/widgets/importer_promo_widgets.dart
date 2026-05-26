import 'package:flutter/material.dart';

import '../models/promo_campaign_model.dart';
import '../models/transaction_request_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

String _formatPromoRange(DateTime start, DateTime end) {
  final a = formatEsShortDateTime(
    DateTime(start.year, start.month, start.day),
  ).split(' ').first;
  final b = formatEsShortDateTime(
    DateTime(end.year, end.month, end.day),
  ).split(' ').first;
  return '$a – $b';
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
        color: AppColors.brandOrange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.brandOrange.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: compact ? 14 : 15,
            color: AppColors.brandOrange,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'Pedido bajo promoción · $label',
              style: TextStyle(
                fontSize: compact ? 10.5 : 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.brandOrange,
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

/// Banner importador: campañas activas en catálogo aliado.
class ImporterActivePromoBanner extends StatefulWidget {
  const ImporterActivePromoBanner({super.key});

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
        if (campaigns.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Material(
            color: AppColors.brandOrange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showDetailSheet(context, campaigns),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      color: AppColors.brandOrange,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            campaigns.length == 1
                                ? 'Promoción activa en catálogo aliado'
                                : '${campaigns.length} promociones activas en catálogo aliado',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Los aliados pueden ver su campaña «${campaigns.first.promoLabel}». '
                            'Los pedidos solicitados desde la promoción aparecerán marcados.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade600,
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sus promociones activas',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mientras estén vigentes, los pedidos que un aliado solicite '
                  'tras usar «Ver proveedor» en su campaña se marcarán como '
                  '«Pedido bajo promoción».',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.grey.shade800,
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
                              color: AppColors.fieldFill,
                              child: const Icon(Icons.image_outlined),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c.isPopup ? 'Pop-up' : 'Banner'} · '
                                '${_formatPromoRange(c.startsAt, c.endsAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
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
      },
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
