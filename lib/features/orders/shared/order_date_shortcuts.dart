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

  static DateTime _day(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static OrderDateShortcut active(DateTime? from, DateTime? to) {
    if (from == null && to == null) return OrderDateShortcut.all;
    if (from == null || to == null) return OrderDateShortcut.custom;
    final start = _day(from);
    final end = _day(to);
    final today = _day(DateTime.now());
    if (start == today && end == today) return OrderDateShortcut.today;
    if (end == today && start == today.subtract(const Duration(days: 6))) {
      return OrderDateShortcut.days7;
    }
    if (end == today && start == today.subtract(const Duration(days: 29))) {
      return OrderDateShortcut.days30;
    }
    return OrderDateShortcut.custom;
  }

  void _apply(OrderDateShortcut shortcut) {
    final today = _day(DateTime.now());
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

  @override
  Widget build(BuildContext context) {
    final current = active(from, to);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('Todas', OrderDateShortcut.all, current),
          _chip('Hoy', OrderDateShortcut.today, current),
          _chip('7 días', OrderDateShortcut.days7, current),
          _chip('30 días', OrderDateShortcut.days30, current),
          _chip(
            current == OrderDateShortcut.custom ? 'Fechas ✓' : 'Fechas',
            OrderDateShortcut.custom,
            current,
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, OrderDateShortcut shortcut, OrderDateShortcut current) {
    final selected = shortcut == current;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => _apply(shortcut),
        visualDensity: VisualDensity.compact,
        selectedColor: AppColors.brand.withOpacity(0.16),
        checkmarkColor: AppColors.brand,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: selected ? AppColors.brand : AppColors.textSecondary,
        ),
      ),
    );
  }
}
