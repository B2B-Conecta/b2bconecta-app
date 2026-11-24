import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/aliado_shell_tabs.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/core/layout/aliado_bottom_nav.dart';

Color supplierPanelColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF192338)
        : const Color(0xFFEBEEF6);

Color supplierOutlineColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF485A77)
        : const Color(0xFFC4CDDE);

class SupplierCategoryPill extends StatelessWidget {
  const SupplierCategoryPill({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(.65),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: supplierOutlineColor(context))),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.2,
                  color: Theme.of(context).colorScheme.onSurface))));
}

class SupplierFilterChip extends StatelessWidget {
  const SupplierFilterChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onSelected});
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  @override
  Widget build(BuildContext context) => ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      shape: const StadiumBorder(),
      side: BorderSide(
          color: selected
              ? const Color(0xFF004BDD)
              : supplierOutlineColor(context)),
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: const Color(0xFF004BDD),
      labelPadding: const EdgeInsets.symmetric(horizontal: 7),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface));
}

class SupplierRating extends StatelessWidget {
  const SupplierRating({super.key, required this.average, required this.count});
  final double? average;
  final int? count;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (average == null || (count ?? 0) == 0) {
      return Text('Aún sin valoraciones',
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant));
    }
    return Wrap(
        spacing: 8,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded, size: 22, color: Color(0xFFF5A900)),
            const SizedBox(width: 3),
            Text(average!.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface))
          ]),
          Text('$count ${count == 1 ? 'valoración' : 'valoraciones'}',
              style: TextStyle(fontSize: 13.5, color: colors.onSurface))
        ]);
  }
}

/// La misma barra del Inicio; vuelve al shell antes de cambiar de módulo.
class SupplierMobileNavigation extends StatelessWidget {
  const SupplierMobileNavigation({super.key});
  @override
  Widget build(BuildContext context) => AliadoBottomNav(
      currentIndex: AliadoShellTabs.inicio,
      onTap: (index) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        MainShellTabController.navigateToAliadoTab(index);
      });
}
