/// Resumen admin: morosidad de pagos y suspensión de nuevos pedidos por aliado.
class AdminAliadoMorosidadFlag {
  const AdminAliadoMorosidadFlag({
    required this.tieneMorosos,
    required this.pedidosSuspendidosMorosidad,
  });

  final bool tieneMorosos;
  final bool pedidosSuspendidosMorosidad;
}
