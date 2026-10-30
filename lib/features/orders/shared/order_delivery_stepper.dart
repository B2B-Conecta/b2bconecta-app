import 'package:flutter/material.dart';
import 'order_list_colors.dart';
import 'order_list_entry.dart';
import 'transaction_request_model.dart';
import 'transaction_request_status.dart';

/// The dispatch journey is independent from the negotiated payment schedule.
class OrderDeliveryStepper extends StatelessWidget {
  const OrderDeliveryStepper({super.key, required this.lines});
  final List<TransactionRequestModel> lines;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    final phases = lines
        .map((l) => orderShippingPhase(l.status))
        .where((p) => p >= 0)
        .toList();
    if (phases.isEmpty) {
      return Text(
          lines.every((l) => l.status == TransactionRequestStatus.rechazado)
              ? 'Este pedido fue cancelado.'
              : 'El seguimiento aún no está disponible.',
          style: TextStyle(color: colors.secondary, height: 1.4));
    }
    final current = phases.reduce((a, b) => a < b ? a : b);
    final done =
        lines.every((l) => l.status == TransactionRequestStatus.entregado);
    final mixed = lines.any((l) => l.status != lines.first.status);
    const names = ['Confirmación', 'Preparación', 'En camino', 'Entrega'];
    const icons = [
      Icons.receipt_long_outlined,
      Icons.inventory_2_outlined,
      Icons.local_shipping_outlined,
      Icons.check_circle_outline
    ];
    Widget node(int i) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i <= current ? colors.accent : colors.surface,
            border: Border.all(
                color: i <= current ? colors.accent : colors.border)),
        child: Icon(i < current || done ? Icons.check_rounded : icons[i],
            size: 18,
            color: i <= current
                ? (colors.dark ? Colors.black : Colors.white)
                : colors.secondary));
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 540 ||
          MediaQuery.textScalerOf(context).scale(12) > 17;
      return Semantics(
          label: 'Seguimiento del envío',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mixed)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                        'Los productos tienen avances distintos. Revisa el historial.',
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: colors.secondary))),
              if (compact)
                Wrap(spacing: 12, runSpacing: 16, children: [
                  for (var i = 0; i < 4; i++)
                    SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: Row(children: [
                          node(i),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(names[i],
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: i == current
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: i <= current
                                          ? colors.accent
                                          : colors.secondary)))
                        ])),
                ])
              else
                Column(children: [
                  Row(children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0)
                        Expanded(
                            child: Container(
                                height: 2,
                                color: i <= current
                                    ? colors.accent
                                    : colors.border)),
                      node(i),
                    ]
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (var i = 0; i < 4; i++)
                      Expanded(
                          child: Text(names[i],
                              textAlign: i == 0
                                  ? TextAlign.left
                                  : i == 3
                                      ? TextAlign.right
                                      : TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: i == current
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: i <= current
                                      ? colors.accent
                                      : colors.secondary)))
                  ]),
                ]),
            ],
          ));
    });
  }
}
