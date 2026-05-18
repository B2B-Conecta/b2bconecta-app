import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../theme/app_theme.dart';
import '../utils/aliado_multi_importer_payment.dart';
import '../utils/ves_amount_format.dart';
import 'aliado_importador_factura_section.dart';
import 'aliado_order_experience_display.dart';

/// Bloque visual por importador dentro de un carrito multi-proveedor.
class AliadoImportadorPedidoBlock extends StatelessWidget {
  const AliadoImportadorPedidoBlock({
    super.key,
    required this.index,
    required this.total,
    required this.chunk,
    required this.child,
  });

  /// 1-based
  final int index;
  final int total;
  final List<TransactionRequestModel> chunk;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final name = chunk.first.ownerBusinessName ?? 'Importador';
    final fase = fasePagoBloqueImportador(chunk);
    final monto = subtotalBloqueImportador(chunk);
    final lineCount = chunk.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.2),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.brandBlue.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.brandBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$index',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Proveedor $index de $total',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AliadoOrderExperienceStatusChip(
                      request: chunk.first,
                      linesForGroup: chunk,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _PasoChip(
                      label: '1. Factura',
                      done: chunk.any((r) => r.hasProveedorFactura),
                      active: fase == AliadoImportadorPagoFase.esperandoFacturaProveedor,
                    ),
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade500),
                    _PasoChip(
                      label: '2. Su pago',
                      done: fase == AliadoImportadorPagoFase.pagoConfirmado,
                      active: fase == AliadoImportadorPagoFase.pendientePago ||
                          fase == AliadoImportadorPagoFase.comprobanteEnRevision,
                    ),
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade500),
                    _PasoChip(
                      label: '3. Recepción',
                      done: chunk.every(
                        (r) => r.status == TransactionRequestStatus.entregado,
                      ),
                      active: false,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$lineCount ${lineCount == 1 ? "línea" : "líneas"} · '
                        'A pagar a este proveedor: ${formatRefAmount(monto)} REF',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  fasePagoBloqueLabelEs(fase),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _faseTextColor(fase),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: AliadoImportadorFacturaSection(lines: chunk),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: child,
          ),
        ],
      ),
    );
  }

  Color _faseTextColor(AliadoImportadorPagoFase fase) {
    switch (fase) {
      case AliadoImportadorPagoFase.pagoConfirmado:
        return Colors.green.shade800;
      case AliadoImportadorPagoFase.esperandoFacturaProveedor:
        return Colors.amber.shade900;
      case AliadoImportadorPagoFase.comprobanteEnRevision:
        return Colors.orange.shade900;
      case AliadoImportadorPagoFase.pendientePago:
        return AppColors.brandBlue;
      default:
        return Colors.grey.shade700;
    }
  }
}

class _PasoChip extends StatelessWidget {
  const _PasoChip({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bg = done
        ? Colors.green.shade50
        : active
            ? Colors.orange.shade50
            : Colors.grey.shade100;
    final border = done
        ? Colors.green.shade300
        : active
            ? Colors.orange.shade300
            : Colors.grey.shade300;
    final fg = done
        ? Colors.green.shade900
        : active
            ? Colors.orange.shade900
            : Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done)
            Icon(Icons.check, size: 14, color: fg)
          else if (active)
            Icon(Icons.radio_button_checked, size: 14, color: fg)
          else
            Icon(Icons.radio_button_off, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}
