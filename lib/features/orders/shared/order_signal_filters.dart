import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/widgets/segmented_filter_bar.dart';
import 'transaction_request_model.dart';

bool orderLineUsesStoreCredit(TransactionRequestModel line) =>
    line.creditoAplicadoMonto > 0;

bool orderLineHasProductChange(TransactionRequestModel line) =>
    line.postventaResolucion == 'cambio';

/// Conserva el carrito completo si alguna línea cumple el filtro activo.
List<List<TransactionRequestModel>> filterOrderGroupsBySignals(
  List<List<TransactionRequestModel>> groups, {
  required bool creditOnly,
  required bool replacementOnly,
}) {
  if (!creditOnly && !replacementOnly) return groups;
  return groups.where((group) {
    if (creditOnly && !group.any(orderLineUsesStoreCredit)) return false;
    if (replacementOnly && !group.any(orderLineHasProductChange)) {
      return false;
    }
    return true;
  }).toList();
}

/// Todos · Bajo crédito · Cambio de producto, una sola elección.
class OrderSignalFilterBar extends StatelessWidget {
  const OrderSignalFilterBar({
    super.key,
    required this.creditOnly,
    required this.replacementOnly,
    required this.onChanged,
  });

  final bool creditOnly;
  final bool replacementOnly;
  final void Function(bool credit, bool replacement) onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = creditOnly ? 1 : (replacementOnly ? 2 : 0);
    return SegmentedFilterBar(
      labels: const ['Todos', 'Bajo crédito', 'Cambio de producto'],
      selectedIndex: selected,
      onSelected: (index) => onChanged(index == 1, index == 2),
    );
  }
}
