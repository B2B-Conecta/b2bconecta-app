/// Anchos de referencia para layouts adaptativos (web / tablet / móvil).
abstract final class AppBreakpoints {
  /// Admin en escritorio: barra lateral en lugar de bottom nav.
  static const double adminDesktop = 900;

  /// NavigationRail extendido con etiquetas largas.
  static const double adminRailExtended = 1180;

  /// Ancho máximo del contenido admin centrado.
  static const double adminContentMaxWidth = 1440;

  /// Formularios (perfil) legibles en pantalla ancha.
  static const double formMaxWidth = 720;
}
