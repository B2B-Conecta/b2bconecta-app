import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
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

/// Chips «Bajo crédito» y «Cambio de producto» para la fila de filtros.
List<Widget> orderSignalFilterChips({
  required bool creditOnly,
  required bool replacementOnly,
  required ValueChanged<bool> onCreditChanged,
  required ValueChanged<bool> onReplacementChanged,
}) {
  Widget chip({
    required String label,
    required IconData icon,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: AppColors.brand.withOpacity(0.16),
      checkmarkColor: AppColors.brand,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: selected ? AppColors.brand : AppColors.textSecondary,
      ),
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? AppColors.brand : AppColors.textSecondary,
      ),
    );
  }

  return [
    chip(
      label: 'Bajo crédito',
      icon: Icons.account_balance_wallet_outlined,
      selected: creditOnly,
      onSelected: onCreditChanged,
    ),
    chip(
      label: 'Cambio de producto',
      icon: Icons.swap_horiz,
      selected: replacementOnly,
      onSelected: onReplacementChanged,
    ),
  ];
}
