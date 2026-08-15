import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/orders/shared/order_flow_copy/order_actions_flow_copy.dart';

/// Pide al importador el ETA (días y horas) antes de marcar el pedido en tránsito.
/// Devuelve `(días, horas)` o `null` si canceló.
Future<({int days, int hours})?> showImporterTransitEtaDialog(
  BuildContext context,
) async {
  return showDialog<({int days, int hours})?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _ImporterTransitEtaDialog(),
  );
}

class _ImporterTransitEtaDialog extends StatefulWidget {
  const _ImporterTransitEtaDialog();

  @override
  State<_ImporterTransitEtaDialog> createState() =>
      _ImporterTransitEtaDialogState();
}

class _ImporterTransitEtaDialogState extends State<_ImporterTransitEtaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _daysCtrl;
  late final TextEditingController _hoursCtrl;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _daysCtrl = TextEditingController(text: '0');
    _hoursCtrl = TextEditingController(text: '4');
  }

  @override
  void dispose() {
    _daysCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final d = int.parse(_daysCtrl.text.trim());
    final h = int.parse(_hoursCtrl.text.trim());
    if (d == 0 && h == 0) {
      setState(() {
        _inlineError = OrderActionsFlowCopy.transitEtaErrorCero;
      });
      return;
    }
    Navigator.pop(context, (days: d, hours: h));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(OrderActionsFlowCopy.transitEtaTitulo),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              OrderActionsFlowCopy.transitEtaIntro,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _daysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: OrderActionsFlowCopy.transitEtaDias,
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) {
                if (_inlineError != null) {
                  setState(() => _inlineError = null);
                }
              },
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
              controller: _hoursCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: OrderActionsFlowCopy.transitEtaHoras,
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) {
                if (_inlineError != null) {
                  setState(() => _inlineError = null);
                }
              },
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 0 || n > 23) {
                  return '0 a 23';
                }
                return null;
              },
            ),
            if (_inlineError != null) ...[
              const SizedBox(height: 10),
              Text(
                _inlineError!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(OrderActionsFlowCopy.transitEtaConfirmar),
        ),
      ],
    );
  }
}
