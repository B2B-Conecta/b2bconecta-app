/// Estado simplificado para filtros del hub de usuarios.
enum AdminUserEstadoFilter {
  todos,
  pendiente,
  verificado,
  activo,
  bloqueado,
}

/// Rol simplificado (minorista / mayorista) para el hub de usuarios.
enum AdminUserRolFilter {
  todos,
  minorista,
  mayorista,
  administracion,
}

extension AdminUserEstadoFilterLabel on AdminUserEstadoFilter {
  String get labelEs => switch (this) {
        AdminUserEstadoFilter.todos => 'Todos',
        AdminUserEstadoFilter.pendiente => 'Pendiente',
        AdminUserEstadoFilter.verificado => 'Verificado',
        AdminUserEstadoFilter.activo => 'Activo',
        AdminUserEstadoFilter.bloqueado => 'Bloqueado',
      };
}

extension AdminUserRolFilterLabel on AdminUserRolFilter {
  String get labelEs => switch (this) {
        AdminUserRolFilter.todos => 'Todos',
        AdminUserRolFilter.minorista => 'Minorista',
        AdminUserRolFilter.mayorista => 'Mayorista',
        AdminUserRolFilter.administracion => 'Administración',
      };
}
