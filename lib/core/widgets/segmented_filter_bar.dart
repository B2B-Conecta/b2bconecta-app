import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';

/// Barra de una sola elección: fondo de marca suave y tramo activo en brand.
/// En pantallas angostas hace scroll horizontal para evitar overflow.
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
    final narrow = MediaQuery.sizeOf(context).width < 420;
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
          child: narrow
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < labels.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _Segment(
                            label: labels[i],
                            selected: i == selectedIndex,
                            narrow: true,
                            expanded: false,
                            onTap: () => onSelected(i),
                          ),
                        ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _Segment(
                            label: labels[i],
                            selected: i == selectedIndex,
                            narrow: false,
                            expanded: true,
                            onTap: () => onSelected(i),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.narrow,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool narrow;
  final bool expanded;
  final VoidCallback onTap;

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
            padding: EdgeInsets.symmetric(
              horizontal: narrow ? 10 : 4,
              vertical: 8,
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: narrow ? 11 : 12.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? theme.surfaceCard : theme.brand,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
