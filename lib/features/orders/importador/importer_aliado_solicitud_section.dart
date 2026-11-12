import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/orders/shared/order_item_model.dart';
import 'package:motolink_pro_app/features/orders/shared/order_product_thumb.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/features/orders/shared/aliado_order_grouping.dart';
import 'package:motolink_pro_app/features/orders/shared/b2b_orders_panel_layout.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';

/// Vista importador vs aliado: de dónde salen las partidas (`order_items` / fila).
enum PedidoDesgloseViewer {
  importador,
  aliado,
}

/// Partidas para desglose según rol de pantalla.
List<PedidoProductoLineUi> transactionRequestLineasDesgloseForViewer(
  TransactionRequestModel r,
  PedidoDesgloseViewer viewer,
) {
  if (viewer == PedidoDesgloseViewer.aliado) {
    return r.lineasProductoDesglose(forImportadorUserId: r.ownerId);
  }
  return r.lineasProductoDesglose(
    forImportadorUserId: SupabaseService.currentUserId,
  );
}

/// Fila de partida con miniatura, cantidad y total (detalle o lista compacta).
Widget pedidoProductoLineCard(
  BuildContext context,
  PedidoProductoLineUi p,
  bool compact, {
  String currencyLabel = 'REF',
}) {
  final theme = B2BThemeExtension.of(context);
  final density = B2bOrderCardDensityScope.of(context);
  final webCompact = density.isDesktop && compact;
  final sku = p.sku?.trim();
  // Detalle ampliado: miniatura y tipografía legibles en panel admin.
  final thumb = compact ? (webCompact ? 40.0 : 44.0) : 72.0;
  final nameSize = compact ? (webCompact ? 12.0 : 13.0) : 15.5;
  final metaSize = compact ? (webCompact ? 10.5 : 11.5) : 13.0;
  final amountSize = compact ? (webCompact ? 12.0 : 13.0) : 16.5;
  final qtyLabel =
      '${p.cantidad} ${p.cantidad == 1 ? 'unidad' : 'unidades'}';
  final amountLabel = '${formatRefAmount(p.precioRef)} $currencyLabel';

  final info = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        p.nombre,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: nameSize,
          color: theme.textPrimary,
          height: 1.3,
        ),
        maxLines: compact ? 2 : 3,
        overflow: TextOverflow.ellipsis,
      ),
      if (sku != null && sku.isNotEmpty) ...[
        SizedBox(height: compact ? 2 : 5),
        Text(
          'SKU: $sku',
          style: TextStyle(
            fontSize: metaSize,
            fontWeight: FontWeight.w600,
            color: theme.textSecondary,
            height: 1.25,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
      SizedBox(height: compact ? 3 : 6),
      Text(
        qtyLabel,
        style: TextStyle(
          fontSize: metaSize,
          fontWeight: FontWeight.w600,
          color: theme.textSecondary,
          height: 1.25,
        ),
      ),
    ],
  );

  final amount = Text(
    amountLabel,
    textAlign: TextAlign.end,
    style: TextStyle(
      fontSize: amountSize,
      fontWeight: FontWeight.w800,
      color: theme.textPrimary,
      height: 1.2,
    ),
  );

  final row = LayoutBuilder(
    builder: (context, constraints) {
      final stackAmount = compact
          ? true
          : constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(14) > 20;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          OrderProductThumb(size: thumb, url: p.imageUrl),
          SizedBox(width: compact ? 10 : 14),
          Expanded(
            child: stackAmount
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      info,
                      SizedBox(height: compact ? 6 : 8),
                      amount,
                    ],
                  )
                : info,
          ),
          if (!stackAmount) ...[
            const SizedBox(width: 16),
            amount,
          ],
        ],
      );
    },
  );

  return Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(
      horizontal: compact ? (webCompact ? 8 : 10) : 14,
      vertical: compact ? (webCompact ? 8 : 10) : 14,
    ),
    decoration: BoxDecoration(
      color: compact ? theme.surfaceSubtle : theme.inputFill,
      borderRadius: BorderRadius.circular(compact ? (webCompact ? 8 : 10) : 12),
      border: Border.all(color: theme.borderSubtle),
    ),
    child: row,
  );
}

/// Desglose de productos para una o varias filas de pedido (detalle expandido, ficha admin, etc.).
class TransactionRequestProductosDesgloseSection extends StatelessWidget {
  const TransactionRequestProductosDesgloseSection({
    super.key,
    required this.lines,
    this.compact = true,
    this.viewer = PedidoDesgloseViewer.importador,
    this.showPrecioHelp = true,
    this.sectionTitle,
    this.showImporterGroupHeaders = true,
    this.hideSectionTitle = false,
  });

  final List<TransactionRequestModel> lines;
  final bool compact;
  final PedidoDesgloseViewer viewer;
  final bool showPrecioHelp;

  /// Si se define, sustituye el título por defecto.
  final String? sectionTitle;

  /// En carritos multi-importador, agrupa por nombre de proveedor.
  final bool showImporterGroupHeaders;

  /// Dentro de [OrderCardCollapsibleSection]: el título va en el encabezado colapsable.
  final bool hideSectionTitle;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();

    final density = B2bOrderCardDensityScope.of(context);
    final web = density.isDesktop && compact;
    final titleSize = web ? 11.5 : (compact ? 12.5 : 13.5);
    final helpSize = web ? 9.5 : (compact ? 10.0 : 10.5);
    var chunks = groupCheckoutLinesByImportador(lines);
    if (chunks.isEmpty) {
      chunks = <List<TransactionRequestModel>>[lines];
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hideSectionTitle) ...[
          Text(
            sectionTitle ??
                (viewer == PedidoDesgloseViewer.aliado
                    ? 'Productos de tu pedido'
                    : 'Productos del pedido'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: titleSize,
              color: AppColors.textPrimary,
            ),
          ),
          if (showPrecioHelp && viewer == PedidoDesgloseViewer.importador) ...[
            const SizedBox(height: 4),
            Text(
              orderAmountCurrency(lines) == 'USD'
                  ? 'Precios acordados para pago en divisas (USD).'
                  : 'Precios en REF para pago en bolívares a la tasa BCV del pedido.',
              style: TextStyle(
                fontSize: helpSize,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
          SizedBox(height: compact ? 8 : 10),
        ],
        for (var ci = 0; ci < chunks.length; ci++) ...[
          if (ci > 0) SizedBox(height: compact ? 14 : 16),
          if (showImporterGroupHeaders && chunks.length > 1) ...[
            Text(
              () {
                final t = chunks[ci].first.ownerBusinessName?.trim();
                return (t != null && t.isNotEmpty) ? t : 'Proveedor';
              }(),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: web ? 10.5 : (compact ? 11.5 : 12),
                color: AppColors.brandBlue,
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
          ],
          for (var li = 0; li < chunks[ci].length; li++) ...[
            if (li > 0) SizedBox(height: compact ? 8 : 10),
            _LineDesgloseBlock(
              line: chunks[ci][li],
              viewer: viewer,
              compact: compact,
            ),
          ],
        ],
      ],
    );
  }
}

class _LineDesgloseBlock extends StatelessWidget {
  const _LineDesgloseBlock({
    required this.line,
    required this.viewer,
    required this.compact,
  });

  final TransactionRequestModel line;
  final PedidoDesgloseViewer viewer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final partidas = transactionRequestLineasDesgloseForViewer(line, viewer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var j = 0; j < partidas.length; j++) ...[
          if (j > 0)
            compact
                ? const SizedBox(height: 8)
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: AppColors.borderSubtle),
                  ),
          pedidoProductoLineCard(context, partidas[j], compact,
              currencyLabel: line.amountCurrencyLabel),
        ],
      ],
    );
  }
}

/// Qué pidió el aliado a **este** importador: partidas, cantidades y monto al aliado (REF).
class ImporterAliadoSolicitudSection extends StatelessWidget {
  const ImporterAliadoSolicitudSection({
    super.key,
    required this.request,
    this.compact = false,

    /// Dentro de [ImporterExpandableOrderCard]: sin títulos duplicados respecto a la cabecera de la tarjeta.
    this.embedInOrderCard = false,

    /// En cabecera embebida: si es false, solo totales; el desglose va al bloque expandido.
    this.productDetailRows = true,
  });

  final TransactionRequestModel request;
  final bool compact;
  final bool embedInOrderCard;
  final bool productDetailRows;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final uid = SupabaseService.currentUserId;
    final partidas = r.lineasProductoDesglose(forImportadorUserId: uid);
    return _buildDesglose(context, r, partidas);
  }

  Widget _buildDesglose(
    BuildContext context,
    TransactionRequestModel r,
    List<PedidoProductoLineUi> partidas,
  ) {
    final nPart = partidas.length;
    final uds = partidas.fold<int>(0, (a, e) => a + e.cantidad);
    final pad = compact
        ? const EdgeInsets.fromLTRB(0, 6, 0, 0)
        : const EdgeInsets.fromLTRB(0, 0, 0, 0);
    final titleSize = compact ? 12.0 : 13.0;
    final bodySize = compact ? 11.5 : 12.0;
    final showRows = productDetailRows || !embedInOrderCard;

    return Padding(
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!embedInOrderCard) ...[
            Text(
              'Pedido de la tienda minorista',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: titleSize,
                color: AppColors.brandBlue,
              ),
            ),
            SizedBox(height: compact ? 2 : 4),
          ],
          Text(
            '$nPart ${nPart == 1 ? 'línea' : 'líneas'} · $uds uds · '
            '${_totalRefEtiquetaPedidoAliado(r)}'
            '${r.precioTotalBsUi != null ? ' · ~${formatVesAmount(r.precioTotalBsUi!)} Bs' : ''}',
            style: TextStyle(
              fontSize: bodySize * 0.95,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          if (r.tieneDescuentoDivisasAplicadoEnPedido) ...[
            SizedBox(height: compact ? 4 : 6),
            Text(
              'Incluye descuento por pago en ${PagoMetodo.labelEs(r.pagoMetodo!)}.',
              style: TextStyle(
                fontSize: compact ? 10 : 10.5,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade800,
              ),
            ),
          ] else if (r.tieneDescuentoDivisasDisponible) ...[
            SizedBox(height: compact ? 4 : 6),
            Text(
              'Zelle, USDT o efectivo aplican descuento en divisas al registrar el pago.',
              style: TextStyle(
                fontSize: compact ? 10 : 10.5,
                color: AppColors.textSecondary,
                height: 1.25,
              ),
            ),
          ],
          if (!embedInOrderCard) ...[
            const SizedBox(height: 2),
            Text(
              r.amountCurrencyLabel == 'USD'
                  ? 'Precios acordados para pago en divisas (USD).'
                  : 'Precios en REF para pago en bolívares a la tasa BCV del pedido.',
              style: TextStyle(
                fontSize: compact ? 9.5 : 10.5,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            Text(
              'Productos',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 10.5 : 11,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: compact ? 4 : 6),
          ] else
            SizedBox(height: compact ? 6 : 8),
          if (showRows)
            for (var i = 0; i < partidas.length; i++) ...[
              if (i > 0) SizedBox(height: compact ? 4 : 6),
              pedidoProductoLineCard(context, partidas[i], compact,
                  currencyLabel: r.amountCurrencyLabel),
            ],
        ],
      ),
    );
  }
}

/// Varias filas de `transaction_requests` del mismo carrito (`checkout_group_id`): un solo bloque maestro.
class ImporterCheckoutBundleSolicitudSection extends StatelessWidget {
  const ImporterCheckoutBundleSolicitudSection({
    super.key,
    required this.lines,
    this.compact = false,
    this.embedInOrderCard = false,
    this.productDetailRows = true,
  });

  final List<TransactionRequestModel> lines;
  final bool compact;
  final bool embedInOrderCard;
  final bool productDetailRows;

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 12.0 : 13.0;
    final bodySize = compact ? 11.5 : 12.0;
    final pad =
        compact ? const EdgeInsets.fromLTRB(0, 6, 0, 0) : EdgeInsets.zero;
    final totalUds = lines.fold<int>(0, (s, r) => s + r.cantidad);
    final totalRef = lines.fold<double>(0, (s, r) => s + r.precioTotal);
    final uid = SupabaseService.currentUserId;
    final showRows = productDetailRows || !embedInOrderCard;

    return Padding(
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!embedInOrderCard) ...[
            Text(
              'Carrito de la tienda minorista',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: titleSize,
                color: AppColors.brandBlue,
              ),
            ),
            SizedBox(height: compact ? 2 : 4),
          ],
          Text(
            '${lines.length} líneas · $totalUds uds · '
            '${formatRefAmount(totalRef)} ${orderAmountCurrency(lines)}',
            style: TextStyle(
              fontSize: bodySize * 0.95,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          if (!embedInOrderCard) ...[
            const SizedBox(height: 2),
            Text(
              orderAmountCurrency(lines) == 'USD'
                  ? 'Precios acordados para pago en divisas (USD).'
                  : 'Precios en REF para pago en bolívares a la tasa BCV del pedido.',
              style: TextStyle(
                fontSize: compact ? 9.5 : 10.5,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
            SizedBox(height: compact ? 6 : 10),
            Text(
              'Productos',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 10.5 : 11,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: compact ? 4 : 6),
          ] else
            SizedBox(height: compact ? 6 : 8),
          if (showRows)
            for (var i = 0; i < lines.length; i++) ...[
              if (i > 0) SizedBox(height: compact ? 4 : 6),
              _itemLine(context, lines[i], compact, uid),
            ],
        ],
      ),
    );
  }

  Widget _itemLine(
    BuildContext context,
    TransactionRequestModel r,
    bool compact,
    String? importadorUid,
  ) {
    final partidas =
        r.lineasProductoDesglose(forImportadorUserId: importadorUid);
    if (partidas.length == 1) {
      return pedidoProductoLineCard(context, partidas.single, compact,
          currencyLabel: r.amountCurrencyLabel);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var j = 0; j < partidas.length; j++) ...[
          if (j > 0) SizedBox(height: compact ? 4 : 6),
          pedidoProductoLineCard(context, partidas[j], compact,
              currencyLabel: r.amountCurrencyLabel),
        ],
      ],
    );
  }
}

String _totalRefEtiquetaPedidoAliado(TransactionRequestModel r) {
  final total = r.tieneDescuentoDivisasAplicadoEnPedido
      ? r.precioTotal
      : r.refBaseTotalForPago;
  final buf =
      StringBuffer('${formatRefAmount(total)} ${r.amountCurrencyLabel}');
  if (r.tieneDescuentoDivisasAplicadoEnPedido) {
    buf.write(' (antes ${formatRefAmount(r.refBaseTotalForPago)})');
  }
  return buf.toString();
}
