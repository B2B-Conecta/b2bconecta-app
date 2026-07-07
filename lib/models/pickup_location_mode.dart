/// Modo de punto de recolección confirmado por el importador.
abstract final class PickupLocationMode {
  static const warehouse = 'warehouse';
  static const carrierBase = 'carrier_base';
  static const alternate = 'alternate';

  static String labelEs(String? raw) => switch (raw?.trim()) {
        warehouse => 'Mi almacén',
        carrierBase => 'Base del transportista',
        alternate => 'Ubicación alterna',
        _ => '—',
      };
}
