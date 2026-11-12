/// Anchos de referencia para layouts adaptativos (web / tablet / móvil).
abstract final class AppBreakpoints {
  /// Cajón deslizable / hamburguesa: por debajo se oculta el rail fijo.
  static const double mobileMenu = 768;

  /// Área táctil mínima (Material / accesibilidad).
  static const double minTouchTarget = 48;

  /// Layouts de contenido “escritorio” (hubs, sheets, formularios anchos).
  static const double adminDesktop = 900;

  /// Aliado / importador: mismo umbral de contenido ancho.
  static const double b2bDesktop = adminDesktop;

  /// NavigationRail extendido con etiquetas largas.
  static const double adminRailExtended = 1180;

  /// Alias compartido rail extendido (admin + B2B).
  static const double desktopRailExtended = adminRailExtended;

  /// Ancho máximo del contenido admin centrado.
  static const double adminContentMaxWidth = 1440;

  /// Formularios (perfil) legibles en pantalla ancha.
  static const double formMaxWidth = 720;

  /// Login / registro: layout de dos columnas en escritorio.
  static const double authDesktop = 840;

  /// Ancho máximo del formulario de auth (login, registro).
  static const double authFormMaxWidth = 420;

  /// Ficha de producto aliado en escritorio.
  static const double productDetailMaxWidth = 1280;

  /// Umbral para ficha de producto en dos columnas (imagen | compra).
  static const double productDetailDesktop = 860;
}
