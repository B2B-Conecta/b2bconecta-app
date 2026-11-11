import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

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

  LucideGlyph? get glyph {
    switch (this) {
      case AliadoCatalogQuickFilter.all:
        return null;
      case AliadoCatalogQuickFilter.usdPromo:
        return LucideGlyph.tag;
      case AliadoCatalogQuickFilter.shippingIncluded:
        return LucideGlyph.truck;
      case AliadoCatalogQuickFilter.topReputation:
        return LucideGlyph.star;
    }
  }
}

/// Chips horizontales bajo el título. Sin barra de scroll visible.
class AliadoCatalogQuickFilters extends StatelessWidget {
  const AliadoCatalogQuickFilters({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AliadoCatalogQuickFilter selected;
  final ValueChanged<AliadoCatalogQuickFilter> onSelected;

  static const _activeBlue = Color(0xFF004BDD);
  static const _idleFill = Color(0xFFF0F2F5);
  static const _idleText = Color(0xFF000010);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
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
                activeColor: dark ? AppColors.brandAccent : _activeBlue,
                idleFill: dark ? AppColors.surfaceTinted : _idleFill,
                idleText: dark ? AppColors.textPrimary : _idleText,
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
    required this.activeColor,
    required this.idleFill,
    required this.idleText,
    required this.onTap,
  });

  final AliadoCatalogQuickFilter filter;
  final bool selected;
  final Color activeColor;
  final Color idleFill;
  final Color idleText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.white : idleText;
    final glyph = filter.glyph;
    return Material(
      color: selected ? activeColor : idleFill,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph != null) ...[
                LucideIcon(glyph, size: 14, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                filter.labelEs,
                style: TextStyle(
                  fontSize: 13,
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
