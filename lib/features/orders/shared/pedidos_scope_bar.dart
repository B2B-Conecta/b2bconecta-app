import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/widgets/segmented_filter_bar.dart';

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
    return SegmentedFilterBar(
      labels: const ['Todos', 'En curso', 'Entregados', 'Cancelados'],
      selectedIndex: selected.index,
      onSelected: (index) => onSelected(PedidosListScope.values[index]),
    );
  }
}
