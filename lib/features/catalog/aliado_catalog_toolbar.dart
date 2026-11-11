import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

import 'aliado_catalog_quick_filters.dart';
import 'catalog_sort_mode.dart';

/// Bloque bajo el encabezado branded: título, chips y meta de resultados/orden.
class AliadoCatalogToolbar extends StatelessWidget {
  const AliadoCatalogToolbar({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
    required this.resultCount,
    required this.sortMode,
    required this.onSortTap,
    this.brandChip,
  });

  final AliadoCatalogQuickFilter selectedFilter;
  final ValueChanged<AliadoCatalogQuickFilter> onFilterSelected;
  final int resultCount;
  final CatalogSortMode sortMode;
  final VoidCallback onSortTap;
  final Widget? brandChip;

  static const _titleColor = Color(0xFF000000);
  static const _metaColor = Color(0xFF000010);

  @override
  Widget build(BuildContext context) {
    final countLabel =
        '$resultCount ${resultCount == 1 ? 'repuesto' : 'repuestos'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Catálogo de repuestos',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.15,
            color: _titleColor,
          ),
        ),
        const SizedBox(height: 14),
        AliadoCatalogQuickFilters(
          selected: selectedFilter,
          onSelected: onFilterSelected,
        ),
        if (brandChip != null) ...[
          const SizedBox(height: 8),
          brandChip!,
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: onSortTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    color: _metaColor,
                  ),
                  children: [
                    TextSpan(text: countLabel),
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: sortMode.compactLabelEs,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: ' ↓'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<CatalogSortMode?> showAliadoCatalogSortSheet({
  required BuildContext context,
  required CatalogSortMode selected,
}) {
  return showModalBottomSheet<CatalogSortMode>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ordenar por', style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final mode in CatalogSortMode.values)
              ListTile(
                selected: mode == selected,
                leading: Icon(mode.iconData,
                    color: mode == selected
                        ? AppColors.brandBlue
                        : AppColors.textSecondary),
                title: Text(mode.compactLabelEs),
                subtitle: Text(mode.subtitleEs, maxLines: 2),
                trailing: mode == selected
                    ? const LucideIcon(LucideGlyph.circleCheck,
                        color: AppColors.brandBlue)
                    : null,
                onTap: () => Navigator.pop(sheet, mode),
              ),
          ],
        ),
      ),
    ),
  );
}
