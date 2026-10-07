import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'order_return_request_screen.dart';
import 'order_return_rules.dart';
import 'transaction_request_model.dart';

/// Accesos a devolución de las líneas de una ficha que cumplen [OrderReturnRules].
class OrderReturnButtons extends StatelessWidget {
  const OrderReturnButtons({
    super.key,
    required this.lines,
    required this.allowReplyAsAliado,
    required this.allowReplyAsImportador,
  });

  final List<TransactionRequestModel> lines;
  final bool allowReplyAsAliado;
  final bool allowReplyAsImportador;

  @override
  Widget build(BuildContext context) {
    final eligible = lines
        .where(
          (line) => OrderReturnRules.isAvailable(
            status: line.status,
            updatedAt: line.updatedAt,
          ),
        )
        .toList();
    if (eligible.isEmpty) return const SizedBox.shrink();
    final showProduct = lines.length > 1;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in eligible) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OrderReturnRequestScreen(
                      request: line,
                      allowReplyAsAliado: allowReplyAsAliado,
                      allowReplyAsImportador: allowReplyAsImportador,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.assignment_return_outlined, size: 18),
              label: Text(_label(line, showProduct: showProduct)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                side: const BorderSide(color: AppColors.brand),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  String _label(TransactionRequestModel line, {required bool showProduct}) {
    if (!showProduct) return 'Devoluciones';
    final name = line.productName?.trim();
    if (name == null || name.isEmpty) return 'Devoluciones';
    return 'Devoluciones · $name';
  }
}
