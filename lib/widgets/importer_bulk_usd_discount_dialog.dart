import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'product_usd_payment_discount_field.dart';

/// Alcance de la actualización masiva de % descuento USD.
enum ImporterBulkUsdDiscountScope {
  conDescuento,
  todos,
}

/// Diálogo: nuevo % de descuento USD para varios productos del inventario.
class ImporterBulkUsdDiscountDialog extends StatefulWidget {
  const ImporterBulkUsdDiscountDialog({super.key});

  static Future<({
    double pct,
    ImporterBulkUsdDiscountScope scope,
  })?> show(BuildContext context) {
    return showDialog<({
      double pct,
      ImporterBulkUsdDiscountScope scope,
    })>(
      context: context,
      builder: (_) => const ImporterBulkUsdDiscountDialog(),
    );
  }

  @override
  State<ImporterBulkUsdDiscountDialog> createState() =>
      _ImporterBulkUsdDiscountDialogState();
}

class _ImporterBulkUsdDiscountDialogState
    extends State<ImporterBulkUsdDiscountDialog> {
  final _pctController = TextEditingController();
  ImporterBulkUsdDiscountScope _scope =
      ImporterBulkUsdDiscountScope.conDescuento;

  @override
  void dispose() {
    _pctController.dispose();
    super.dispose();
  }

  void _confirm() {
    final pct = parseUsdPaymentDiscountPctField(_pctController.text);
    if (pct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Indique un % válido entre 0 y 100 (0 quita el descuento USD).',
          ),
        ),
      );
      return;
    }
    Navigator.pop(context, (pct: pct, scope: _scope));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.percent, color: AppColors.brand),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Actualizar descuentos USD',
              style: TextStyle(fontSize: 17),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Aplica el mismo % de descuento en precio USD (Zelle, Binance, USDT, efectivo) '
              'a varios productos de una vez, o use 0 para quitar todos esos descuentos. '
              'No modifica oferta ni tramos por volumen.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            ProductUsdPaymentDiscountField(controller: _pctController),
            const SizedBox(height: 16),
            Text(
              'Aplicar a',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            RadioListTile<ImporterBulkUsdDiscountScope>(
              value: ImporterBulkUsdDiscountScope.conDescuento,
              groupValue: _scope,
              onChanged: (v) => setState(() => _scope = v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Solo productos con descuento USD previo',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Actualiza el % en artículos que ya tenían descuento USD configurado.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
            RadioListTile<ImporterBulkUsdDiscountScope>(
              value: ImporterBulkUsdDiscountScope.todos,
              groupValue: _scope,
              onChanged: (v) => setState(() => _scope = v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Todos mis productos',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Aplica el % a todo el inventario, o 0 para quitar descuentos USD en todos '
                '(conserva tramos por volumen si existen).',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
