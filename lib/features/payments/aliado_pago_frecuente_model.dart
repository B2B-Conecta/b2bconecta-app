/// Método de pago usado con frecuencia por un aliado con un importador.
class AliadoPagoFrecuenteModel {
  const AliadoPagoFrecuenteModel({
    required this.pagoMetodo,
    required this.useCount,
    this.lastUsedAt,
  });

  final String pagoMetodo;
  final int useCount;
  final DateTime? lastUsedAt;

  factory AliadoPagoFrecuenteModel.fromJson(Map<String, dynamic> json) {
    DateTime? last;
    final raw = json['last_used_at'];
    if (raw != null) {
      last = DateTime.tryParse(raw.toString());
    }
    int count = 0;
    final c = json['use_count'];
    if (c is int) {
      count = c;
    } else if (c is num) {
      count = c.toInt();
    }
    return AliadoPagoFrecuenteModel(
      pagoMetodo: json['pago_metodo']?.toString().trim() ?? '',
      useCount: count,
      lastUsedAt: last,
    );
  }
}
