/// Rol B2B para el dashboard principal tras completar el perfil.
enum AppHomeRole {
  /// Catálogo y operación orientada a stock / importación.
  importador,

  /// Vista de aliado (taller, etc.).
  aliado,

  /// Broker MotoLink: bandeja de aprobación.
  administrador,

  /// Despacho / cobro en ruta (pedidos activos, respaldo efectivo).
  transportista,
}
