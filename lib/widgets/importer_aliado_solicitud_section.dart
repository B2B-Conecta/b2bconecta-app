import 'package:flutter/material.dart';

import '../models/order_item_model.dart';
import '../models/transaction_request_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Qué pidió el aliado a **este** importador: partidas, cantidades y monto al aliado (REF).
class ImporterAliadoSolicitudSection extends StatelessWidget {
  const ImporterAliadoSolicitudSection({
    super.key,
    required this.request,
    this.compact = false,
  });

  final TransactionRequestModel request;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final uid = SupabaseService.currentUserId;
    final lines = r.orderItemsParaVistaImportador(uid);

    if (lines.isNotEmpty) {
      return _conPartidas(r, lines);
    }
    return _sinPartidasEnApi(r);
  }

  Widget _conPartidas(TransactionRequestModel r, List<OrderItemModel> lines) {
    final nPart = lines.length;
    final uds = r.totalUnidadesImportador(lines);
    final pad = compact
        ? const EdgeInsets.fromLTRB(0, 6, 0, 0)
        : const EdgeInsets.fromLTRB(0, 0, 0, 0);
    final titleSize = compact ? 12.0 : 13.0;
    final bodySize = compact ? 11.5 : 12.0;

    return Padding(
      padding: pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Solicitud del aliado',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: titleSize,
              color: AppColors.brandBlue,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            '$nPart partida(s) · $uds uds · subtotal (tu tramo) '
            '${r.precioTotal.toStringAsFixed(2)} REF'
            '${r.precioTotalBsUi != null ? ' · ~${r.precioTotalBsUi!.toStringAsFixed(2)} BS' : ''}',
            style: TextStyle(
              fontSize: bodySize * 0.95,
              color: Colors.grey.shade800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Los montos REF son el precio oferta al aliado fijado por MotoLink (tu referencia para alistar la carga).',
            style: TextStyle(
              fontSize: compact ? 9.5 : 10.5,
              color: Colors.grey.shade600,
              height: 1.3,
            ),
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(
            'Desglose por producto',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 10.5 : 11,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) SizedBox(height: compact ? 4 : 6),
            _lineaItem(lines[i], compact),
          ],
        ],
      ),
    );
  }

  Widget _lineaItem(OrderItemModel p, bool compact) {
    final nm = p.productName?.trim() ?? 'Producto';
    final sku = p.productSku?.trim();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nm,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: compact ? 12.0 : 12.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (sku != null && sku.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'SKU: $sku',
              style: TextStyle(
                fontSize: compact ? 10 : 10.5,
                color: Colors.grey.shade700,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            '${p.cantidad} uds · ${p.precioLineTotal.toStringAsFixed(2)} REF (línea)',
            style: TextStyle(
              fontSize: compact ? 11 : 11.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  /// Pedido 1:1 o sin `order_items` en la carga: un solo bloque de contexto.
  Widget _sinPartidasEnApi(TransactionRequestModel r) {
    final pad = compact
        ? const EdgeInsets.fromLTRB(0, 6, 0, 0)
        : EdgeInsets.zero;
    final name = r.productName?.trim().isNotEmpty == true
        ? r.productName!.trim()
        : 'Producto';
    return Padding(
      padding: pad,
      child: Material(
        color: AppColors.brandBlueContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Solicitud del aliado',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 12.0 : 13.0,
                  color: AppColors.brandBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (r.productSku != null && r.productSku!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'SKU: ${r.productSku}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${r.cantidad} uds · subtotal (precio al aliado, tu tramo) '
                '${r.precioTotal.toStringAsFixed(2)} REF',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
