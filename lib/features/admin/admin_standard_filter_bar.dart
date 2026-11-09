import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'package:motolink_pro_app/core/layout/filter_menu_button.dart';

/// Opción de un menú de filtro del estándar admin (como Verificación).
class AdminFilterOption {
  const AdminFilterOption({
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;
}

/// Menú desplegable de la barra estándar.
class AdminFilterDropdown {
  const AdminFilterDropdown({
    required this.icon,
    required this.placeholder,
    required this.valueLabel,
    required this.active,
    required this.options,
  });

  final IconData icon;
  final String placeholder;
  final String valueLabel;
  final bool active;
  final List<AdminFilterOption> options;

  String get buttonLabel => active ? valueLabel : placeholder;
}

/// Estándar UI Usuarios: búsqueda + menús desplegables (desktop) / sheet (móvil).
class AdminStandardFilterBar extends StatelessWidget {
  const AdminStandardFilterBar({
    super.key,
    required this.searchController,
    required this.searchHint,
    required this.menus,
    this.onSearchChanged,
    this.onClear,
    this.clearVisible = false,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  final TextEditingController searchController;
  final String searchHint;
  final List<AdminFilterDropdown> menus;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onClear;
  final bool clearVisible;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  Future<void> _openMobileFilters(BuildContext context) async {
    await showAdaptiveAdminSheet<void>(
      context: context,
      builder: (ctx, _) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                16 + MediaQuery.paddingOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Filtros',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  for (final menu in menus) ...[
                    const SizedBox(height: 14),
                    Text(
                      menu.placeholder,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final opt in menu.options)
                          ChoiceChip(
                            label: Text(opt.label),
                            selected: opt.selected,
                            onSelected: (_) {
                              opt.onSelect();
                              setLocal(() {});
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Listo'),
                  ),
                  if (clearVisible && onClear != null)
                    TextButton(
                      onPressed: () {
                        onClear!();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Limpiar filtros'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final anyActive = menus.any((m) => m.active) || clearVisible;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
              if (narrow && menus.isNotEmpty) ...[
                const SizedBox(width: 8),
                FilterPillButton(
                  icon: Icons.tune,
                  label: anyActive ? 'Filtros ·' : 'Filtros',
                  active: anyActive,
                  showChevron: false,
                  onTap: () => _openMobileFilters(context),
                ),
              ],
            ],
          ),
          if (!narrow && menus.isNotEmpty) ...[
            const SizedBox(height: 8),
            FilterToolbar(
              children: [
                for (final menu in menus)
                  FilterMenuButton(
                    icon: menu.icon,
                    label: menu.buttonLabel,
                    active: menu.active,
                    menuChildren: [
                      for (final opt in menu.options)
                        FilterMenuOption(
                          label: opt.label,
                          selected: opt.selected,
                          onPressed: opt.onSelect,
                        ),
                    ],
                  ),
                if (clearVisible && onClear != null)
                  TextButton(
                    onPressed: onClear,
                    child: const Text('Limpiar'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
