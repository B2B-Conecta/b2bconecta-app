import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

enum OrderDateShortcut { all, today, days7, days30, custom }

/// Atajos de fecha para las listas de pedidos. El mismo criterio que en Chats.
class OrderDateShortcuts extends StatelessWidget {
  const OrderDateShortcuts({
    super.key,
    required this.from,
    required this.to,
    required this.onChanged,
    required this.onPickRange,
  });

  final DateTime? from;
  final DateTime? to;
  final void Function(DateTime? from, DateTime? to) onChanged;
  final VoidCallback onPickRange;

  static DateTime day(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static OrderDateShortcut active(DateTime? from, DateTime? to) {
    if (from == null && to == null) return OrderDateShortcut.all;
    if (from == null || to == null) return OrderDateShortcut.custom;
    final start = day(from);
    final end = day(to);
    final today = day(DateTime.now());
    if (start == today && end == today) return OrderDateShortcut.today;
    if (end == today && start == today.subtract(const Duration(days: 6))) {
      return OrderDateShortcut.days7;
    }
    if (end == today && start == today.subtract(const Duration(days: 29))) {
      return OrderDateShortcut.days30;
    }
    return OrderDateShortcut.custom;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: orderDateShortcutChips(
        from: from,
        to: to,
        onChanged: onChanged,
        onPickRange: onPickRange,
      ),
    );
  }
}

/// Atajos de fecha como chips sueltos, para la misma fila que el resto de filtros.
List<Widget> orderDateShortcutChips({
  required DateTime? from,
  required DateTime? to,
  required void Function(DateTime? from, DateTime? to) onChanged,
  required VoidCallback onPickRange,
}) {
  final current = OrderDateShortcuts.active(from, to);

  void apply(OrderDateShortcut shortcut) {
    final today = OrderDateShortcuts.day(DateTime.now());
    switch (shortcut) {
      case OrderDateShortcut.all:
        onChanged(null, null);
      case OrderDateShortcut.today:
        onChanged(today, today);
      case OrderDateShortcut.days7:
        onChanged(today.subtract(const Duration(days: 6)), today);
      case OrderDateShortcut.days30:
        onChanged(today.subtract(const Duration(days: 29)), today);
      case OrderDateShortcut.custom:
        onPickRange();
    }
  }

  Widget chip(String label, OrderDateShortcut shortcut) {
    final selected = shortcut == current;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => apply(shortcut),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: AppColors.brand.withOpacity(0.16),
      checkmarkColor: AppColors.brand,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: selected ? AppColors.brand : AppColors.textSecondary,
      ),
    );
  }

  return [
    chip('Todas', OrderDateShortcut.all),
    chip('Hoy', OrderDateShortcut.today),
    chip('7 días', OrderDateShortcut.days7),
    chip('30 días', OrderDateShortcut.days30),
    chip(
      current == OrderDateShortcut.custom ? 'Fechas ✓' : 'Fechas',
      OrderDateShortcut.custom,
    ),
  ];
}
