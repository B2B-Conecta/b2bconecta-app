import 'package:flutter/material.dart';

import 'lucide_icon.dart';

class AliadoHeaderSearch extends StatelessWidget {
  const AliadoHeaderSearch({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSearch,
    required this.onFilters,
    this.autofocus = false,
    this.filterCount = 0,
    this.searchLabel = 'Buscar en el catálogo',
    this.filterLabel = 'Filtros del catálogo',
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSearch;
  final VoidCallback onFilters;
  final bool autofocus;
  final int filterCount;
  final String searchLabel;
  final String filterLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted =
        dark ? theme.colorScheme.onSurfaceVariant : const Color(0xFF64748B);

    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSearch(),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: muted, fontSize: 14),
          prefixIcon: IconButton(
            tooltip: searchLabel,
            onPressed: onSearch,
            icon: LucideIcon(LucideGlyph.search, size: 19, color: muted),
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: filterCount == 0
                  ? filterLabel
                  : '$filterLabel ($filterCount activos)',
              onPressed: onFilters,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(44),
                padding: EdgeInsets.zero,
                foregroundColor: const Color(0xFF245DE6),
              ),
              icon: Badge(
                isLabelVisible: filterCount > 0,
                label: Text('$filterCount'),
                child: const SizedBox.square(
                  dimension: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF245DE6),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: LucideIcon(LucideGlyph.slidersHorizontal,
                          size: 17, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
          filled: true,
          fillColor: dark ? theme.colorScheme.surface : Colors.white,
          border: outline,
          enabledBorder: outline,
          focusedBorder: outline.copyWith(
            borderSide: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
