import 'package:flutter/material.dart';

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
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Propuesta de ajuste de cantidad'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cantidad solicitada: $requestedQty uds.\n'
              'Indique una cantidad menor disponible; el aliado deberá aceptar o rechazar en su ficha '
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
                labelText: 'Comentario para el aliado',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
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
