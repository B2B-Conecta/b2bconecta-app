import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../theme/app_theme.dart';
import '../utils/aliado_multi_importer_payment.dart';
import '../utils/ves_amount_format.dart';

/// Resumen del carrito con varios importadores: pagos independientes por proveedor.
class AliadoMultiImporterCheckoutOverview extends StatelessWidget {
  const AliadoMultiImporterCheckoutOverview({
    super.key,
    required this.allLines,
    required this.porImportador,
  });

  final List<TransactionRequestModel> allLines;
  final List<List<TransactionRequestModel>> porImportador;

  @override
  Widget build(BuildContext context) {
    final nImp = porImportador.length;
    if (nImp < 2) return const SizedBox.shrink();

    final pagados = importadoresConPagoConfirmado(porImportador);
    final totalRef =
        allLines.fold<double>(0, (s, r) => s + r.precioTotal);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandBlueContainer.withOpacity(0.55),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.brandBlue.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart_outlined, color: AppColors.brandBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Carrito con $nImp importadores',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cada proveedor emite su factura y usted realiza un pago separado. '
            'Total del pedido: ${formatRefAmount(totalRef)} REF.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: nImp > 0 ? pagados / nImp : 0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: pagados == nImp ? Colors.green.shade600 : AppColors.brandBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pagos confirmados por importadores: $pagados de $nImp',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: pagados == nImp
                  ? Colors.green.shade800
                  : AppColors.brandBlue,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(porImportador.length, (i) {
            final chunk = porImportador[i];
            final fase = fasePagoBloqueImportador(chunk);
            final name = chunk.first.ownerBusinessName ?? 'Importador';
            final monto = subtotalBloqueImportador(chunk);
            return Padding(
              padding: EdgeInsets.only(bottom: i < nImp - 1 ? 8 : 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: _faseColor(fase).withOpacity(0.15),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _faseColor(fase),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${formatRefAmount(monto)} REF · ${fasePagoBloqueLabelEs(fase)}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(_faseIcon(fase), size: 20, color: _faseColor(fase)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _faseColor(AliadoImportadorPagoFase fase) {
    switch (fase) {
      case AliadoImportadorPagoFase.pagoConfirmado:
        return Colors.green.shade700;
      case AliadoImportadorPagoFase.comprobanteEnRevision:
        return Colors.orange.shade800;
      case AliadoImportadorPagoFase.pendientePago:
        return AppColors.brandBlue;
      case AliadoImportadorPagoFase.esperandoFacturaProveedor:
        return Colors.amber.shade900;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _faseIcon(AliadoImportadorPagoFase fase) {
    switch (fase) {
      case AliadoImportadorPagoFase.pagoConfirmado:
        return Icons.check_circle;
      case AliadoImportadorPagoFase.comprobanteEnRevision:
        return Icons.hourglass_top;
      case AliadoImportadorPagoFase.pendientePago:
        return Icons.payments_outlined;
      case AliadoImportadorPagoFase.esperandoFacturaProveedor:
        return Icons.receipt_long_outlined;
      default:
        return Icons.local_shipping_outlined;
    }
  }
}
