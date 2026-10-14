import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/orders/shared/order_flow_copy/order_actions_flow_copy.dart';

/// Pide al importador el tiempo de llegada antes de marcar el pedido en tránsito.
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
  int _days = 0;
  int _hours = 4;
  String? _inlineError;

  void _setDays(int value) {
    setState(() {
      _days = value.clamp(0, 365);
      _inlineError = null;
    });
  }

  void _setHours(int value) {
    setState(() {
      _hours = value.clamp(0, 23);
      _inlineError = null;
    });
  }

  void _submit() {
    if (_days == 0 && _hours == 0) {
      setState(() {
        _inlineError = OrderActionsFlowCopy.transitEtaErrorCero;
      });
      return;
    }
    Navigator.pop(context, (days: _days, hours: _hours));
  }

  String get _preview {
    final days = _days == 1 ? '1 día' : '$_days días';
    final hours = _hours == 1 ? '1 hora' : '$_hours horas';
    return 'Llega en $days y $hours.';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(OrderActionsFlowCopy.transitEtaTitulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            OrderActionsFlowCopy.transitEtaIntro,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          _StepperRow(
            label: OrderActionsFlowCopy.transitEtaDias,
            value: _days,
            onMinus: _days <= 0 ? null : () => _setDays(_days - 1),
            onPlus: _days >= 365 ? null : () => _setDays(_days + 1),
          ),
          const SizedBox(height: 10),
          _StepperRow(
            label: OrderActionsFlowCopy.transitEtaHoras,
            value: _hours,
            onMinus: _hours <= 0 ? null : () => _setHours(_hours - 1),
            onPlus: _hours >= 23 ? null : () => _setHours(_hours + 1),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.brandBlueContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _preview,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
              ),
            ),
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

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Menos',
            onPressed: onMinus,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Más',
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
