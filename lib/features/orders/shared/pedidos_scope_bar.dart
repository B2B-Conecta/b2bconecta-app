import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Vista de la lista de pedidos, igual para tienda, proveedor y administrador.
enum PedidosListScope { todos, enCurso, entregados, cancelados }

/// Barra Todos · En curso · Entregados · Cancelados.
class PedidosScopeBar extends StatelessWidget {
  const PedidosScopeBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final PedidosListScope selected;
  final ValueChanged<PedidosListScope> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['Todos', 'En curso', 'Entregados', 'Cancelados'];
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
}
