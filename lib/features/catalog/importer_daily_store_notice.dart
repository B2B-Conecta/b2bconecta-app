/// Aviso del primer ingreso del día del importador.
///
/// El texto oficial solo se arma si el conteo es un entero mayor que cero.
/// Un fallo o un cero no producen el banner.
class ImporterDailyStoreNotice {
  const ImporterDailyStoreNotice({
    required this.show,
    this.storeCount,
  });

  final bool show;
  final int? storeCount;

  static const officialTemplate = 'Ya hay {cantidad} tiendas activas en B2B Conecta.';

  String? get message {
    final count = storeCount;
    if (!show || count == null || count <= 0) return null;
    return officialTemplate.replaceFirst('{cantidad}', '$count');
  }

  factory ImporterDailyStoreNotice.fromRpc(Map<String, dynamic> json) {
    final raw = json['store_count'];
    int? count;
    if (raw is int) {
      count = raw;
    } else if (raw is num) {
      count = raw.toInt();
    } else if (raw != null) {
      count = int.tryParse(raw.toString());
    }
    final serverShow = json['show'] == true;
    return ImporterDailyStoreNotice.decide(
      failed: false,
      serverSaysShow: serverShow,
      storeCount: count,
    );
  }

  /// Regla de presentación. [failed] o un conteo nulo/cero ocultan el aviso.
  factory ImporterDailyStoreNotice.decide({
    required bool failed,
    required bool serverSaysShow,
    required int? storeCount,
  }) {
    if (failed || !serverSaysShow) {
      return const ImporterDailyStoreNotice(show: false);
    }
    if (storeCount == null || storeCount <= 0) {
      return const ImporterDailyStoreNotice(show: false);
    }
    return ImporterDailyStoreNotice(show: true, storeCount: storeCount);
  }
}
