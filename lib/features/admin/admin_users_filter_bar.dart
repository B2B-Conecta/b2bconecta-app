import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/admin/admin_standard_filter_bar.dart';
import 'package:motolink_pro_app/features/admin/admin_users_filter_models.dart';
import 'package:motolink_pro_app/features/admin/owner_account_search.dart';

/// Barra limpia: búsqueda + Estado / Rol (+ orden), estándar Verificación.
class AdminUsersFilterBar extends StatelessWidget {
  const AdminUsersFilterBar({
    super.key,
    required this.searchController,
    required this.searchHint,
    required this.estado,
    required this.rol,
    required this.onEstado,
    required this.onRol,
    this.onSearchChanged,
    this.sort,
    this.onSort,
    this.includeAdminRol = false,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 0),
    this.extraMenus = const [],
  });

  final TextEditingController searchController;
  final String searchHint;
  final AdminUserEstadoFilter estado;
  final AdminUserRolFilter rol;
  final ValueChanged<AdminUserEstadoFilter> onEstado;
  final ValueChanged<AdminUserRolFilter> onRol;
  final ValueChanged<String>? onSearchChanged;
  final OwnerAccountSort? sort;
  final ValueChanged<OwnerAccountSort>? onSort;
  final bool includeAdminRol;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  /// Menús adicionales (p. ej. Vista Cuentas / Registro incompleto).
  final List<AdminFilterDropdown> extraMenus;

  List<AdminUserRolFilter> get _roles => [
        AdminUserRolFilter.todos,
        AdminUserRolFilter.minorista,
        AdminUserRolFilter.mayorista,
        if (includeAdminRol) AdminUserRolFilter.administracion,
      ];

  bool get _filtersActive =>
      estado != AdminUserEstadoFilter.todos ||
      rol != AdminUserRolFilter.todos ||
      (sort != null && sort != OwnerAccountSort.newest) ||
      extraMenus.any((m) => m.active);

  @override
  Widget build(BuildContext context) {
    final menus = <AdminFilterDropdown>[
      ...extraMenus,
      AdminFilterDropdown(
        icon: Icons.flag_outlined,
        placeholder: 'Estado',
        valueLabel: estado.labelEs,
        active: estado != AdminUserEstadoFilter.todos,
        options: [
          for (final e in AdminUserEstadoFilter.values)
            AdminFilterOption(
              label: e.labelEs,
              selected: estado == e,
              onSelect: () => onEstado(e),
            ),
        ],
      ),
      AdminFilterDropdown(
        icon: Icons.badge_outlined,
        placeholder: 'Rol',
        valueLabel: rol.labelEs,
        active: rol != AdminUserRolFilter.todos,
        options: [
          for (final r in _roles)
            AdminFilterOption(
              label: r.labelEs,
              selected: rol == r,
              onSelect: () => onRol(r),
            ),
        ],
      ),
      if (onSort != null && sort != null)
        AdminFilterDropdown(
          icon: Icons.sort,
          placeholder: 'Orden',
          valueLabel: sort!.labelEs,
          active: sort != OwnerAccountSort.newest,
          options: [
            for (final s in OwnerAccountSort.values)
              AdminFilterOption(
                label: s.labelEs,
                selected: sort == s,
                onSelect: () => onSort!(s),
              ),
          ],
        ),
    ];

    return AdminStandardFilterBar(
      searchController: searchController,
      searchHint: searchHint,
      onSearchChanged: onSearchChanged,
      menus: menus,
      clearVisible: _filtersActive || searchController.text.trim().isNotEmpty,
      onClear: () {
        if (searchController.text.isNotEmpty) {
          searchController.clear();
          onSearchChanged?.call('');
        }
        onEstado(AdminUserEstadoFilter.todos);
        onRol(AdminUserRolFilter.todos);
        onSort?.call(OwnerAccountSort.newest);
      },
      trailing: trailing,
      padding: padding,
    );
  }
}
