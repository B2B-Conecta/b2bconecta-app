import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/widgets/segmented_filter_bar.dart';

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
    return OrderDateShortcutBar(
      from: from,
      to: to,
      onChanged: onChanged,
      onPickRange: onPickRange,
    );
  }
}

/// Todas · Hoy · 7 días · 30 días · Fechas, con la barra azul de Pedidos.
class OrderDateShortcutBar extends StatelessWidget {
  const OrderDateShortcutBar({
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

  @override
  Widget build(BuildContext context) {
    final current = OrderDateShortcuts.active(from, to);
    return SegmentedFilterBar(
      labels: const ['Todas', 'Hoy', '7 días', '30 días', 'Fechas'],
      selectedIndex: current.index,
      onSelected: (index) => _apply(OrderDateShortcut.values[index]),
    );
  }

  void _apply(OrderDateShortcut shortcut) {
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
}

