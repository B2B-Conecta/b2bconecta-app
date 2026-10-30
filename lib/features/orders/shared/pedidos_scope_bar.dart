import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'order_list_colors.dart';

/// Vista de la lista de pedidos, igual para tienda, proveedor y administrador.
enum PedidosListScope { todos, enCurso, entregados, cancelados }

/// Barra Todos · En curso · Entregados · Cancelados.
class PedidosScopeBar extends StatelessWidget {
  const PedidosScopeBar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.filledStyle = false,
  });

  final PedidosListScope selected;
  final ValueChanged<PedidosListScope> onSelected;
  final bool filledStyle;

  @override
  Widget build(BuildContext context) {
    const labels = ['Todos', 'En curso', 'Entregados', 'Cancelados'];
    if (filledStyle) {
      return _filled(context, labels);
    }
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth < 320 ||
              MediaQuery.textScalerOf(context).scale(12) > 17
          ? 2
          : 4;
      return Wrap(children: [
        for (var i = 0; i < labels.length; i++)
          SizedBox(
              width: constraints.maxWidth / columns,
              child: Semantics(
                selected: selected.index == i,
                button: true,
                child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelected(PedidosListScope.values[i]),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 10),
                        decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                          width: selected.index == i ? 2 : 1,
                          color: selected.index == i
                              ? Theme.of(context).colorScheme.primary
                              : AppColors.borderSubtle,
                        ))),
                        child: Text(labels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected.index == i
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected.index == i
                                  ? Theme.of(context).colorScheme.primary
                                  : AppColors.textSecondary,
                            )),
                      ),
                    )),
              )),
      ]);
    });
  }

  Widget _filled(BuildContext context, List<String> labels) {
    final colors = OrderListColors.of(context);
    const icons = [
      Icons.receipt_long_outlined,
      Icons.local_shipping_outlined,
      Icons.check_circle_outline,
      Icons.block_outlined
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 520;
      final largeText = MediaQuery.textScalerOf(context).scale(12) > 17;
      final columns = largeText ? 2 : 4;
      return Wrap(spacing: 4, runSpacing: 4, children: [
        for (var i = 0; i < labels.length; i++)
          SizedBox(
              width: narrow || largeText
                  ? (constraints.maxWidth - (columns - 1) * 4) / columns
                  : null,
              child: Semantics(
                button: true,
                selected: selected.index == i,
                child: Material(
                  color: selected.index == i
                      ? colors.accent.withOpacity(.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => onSelected(PedidosListScope.values[i]),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: EdgeInsets.symmetric(
                          horizontal: narrow ? 4 : 14, vertical: 10),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!narrow) ...[
                              Icon(icons[i],
                                  size: 17,
                                  color: selected.index == i
                                      ? colors.accent
                                      : colors.secondary),
                              const SizedBox(width: 7),
                            ],
                            Flexible(
                                child: Text(labels[i],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: selected.index == i
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected.index == i
                                            ? colors.accent
                                            : colors.secondary))),
                          ]),
                    ),
                  ),
                ),
              )),
      ]);
    });
  }
}
