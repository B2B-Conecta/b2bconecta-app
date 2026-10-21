import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Atajos de la vitrina aliado. Una sola opción activa a la vez.
enum AliadoCatalogQuickFilter {
  all,
  usdPromo,
  shippingIncluded,
  topReputation,
}

extension AliadoCatalogQuickFilterLabel on AliadoCatalogQuickFilter {
  String get labelEs {
    switch (this) {
      case AliadoCatalogQuickFilter.all:
        return 'Todos';
      case AliadoCatalogQuickFilter.usdPromo:
        return 'Promociones USD';
      case AliadoCatalogQuickFilter.shippingIncluded:
        return 'Envío incluido';
      case AliadoCatalogQuickFilter.topReputation:
        return 'Mayor reputación';
    }
  }

  IconData? get icon {
    switch (this) {
      case AliadoCatalogQuickFilter.all:
        return null;
      case AliadoCatalogQuickFilter.usdPromo:
        return Icons.sell_outlined;
      case AliadoCatalogQuickFilter.shippingIncluded:
        return Icons.local_shipping_outlined;
      case AliadoCatalogQuickFilter.topReputation:
        return Icons.star_rounded;
    }
  }
}

/// Chips horizontales bajo el buscador. Sin barra de scroll visible.
class AliadoCatalogQuickFilters extends StatelessWidget {
  const AliadoCatalogQuickFilters({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AliadoCatalogQuickFilter selected;
  final ValueChanged<AliadoCatalogQuickFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final border = AppColors.brightness == Brightness.dark
        ? AppColors.borderSubtle
        : const Color(0xFFE2E8F0);
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        primary: false,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final filter in AliadoCatalogQuickFilter.values) ...[
              if (filter != AliadoCatalogQuickFilter.values.first)
                const SizedBox(width: 8),
              _QuickFilterChip(
                filter: filter,
                selected: filter == selected,
                borderColor: border,
                onTap: () => onSelected(filter),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.filter,
    required this.selected,
    required this.borderColor,
    required this.onTap,
  });

  final AliadoCatalogQuickFilter filter;
  final bool selected;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.white : AppColors.textPrimary;
    final icon = filter.icon;
    return Material(
      color: selected ? AppColors.brand : AppColors.card,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.brand : borderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                filter.labelEs,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
