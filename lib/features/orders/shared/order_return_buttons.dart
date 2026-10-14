import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'order_card_collapsible_layout.dart';
import 'order_issue_report_screen.dart';
import 'order_replacement_tracker.dart';
import 'order_return_rules.dart';
import 'transaction_request_model.dart';
import 'transaction_request_status.dart';

/// Devolución o queja anotada en la cabecera del pedido.
class OrderPostventaHeaderMarks extends StatelessWidget {
  const OrderPostventaHeaderMarks({super.key, required this.lines});

  final List<TransactionRequestModel> lines;

  @override
  Widget build(BuildContext context) {
    final cambio = lines.any((l) => l.postventaResolucion == 'cambio');
    final credito = lines.any((l) => l.postventaResolucion == 'credito');
    final rechazo = lines.any((l) => l.postventaResolucion == 'rechazo');
    final devolucionAbierta = lines.any(
      (l) => l.postventaDevolucionAt != null && l.postventaResolucion == null,
    );
    final queja = lines.any((l) => l.postventaQuejaAt != null);
    if (!cambio && !credito && !rechazo && !devolucionAbierta && !queja) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (devolucionAbierta)
            const OrderCardCompactNoticeChip(
              label: 'Devolución en revisión',
              icon: Icons.assignment_return_outlined,
              color: AppColors.brand,
            ),
          if (rechazo)
            OrderCardCompactNoticeChip(
              label: 'Devolución no aceptada',
              icon: Icons.assignment_return_outlined,
              color: AppColors.textSecondary,
            ),
          if (cambio)
            const OrderCardCompactNoticeChip(
              label: 'Cambio de producto',
              icon: Icons.swap_horiz,
              color: AppColors.brand,
            ),
          if (credito)
            const OrderCardCompactNoticeChip(
              label: 'Crédito a favor',
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.brandAccent,
            ),
          if (queja)
            const OrderCardCompactNoticeChip(
              label: 'Queja registrada',
              icon: Icons.report_outlined,
              color: Color(0xFF8A5A00),
            ),
        ],
      ),
    );
  }
}

/// Acciones de postventa en la sección Mensajes.
class OrderReturnButtons extends StatelessWidget {
  const OrderReturnButtons({
    super.key,
    required this.lines,
    required this.allowReplyAsAliado,
    required this.allowReplyAsImportador,
    this.confirmReplacementAsAliado = false,
    this.dispatchReplacementAsImporter = false,
    this.showReplacementTracker = true,
    this.onChanged,
  });

  final List<TransactionRequestModel> lines;
  final bool allowReplyAsAliado;
  final bool allowReplyAsImportador;

  /// La tienda confirma la recepción del cambio aunque el chat ya esté cerrado.
  final bool confirmReplacementAsAliado;

  /// El proveedor marca el cambio en tránsito aunque el chat ya esté cerrado.
  final bool dispatchReplacementAsImporter;
  final bool showReplacementTracker;
  final VoidCallback? onChanged;

  bool _open(TransactionRequestModel line) => OrderReturnRules.isAvailable(
        status: line.status,
        updatedAt: line.updatedAt,
        deliveredAt: line.atEntregado,
      );

  @override
  Widget build(BuildContext context) {
    final canStart = allowReplyAsAliado &&
        lines.any(
          (line) => line.postventaDevolucionAt == null && _open(line),
        );
    final canReview = allowReplyAsAliado &&
        lines.any((line) => line.postventaDevolucionAt != null);
    final windowClosed = allowReplyAsAliado &&
        !canStart &&
        !canReview &&
        lines.any(
          (line) =>
              line.status == TransactionRequestStatus.entregado &&
              line.postventaDevolucionAt == null,
        );
    final pendingForImporter = allowReplyAsImportador &&
        lines.any(
          (line) =>
              line.postventaDevolucionAt != null &&
              line.postventaResolucion == null,
        );

    if (!canStart && !canReview && !windowClosed && !pendingForImporter) {
      return _tracker();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canStart) ...[
            Text(
              OrderReturnRules.openHint,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openReport(context, viewOnly: false),
              icon: const Icon(Icons.warning_amber_rounded, size: 18),
              label: const Text('¿Algo pasa con tu pedido?'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                side: const BorderSide(color: AppColors.brand),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ] else if (canReview)
            OutlinedButton.icon(
              onPressed: () => _openReport(context, viewOnly: true),
              icon: const Icon(Icons.assignment_outlined, size: 18),
              label: const Text('Ver reporte del pedido'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                side: const BorderSide(color: AppColors.brand),
                minimumSize: const Size(double.infinity, 44),
              ),
            )
          else if (windowClosed)
            Text(
              OrderReturnRules.closedHint,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          if (pendingForImporter) ...[
            Text(
              'Hay un reporte pendiente. La respuesta se hace en el chat del pedido.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          _tracker(),
        ],
      ),
    );
  }

  Widget _tracker() {
    if (!showReplacementTracker) return const SizedBox.shrink();
    return OrderReplacementTracker(
      lines: lines,
      allowImporterAdvance:
          allowReplyAsImportador || dispatchReplacementAsImporter,
      allowAliadoAdvance: allowReplyAsAliado || confirmReplacementAsAliado,
      onChanged: onChanged,
    );
  }

  Future<void> _openReport(BuildContext context, {required bool viewOnly}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OrderIssueReportScreen(
          lines: lines,
          viewOnly: viewOnly,
        ),
      ),
    );
    if (saved == true) onChanged?.call();
  }
}
