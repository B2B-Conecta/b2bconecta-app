import 'package:flutter/foundation.dart';

/// Permite cambiar la pestaña del [MainShell] desde hijos o rutas apiladas
/// (p. ej. importador → tab Pedidos tras marcar en preparación).
class MainShellTabController {
  MainShellTabController._();

  static void Function(int index)? _goTo;
  static VoidCallback? _refreshImporterInventory;
  static VoidCallback? _refreshImporterPedidos;

  /// Registrado por [MainShell] en [initState]; [unregister] en [dispose].
  static void register(void Function(int index) goTo) => _goTo = goTo;

  static void unregister() {
    _goTo = null;
    _refreshImporterPedidos = null;
  }

  /// [ImporterInventoryDashboard] registra [reload] para refrescar stock tras entrega.
  static void registerImporterInventoryReload(VoidCallback? reload) {
    _refreshImporterInventory = reload;
  }

  static void notifyImporterInventoryReload() => _refreshImporterInventory?.call();

  /// [ImporterActiveOrdersPanel] registra [reload] al entrar en la pestaña Pedidos o tras avances.
  static void registerImporterPedidosReload(VoidCallback? reload) {
    _refreshImporterPedidos = reload;
  }

  static void notifyImporterPedidosReload() => _refreshImporterPedidos?.call();

  /// Índices: 0 Inventario/Catálogo, 1 Pedidos, 2 Bandeja/validados, 3 Perfil.
  static void goTo(int index) => _goTo?.call(index);
}
