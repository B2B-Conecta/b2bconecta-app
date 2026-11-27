import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/widgets/aliado_quick_filter.dart';
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

  @override
  Widget build(BuildContext context) => AliadoQuickFilterRow(children: [
        for (final filter in AliadoCatalogQuickFilter.values)
          AliadoQuickFilterChip(
            label: filter.labelEs,
            selected: filter == selected,
            onTap: () => onSelected(filter),
            icon: switch (filter.glyph) {
              final glyph? => LucideIcon(glyph, size: 14),
              null => null,
            },
          ),
      ]);
}
