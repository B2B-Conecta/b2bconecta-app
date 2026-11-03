import 'package:flutter/material.dart';
import 'order_list_colors.dart';
import 'order_list_entry.dart';
import 'pedidos_scope_bar.dart';
import 'transaction_request_model.dart';

/// Stable partition: preserve the existing order inside each priority group.
List<List<TransactionRequestModel>> prioritizePendingOrders(
        List<List<TransactionRequestModel>> groups) =>
    [
      ...groups.where((g) => OrderListEntry(g).awaitingConfirmation),
      ...groups.where((g) => !OrderListEntry(g).awaitingConfirmation),
    ];

class OrderPriorityControls extends StatelessWidget {
  const OrderPriorityControls(
      {super.key,
      required this.scope,
      required this.onScope,
      required this.pendingOnly,
      required this.pendingCount,
      required this.onPending,
      required this.pendingFirst,
      required this.onSort});
  final PedidosListScope scope;
  final ValueChanged<PedidosListScope> onScope;
  final bool pendingOnly;
  final int pendingCount;
  final VoidCallback onPending;
  final bool pendingFirst;
  final ValueChanged<bool> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    Widget chip(String label, IconData icon, bool selected, VoidCallback tap,
        {bool pending = false, int? count}) {
      final tone = pending ? colors.pendingAccent : colors.accent;
      return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            selected: selected,
            onSelected: (_) => tap(),
            showCheckmark: false,
            avatar:
                Icon(icon, size: 17, color: selected ? tone : colors.secondary),
            selectedColor: tone.withOpacity(.12),
            backgroundColor: colors.surface,
            side: BorderSide(
                color: selected ? tone.withOpacity(.3) : colors.border),
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label),
              if (count != null) ...[
                const SizedBox(width: 7),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: colors.pendingAccent.withOpacity(.15),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('$count',
                        style: TextStyle(
                            color: colors.pendingAccent,
                            fontWeight: FontWeight.w700))),
              ],
            ]),
            labelStyle: TextStyle(
                fontSize: 12,
                color: selected ? tone : colors.secondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ));
    }

    final tabs = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          chip(
              'Todos',
              Icons.receipt_long_outlined,
              !pendingOnly && scope == PedidosListScope.todos,
              () => onScope(PedidosListScope.todos)),
          chip('Por confirmar', Icons.schedule_outlined, pendingOnly, onPending,
              pending: true, count: pendingCount),
          chip(
              'En curso',
              Icons.local_shipping_outlined,
              !pendingOnly && scope == PedidosListScope.enCurso,
              () => onScope(PedidosListScope.enCurso)),
          chip(
              'Entregados',
              Icons.check_circle_outline,
              !pendingOnly && scope == PedidosListScope.entregados,
              () => onScope(PedidosListScope.entregados)),
          chip(
              'Cancelados',
              Icons.block_outlined,
              !pendingOnly && scope == PedidosListScope.cancelados,
              () => onScope(PedidosListScope.cancelados)),
        ]));
    final sort = PopupMenuButton<bool>(
      tooltip: 'Ordenar pedidos',
      initialValue: pendingFirst,
      onSelected: onSort,
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
            value: true,
            checked: pendingFirst,
            child: const Text('Pendientes primero')),
        CheckedPopupMenuItem(
            value: false,
            checked: !pendingFirst,
            child: const Text('Orden habitual')),
      ],
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.swap_vert, size: 18, color: colors.secondary),
            const SizedBox(width: 5),
            Text(pendingFirst ? 'Pendientes primero' : 'Orden habitual',
                style: TextStyle(fontSize: 12, color: colors.secondary)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: colors.secondary),
          ])),
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 1000 ||
          MediaQuery.textScalerOf(context).scale(12) > 17) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tabs,
              Align(alignment: Alignment.centerRight, child: sort)
            ]);
      }
      return Row(
          children: [Expanded(child: tabs), const SizedBox(width: 12), sort]);
    });
  }
}
