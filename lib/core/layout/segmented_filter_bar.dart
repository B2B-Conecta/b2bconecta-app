import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';

/// Barra de una sola opción, igual que el filtro de pedidos.
class SegmentedFilterBar extends StatelessWidget {
  const SegmentedFilterBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.brandContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 420;
              if (narrow) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _SegmentChip(
                            label: labels[i],
                            selected: selectedIndex == i,
                            onTap: () => onSelected(i),
                            expanded: false,
                          ),
                        ),
                    ],
                  ),
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _SegmentChip(
                          label: labels[i],
                          selected: selectedIndex == i,
                          onTap: () => onSelected(i),
                          expanded: true,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.expanded,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: selected ? theme.brand : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: AppBreakpoints.minTouchTarget,
            minWidth: expanded ? 0 : 88,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: selected ? theme.surfaceCard : theme.brand,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
