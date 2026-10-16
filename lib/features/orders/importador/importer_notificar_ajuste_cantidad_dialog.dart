import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';

class ImporterQuantityAdjustmentDraft {
  const ImporterQuantityAdjustmentDraft({
    required this.availableQty,
    required this.note,
  });

  final int availableQty;
  final String note;
}

/// Importador: propone formalmente menos unidades (aliado acepta/rechaza en la ficha).
Future<ImporterQuantityAdjustmentDraft?>
    showImporterNotificarAjusteCantidadDialog(
  BuildContext context, {
  required int requestedQty,
}) async {
  final qtyCtrl = TextEditingController(text: requestedQty.toString());
  final noteCtrl = TextEditingController();
  final ok = await showAdaptiveAdminSheet<bool>(
    context: context,
    builder: (ctx, _) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Propuesta de ajuste de cantidad',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Cantidad solicitada: $requestedQty uds.\n'
              'Indique una cantidad menor disponible; la tienda minorista deberá aceptar o rechazar en su ficha '
              '(y puede coordinar por el chat desde el estado pendiente).',
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad disponible',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Comentario para la tienda minorista',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final q = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                    if (q < 1) return;
                    if (q >= requestedQty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Enviar propuesta'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  final q = int.tryParse(qtyCtrl.text.trim()) ?? 0;
  final n = noteCtrl.text.trim();
  qtyCtrl.dispose();
  noteCtrl.dispose();
  if (ok != true || q < 1 || q >= requestedQty) return null;
  return ImporterQuantityAdjustmentDraft(availableQty: q, note: n);
}
