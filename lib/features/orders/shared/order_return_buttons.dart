import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'order_card_collapsible_layout.dart';
import 'order_return_request_screen.dart';
import 'order_return_rules.dart';
import 'transaction_request_model.dart';
import 'transaction_request_status.dart';

/// Devolución o queja anotada en la cabecera del pedido.
class OrderPostventaHeaderMarks extends StatelessWidget {
  const OrderPostventaHeaderMarks({super.key, required this.lines});

  final List<TransactionRequestModel> lines;

  @override
  Widget build(BuildContext context) {
    final devolucion = lines.any((l) => l.postventaDevolucionAt != null);
    final queja = lines.any((l) => l.postventaQuejaAt != null);
    if (!devolucion && !queja) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (devolucion)
            OrderCardCompactNoticeChip(
              label: 'Devolución registrada',
              icon: Icons.assignment_return_outlined,
              color: AppColors.brand,
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
    this.mergedThreadRequestIds,
    this.onChanged,
  });

  final List<TransactionRequestModel> lines;
  final bool allowReplyAsAliado;
  final bool allowReplyAsImportador;
  final List<String>? mergedThreadRequestIds;
  final VoidCallback? onChanged;

  bool get _canRegister => allowReplyAsAliado || allowReplyAsImportador;

  @override
  Widget build(BuildContext context) {
    final showProduct = lines.length > 1;
    final buttons = <Widget>[];

    for (final line in lines) {
      final open = OrderReturnRules.isAvailable(
        status: line.status,
        updatedAt: line.updatedAt,
        deliveredAt: line.atEntregado,
      );
      if (line.postventaDevolucionAt != null || (open && _canRegister)) {
        buttons.add(
          _button(
            context,
            line: line,
            kind: OrderPostventaKind.devolucion,
            existing: line.postventaDevolucionAt != null,
            showProduct: showProduct,
          ),
        );
      }
      if (line.postventaQuejaAt != null || (open && _canRegister)) {
        buttons.add(
          _button(
            context,
            line: line,
            kind: OrderPostventaKind.queja,
            existing: line.postventaQuejaAt != null,
            showProduct: showProduct,
          ),
        );
      }
    }

    final deliveredWithoutCase = lines.any(
      (line) =>
          line.status == TransactionRequestStatus.entregado &&
          line.postventaDevolucionAt == null &&
          line.postventaQuejaAt == null &&
          !OrderReturnRules.isAvailable(
            status: line.status,
            updatedAt: line.updatedAt,
            deliveredAt: line.atEntregado,
          ),
    );

    if (buttons.isEmpty && !(_canRegister && deliveredWithoutCase)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (buttons.isEmpty && _canRegister && deliveredWithoutCase)
            Text(
              OrderReturnRules.closedHint,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          for (final button in buttons) ...[
            button,
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _button(
    BuildContext context, {
    required TransactionRequestModel line,
    required String kind,
    required bool existing,
    required bool showProduct,
  }) {
    final name = line.productName?.trim();
    final product = showProduct && name != null && name.isNotEmpty
        ? ' · $name'
        : '';
    final label = existing
        ? '${OrderPostventaKind.viewLabel(kind)}$product'
        : '${OrderPostventaKind.actionLabel(kind)}$product';
    return OutlinedButton.icon(
      onPressed: () async {
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => OrderReturnRequestScreen(
              request: line,
              kind: kind,
              alreadyRegistered: existing,
              allowReplyAsAliado: allowReplyAsAliado,
              allowReplyAsImportador: allowReplyAsImportador,
              mergedThreadRequestIds: mergedThreadRequestIds,
            ),
          ),
        );
        if (saved == true) onChanged?.call();
      },
      icon: Icon(
        kind == OrderPostventaKind.devolucion
            ? Icons.assignment_return_outlined
            : Icons.report_outlined,
        size: 18,
      ),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.brand,
        side: const BorderSide(color: AppColors.brand),
        minimumSize: const Size.fromHeight(44),
      ),
    );
  }
}
