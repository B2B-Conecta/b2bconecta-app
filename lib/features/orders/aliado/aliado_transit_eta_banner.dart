import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';

/// Muestra el ETA de tránsito que registró el importador al marcar «En tránsito».
class AliadoTransitEtaBanner extends StatelessWidget {
  const AliadoTransitEtaBanner({
    super.key,
    required this.request,
    this.compact = false,
    this.importerName,
  });

  final TransactionRequestModel request;
  final bool compact;

  /// Si el carrito tiene varios proveedores, aclara de quién es el plazo.
  final String? importerName;

  static bool shouldShow(TransactionRequestModel r) {
    if (!r.hasTransitEta) return false;
    return r.status == TransactionRequestStatus.enTransito ||
        r.status == TransactionRequestStatus.enviado ||
        r.status == TransactionRequestStatus.entregado;
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShow(request)) return const SizedBox.shrink();

    final eta = request.transitEtaResumenEs;
    if (eta == null || eta.isEmpty) return const SizedBox.shrink();

    final imp = importerName?.trim();
    final titulo = imp != null && imp.isNotEmpty
        ? 'Tiempo estimado · $imp'
        : 'Tiempo estimado de llegada';

    final setAt = request.transitEtaSetAt;
    final registrado = setAt != null
        ? 'Registrado ${formatEsShortDateTime(setAt)}'
        : null;

    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 16,
            color: Colors.teal.shade800,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$titulo: $eta',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.teal.shade900,
                    height: 1.3,
                  ),
                ),
                if (registrado != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    registrado,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Material(
      color: Colors.teal.shade50,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 22,
              color: Colors.teal.shade800,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.teal.shade900.withOpacity(0.85),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    eta,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.teal.shade900,
                      height: 1.2,
                    ),
                  ),
                  if (registrado != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      registrado,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  if (request.status == TransactionRequestStatus.entregado) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Plazo indicado al despachar (referencia).',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
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
  }
}

/// Chip compacto para cabeceras de lista (pedido colapsado).
class AliadoTransitEtaChip extends StatelessWidget {
  const AliadoTransitEtaChip({
    super.key,
    required this.request,
    this.importerName,
  });

  final TransactionRequestModel request;
  final String? importerName;

  @override
  Widget build(BuildContext context) {
    if (!AliadoTransitEtaBanner.shouldShow(request)) {
      return const SizedBox.shrink();
    }
    final eta = request.transitEtaResumenEs;
    if (eta == null) return const SizedBox.shrink();

    final imp = importerName?.trim();
    final label = imp != null && imp.isNotEmpty ? '$imp · ~$eta' : 'Llegada ~$eta';

    return Chip(
      avatar: Icon(
        Icons.schedule,
        size: 16,
        color: Colors.teal.shade800,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.teal.shade900,
        ),
      ),
      backgroundColor: Colors.teal.shade50,
      side: BorderSide(color: Colors.teal.shade200),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
