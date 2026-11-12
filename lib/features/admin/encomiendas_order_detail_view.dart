import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/commissions/order_commission_summary.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_transit_eta_banner.dart';
import 'package:motolink_pro_app/features/orders/shared/courier_timeline_widget.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/reputation/order_rating_eligibility.dart';

/// Detalle limpio de pedido desde Reportes › Encomiendas (sin acordeones saturados).
class OrderDetailView extends StatefulWidget {
  const OrderDetailView({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  State<OrderDetailView> createState() => _OrderDetailViewState();
}

class _DetailLoad {
  const _DetailLoad({required this.primary, required this.lines});
  final TransactionRequestModel primary;
  final List<TransactionRequestModel> lines;
}

class _OrderDetailViewState extends State<OrderDetailView> {
  late Future<_DetailLoad?> _future;
  bool? _importerRated;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailLoad?> _load() async {
    final lines =
        await SupabaseService.fetchCheckoutGroupLinesForTransactionRequest(
      widget.requestId,
    );
    if (lines.isEmpty) return null;
    TransactionRequestModel primary;
    try {
      primary = lines.firstWhere((e) => e.id == widget.requestId);
    } catch (_) {
      primary = lines.first;
    }
    _loadImporterRated(primary);
    return _DetailLoad(primary: primary, lines: lines);
  }

  Future<void> _loadImporterRated(TransactionRequestModel r) async {
    final aliadoId = r.aliadoId.trim();
    final importadorId = r.ownerId.trim();
    if (aliadoId.isEmpty || importadorId.isEmpty) return;
    try {
      final exists = await SupabaseService.orderRatingExistsForRater(
        raterRole: 'importador',
        importadorId: importadorId,
        aliadoId: aliadoId,
        checkoutGroupId: r.checkoutGroupId,
        transactionRequestId: r.id,
      );
      if (mounted) setState(() => _importerRated = exists);
    } catch (_) {
      if (mounted) setState(() => _importerRated = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.surfaceCard,
        foregroundColor: theme.textPrimary,
        elevation: 0,
        title: Text(
          'Detalle del pedido',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
        ),
      ),
      body: FutureBuilder<_DetailLoad?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: theme.brand),
            );
          }
          if (snapshot.hasError) {
            return _centerMsg(
              theme,
              'No se pudo cargar el pedido.\n${snapshot.error}',
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return _centerMsg(
              theme,
              'No encontramos este pedido o no tienes permisos para verlo.',
            );
          }
          return _OrderDetailBody(
            theme: theme,
            primary: data.primary,
            lines: data.lines,
            importerRated: _importerRated,
            onCopyId: () async {
              await Clipboard.setData(ClipboardData(text: data.primary.id));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ID copiado.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _centerMsg(B2BThemeExtension theme, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.textSecondary, height: 1.4),
        ),
      ),
    );
  }
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({
    required this.theme,
    required this.primary,
    required this.lines,
    required this.importerRated,
    required this.onCopyId,
  });

  final B2BThemeExtension theme;
  final TransactionRequestModel primary;
  final List<TransactionRequestModel> lines;
  final bool? importerRated;
  final VoidCallback onCopyId;

  double get _totalRef =>
      lines.fold<double>(0, (s, r) => s + r.precioTotal);

  double? get _totalBs {
    var any = false;
    var sum = 0.0;
    for (final r in lines) {
      final bs = r.precioTotalBsUi;
      if (bs != null) {
        any = true;
        sum += bs;
      }
    }
    return any ? sum : null;
  }

  double? get _bcvRate {
    for (final r in lines) {
      final rate = r.tasaBcvAplicada ?? r.tasaBcvSnapshot;
      if (rate != null && rate > 0) return rate;
    }
    return null;
  }

  String get _statusLabel {
    if (lines.every((l) => l.pedidoEntregadoYPagado)) {
      return 'Entregado y pagado';
    }
    if (lines.any((l) => l.pedidoEntregadoYPagado)) {
      return 'Parcialmente pagado';
    }
    return TransactionRequestStatus.labelEs(primary.status);
  }

  bool get _statusSuccess =>
      lines.every((l) => l.pedidoEntregadoYPagado);

  TransactionRequestModel? get _ratedLine {
    for (final x in lines) {
      if (x.aliadoExperienceSubmittedAt != null) return x;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final eligible = orderLinesEligibleForCommission(lines);
    final commissionUsd = chunkCommissionUsd(eligible);
    final commissionDevengada =
        eligible.isNotEmpty && eligible.every((r) => r.comisionDevengada);
    final aliado = (primary.aliadoBusinessName ?? '').trim().isEmpty
        ? 'Tienda minorista'
        : primary.aliadoBusinessName!.trim();
    final importer = (primary.ownerBusinessName ?? '').trim().isEmpty
        ? 'Mayorista'
        : primary.ownerBusinessName!.trim();
    final shortId = primary.id.length > 8
        ? primary.id.substring(0, 8).toUpperCase()
        : primary.id.toUpperCase();
    final rated = _ratedLine;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _SummaryCard(
          theme: theme,
          statusLabel: _statusLabel,
          success: _statusSuccess,
          shortId: shortId,
          fullId: primary.id,
          createdAt: primary.createdAt,
          totalRef: _totalRef,
          totalBs: _totalBs,
          bcvRate: _bcvRate,
          onCopyId: onCopyId,
        ),
        const SizedBox(height: 12),
        _PartiesCard(theme: theme, aliado: aliado, importer: importer),
        const SizedBox(height: 12),
        Text(
          lines.length == 1 ? 'Producto' : 'Productos (${lines.length})',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: theme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (final line in lines) ...[
          _ProductLineCard(theme: theme, line: line),
          const SizedBox(height: 8),
        ],
        if (eligible.isNotEmpty || rated != null) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (eligible.isNotEmpty)
                _MetaPill(
                  theme: theme,
                  icon: LucideGlyph.badgeDollarSign,
                  label: commissionDevengada
                      ? 'USD ${commissionUsd.toStringAsFixed(2)} · devengada'
                      : 'USD ${commissionUsd.toStringAsFixed(2)} · estimada',
                  accent: commissionDevengada,
                ),
              if (rated?.aliadoExperienceStars != null)
                _MetaPill(
                  theme: theme,
                  icon: LucideGlyph.star,
                  label:
                      'Minorista ★ ${rated!.aliadoExperienceStars}/5',
                ),
              if (importerRated == true)
                _MetaPill(
                  theme: theme,
                  icon: LucideGlyph.star,
                  label: 'Mayorista · valoró',
                )
              else if (importerRated == false &&
                  lineaElegibleValoracionImportador(primary))
                _MetaPill(
                  theme: theme,
                  icon: LucideGlyph.star,
                  label: 'Mayorista · pendiente',
                  muted: true,
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        _MoreDetailsAccordion(
          theme: theme,
          primary: primary,
          lines: lines,
          rated: rated,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.theme,
    required this.statusLabel,
    required this.success,
    required this.shortId,
    required this.fullId,
    required this.createdAt,
    required this.totalRef,
    required this.totalBs,
    required this.bcvRate,
    required this.onCopyId,
  });

  final B2BThemeExtension theme;
  final String statusLabel;
  final bool success;
  final String shortId;
  final String fullId;
  final DateTime? createdAt;
  final double totalRef;
  final double? totalBs;
  final double? bcvRate;
  final VoidCallback onCopyId;

  @override
  Widget build(BuildContext context) {
    final badgeBg = success ? theme.successBg : theme.brandContainer;
    final badgeFg = success ? theme.successFg : theme.brand;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onCopyId,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ref $shortId',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: theme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      LucideIcon(
                        LucideGlyph.copy,
                        size: 14,
                        color: theme.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            createdAt == null
                ? 'Fecha no disponible'
                : formatEsShortDateTime(createdAt),
            style: TextStyle(fontSize: 12.5, color: theme.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            '${totalRef.toStringAsFixed(2)} REF / USD',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
          if (totalBs != null) ...[
            const SizedBox(height: 4),
            Text(
              bcvRate == null
                  ? formatVesAmount(totalBs!)
                  : '${formatVesAmount(totalBs!)} · BCV ${bcvRate!.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          SelectableText(
            fullId,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: theme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartiesCard extends StatelessWidget {
  const _PartiesCard({
    required this.theme,
    required this.aliado,
    required this.importer,
  });

  final B2BThemeExtension theme;
  final String aliado;
  final String importer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        children: [
          LucideIcon(LucideGlyph.store, size: 18, color: theme.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              aliado,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: LucideIcon(
              LucideGlyph.arrowRight,
              size: 16,
              color: theme.textMuted,
            ),
          ),
          LucideIcon(LucideGlyph.package, size: 18, color: theme.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              importer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductLineCard extends StatelessWidget {
  const _ProductLineCard({required this.theme, required this.line});

  final B2BThemeExtension theme;
  final TransactionRequestModel line;

  @override
  Widget build(BuildContext context) {
    final name = (line.productName ?? '').trim().isEmpty
        ? 'Producto'
        : line.productName!.trim();
    final sku = (line.productSku ?? '').trim();
    final bs = line.precioTotalBsUi;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.brandContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: LucideIcon(
              LucideGlyph.package,
              size: 20,
              color: theme.brand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
                if (sku.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sku,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${line.cantidad} uds · ${line.precioTotal.toStringAsFixed(2)} REF / USD'
                  '${bs == null ? '' : ' · ${formatVesAmount(bs)}'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.theme,
    required this.icon,
    required this.label,
    this.accent = false,
    this.muted = false,
  });

  final B2BThemeExtension theme;
  final LucideGlyph icon;
  final String label;
  final bool accent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final bg = accent
        ? theme.successBg
        : muted
            ? theme.surfaceSubtle
            : theme.brandContainer;
    final fg = accent
        ? theme.successFg
        : muted
            ? theme.textMuted
            : theme.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LucideIcon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreDetailsAccordion extends StatelessWidget {
  const _MoreDetailsAccordion({
    required this.theme,
    required this.primary,
    required this.lines,
    required this.rated,
  });

  final B2BThemeExtension theme;
  final TransactionRequestModel primary;
  final List<TransactionRequestModel> lines;
  final TransactionRequestModel? rated;

  @override
  Widget build(BuildContext context) {
    final note = primary.notasAdmin?.trim();
    final comment = rated?.aliadoExperienceComment?.trim();

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: theme.surfaceCard),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: theme.textSecondary,
          collapsedIconColor: theme.textSecondary,
          title: Text(
            'Más detalles',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: theme.textPrimary,
            ),
          ),
          subtitle: Text(
            'Seguimiento, entrega, referencias y notas',
            style: TextStyle(fontSize: 12, color: theme.textSecondary),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Entrega',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              primary.destinoEntregaLineaCompactaEs,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Seguimiento',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (AliadoTransitEtaBanner.shouldShow(primary)) ...[
              AliadoTransitEtaBanner(request: primary),
              const SizedBox(height: 8),
            ],
            CourierTimelineWidget(
              request: primary,
              compact: true,
              viewerRole: AppHomeRole.administrador,
              showHeading: false,
            ),
            if (comment != null && comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Reseña de la tienda minorista',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '“$comment”',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  fontStyle: FontStyle.italic,
                  color: theme.textSecondary,
                ),
              ),
            ],
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Nota de B2B Conecta',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                note,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: theme.textSecondary,
                ),
              ),
            ],
            if (lines.length > 1) ...[
              const SizedBox(height: 12),
              Text(
                '${lines.length} líneas en este pedido',
                style: TextStyle(fontSize: 12, color: theme.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
