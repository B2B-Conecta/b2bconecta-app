import 'package:flutter/material.dart';

/// Pide al importador el ETA (días y horas) antes de marcar el pedido en tránsito.
/// Devuelve `(días, horas)` o `null` si canceló.
Future<({int days, int hours})?> showImporterTransitEtaDialog(
  BuildContext context,
) async {
  final daysCtrl = TextEditingController(text: '0');
  final hoursCtrl = TextEditingController(text: '4');
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<({int days, int hours})?>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Tiempo estimado de tránsito'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Indique cuándo estima que la mercancía llegará al taller del aliado. '
                'El aliado verá este plazo en el seguimiento del pedido.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: daysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Días (0–365)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0 || n > 365) {
                    return '0 a 365';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: hoursCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Horas (0–23)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0 || n > 23) {
                    return '0 a 23';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final d = int.parse(daysCtrl.text.trim());
              final h = int.parse(hoursCtrl.text.trim());
              if (d == 0 && h == 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Indique al menos un día o una hora mayor que cero.',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, (days: d, hours: h));
            },
            child: const Text('Confirmar y marcar en tránsito'),
          ),
        ],
      );
    },
  );

  daysCtrl.dispose();
  hoursCtrl.dispose();
  return result;
}
