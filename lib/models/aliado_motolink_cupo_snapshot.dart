/// Corte de datos del cupo (RPC `aliado_motolink_cupo_snapshot`): límite, imputado y
/// saldo activo coherentes; el saldo baja con cuotas aprobadas.
class AliadoMotoLinkCupoSnapshot {
  const AliadoMotoLinkCupoSnapshot({
    required this.limiteAsignado,
    required this.imputadoAcumulado,
    required this.saldoActivoExposicion,
  });

  final double limiteAsignado;
  final double imputadoAcumulado;
  final double saldoActivoExposicion;

  factory AliadoMotoLinkCupoSnapshot.fromRpcRow(Map<String, dynamic> row) {
    num n(String k) {
      final v = row[k];
      if (v is num) return v;
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }
    return AliadoMotoLinkCupoSnapshot(
      limiteAsignado: n('limite_asignado').toDouble(),
      imputadoAcumulado: n('imputado_acumulado').toDouble(),
      saldoActivoExposicion: n('saldo_activo_exposicion').toDouble(),
    );
  }
}
