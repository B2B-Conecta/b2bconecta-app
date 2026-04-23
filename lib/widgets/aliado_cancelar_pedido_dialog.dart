import 'package:flutter/material.dart';

/// Devuelve el motivo o null si cancela.
Future<String?> showAliadoCancelarPedidoPendienteDialog(BuildContext context) async {
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'MotoLink aún no ha aprobado este pedido. Indique el motivo; se notificará al equipo MotoLink y a su importador.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              maxLength: 4000,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Motivo de la cancelación',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (ctrl.text.trim().length < 3) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirmar cancelación'),
          ),
        ],
      );
    },
  );
  final t = ctrl.text.trim();
  ctrl.dispose();
  if (ok != true) return null;
  if (t.length < 3) return null;
  return t;
}
