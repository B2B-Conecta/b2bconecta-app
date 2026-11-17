import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Encabezado del shell de escritorio mientras el detalle de un pedido está abierto.
///
/// Solo lo publica el panel importador en viewports de escritorio. El shell móvil
/// no escucha este notificador.
class ImporterOrderDetailChrome extends ChangeNotifier {
  ImporterOrderDetailChrome._();

  static final ImporterOrderDetailChrome instance =
      ImporterOrderDetailChrome._();

  String? _reference;
  String? _status;
  VoidCallback? _onClose;

  String? get reference => _reference;
  String? get statusLabel => _status;
  bool get active => _reference != null;

  void publish({
    required String reference,
    required String statusLabel,
    required VoidCallback onClose,
  }) {
    final changed = _reference != reference || _status != statusLabel;
    _reference = reference;
    _status = statusLabel;
    _onClose = onClose;
    if (changed) notifyListeners();
  }

  void close() => _onClose?.call();

  void release(VoidCallback onClose) {
    if (_onClose != onClose) return;
    _reference = null;
    _status = null;
    _onClose = null;
    // dispose corre con el árbol bloqueado (finalizeTree). Avisar en el
    // siguiente frame evita setState() during lock en el encabezado.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
}
