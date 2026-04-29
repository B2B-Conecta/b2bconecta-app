/// Estados logísticos de `sub_orders` (multi-importador).
abstract final class SubOrderStatus {
  static const pendiente = 'pendiente';
  static const preparando = 'preparando';
  static const listo = 'listo';
  static const enRuta = 'en_ruta';
  static const entregado = 'entregado';

  static String labelEs(String status) {
    switch (status) {
      case pendiente:
        return 'Pendiente';
      case preparando:
        return 'Preparando';
      case listo:
        return 'Listo';
      case enRuta:
        return 'En ruta';
      case entregado:
        return 'Entregado';
      default:
        return status;
    }
  }
}
