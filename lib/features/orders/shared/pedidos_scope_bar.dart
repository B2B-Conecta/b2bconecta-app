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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.brandBlueContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              _item('Todos', PedidosListScope.todos),
              _item('En curso', PedidosListScope.enCurso),
              _item('Entregados', PedidosListScope.entregados),
              _item('Cancelados', PedidosListScope.cancelados),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(String label, PedidosListScope value) {
    final isSelected = selected == value;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: isSelected ? AppColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => onSelected(value),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.brand,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
