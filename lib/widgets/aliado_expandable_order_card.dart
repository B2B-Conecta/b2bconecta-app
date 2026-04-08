import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../theme/app_theme.dart';
import 'transaction_request_admin_sections.dart';

/// Ficha compacta para aliado: resumen y detalle con importador y ciclo del envío.
class AliadoExpandableOrderCard extends StatelessWidget {
  const AliadoExpandableOrderCard({
    super.key,
    required this.request,
    required this.expanded,
    required this.onToggle,
    required this.statusLabel,
  });

  final TransactionRequestModel request;
  final bool expanded;
  final VoidCallback onToggle;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final tracking = TransactionRequestStatus.aliadoTrackingHeadline(r.status);
    final showHeadline = tracking.isNotEmpty && tracking != '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeadline) ...[
                            Text(
                              tracking,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: r.status == TransactionRequestStatus.rechazado
                                    ? Colors.red.shade800
                                    : r.status == TransactionRequestStatus.entregado
                                        ? Colors.green.shade800
                                        : AppColors.brandBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.productName ?? 'Producto',
                                  maxLines: expanded ? 3 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Chip(
                                label: Text(
                                  statusLabel,
                                  style: const TextStyle(fontSize: 10),
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                          if (r.productSku != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'SKU: ${r.productSku}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '${r.cantidad} uds · Total estimado '
                            '\$${r.precioTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (r.aliadoCreditScore != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Tu crédito: ${r.aliadoCreditScore}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandBlue.withOpacity(0.95),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: onToggle,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Cerrar'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                        TransactionRequestImporterContactSection(request: r),
                        const SizedBox(height: 12),
                        TransactionRequestLifecycleSection(request: r),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
