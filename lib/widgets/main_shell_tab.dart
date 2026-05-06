import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Permite cambiar la pestaña del [MainShell] desde hijos o rutas apiladas
/// (p. ej. importador → tab Pedidos tras marcar en preparación).
class MainShellTabController {
  MainShellTabController._();

  static void Function(int index)? _goTo;
  static VoidCallback? _refreshImporterInventory;
  static VoidCallback? _refreshImporterPedidos;
  static String? _pendingNotificationRelatedId;
  static VoidCallback? _pedidosNotificationDeepLink;
  static VoidCallback? _importadorValidadosNotificationDeepLink;
  static VoidCallback? _adminActivosNotificationDeepLink;
  static int? _b2bProfileTabIndex;
  static bool _importerPedidosPreferNuevosFilter = false;
  static VoidCallback? _adminCreditoKycNotificationDeepLink;
  static VoidCallback? _notificationsReload;
  static GlobalKey? _kycDocumentationSectionKey;

  /// Registrado por [MainShell] en [initState]; [unregister] en [dispose].
  static void register(void Function(int index) goTo) => _goTo = goTo;

  static void unregister() {
    _goTo = null;
    _refreshImporterPedidos = null;
    _pendingNotificationRelatedId = null;
    _pedidosNotificationDeepLink = null;
    _importadorValidadosNotificationDeepLink = null;
    _adminActivosNotificationDeepLink = null;
    _b2bProfileTabIndex = null;
    _importerPedidosPreferNuevosFilter = false;
    _adminCreditoKycNotificationDeepLink = null;
    _notificationsReload = null;
    _kycDocumentationSectionKey = null;
  }

  /// [ImporterInventoryDashboard] registra [reload] para refrescar stock tras entrega.
  static void registerImporterInventoryReload(VoidCallback? reload) {
    _refreshImporterInventory = reload;
  }

  static void notifyImporterInventoryReload() =>
      _refreshImporterInventory?.call();

  /// [ImporterActiveOrdersPanel] registra [reload] al entrar en la pestaña Pedidos o tras avances.
  static void registerImporterPedidosReload(VoidCallback? reload) {
    _refreshImporterPedidos = reload;
  }

  static void notifyImporterPedidosReload() => _refreshImporterPedidos?.call();

  /// Importador y aliado (3 pestañas): Perfil = 2.
  static void registerB2BProfileTabIndex(int index) => _b2bProfileTabIndex = index;

  static int get _resolvedB2BProfileTabIndex => _b2bProfileTabIndex ?? 2;

  /// Abrir listado importador en filtro «Nuevos» (p. ej. tras tocar notificación).
  static void setImporterPedidosPreferNuevosFilter(bool value) =>
      _importerPedidosPreferNuevosFilter = value;

  static bool consumeImporterPedidosPreferNuevosFilter() {
    final v = _importerPedidosPreferNuevosFilter;
    _importerPedidosPreferNuevosFilter = false;
    return v;
  }

  /// Índices: 0 Inventario/Catálogo, 1 Pedidos, 2 Perfil (importador/aliado).
  static void goTo(int index) => _goTo?.call(index);

  /// [AliadoPedidosPanel] / [ImporterActiveOrdersPanel] registran el expand tras deep link.
  static void registerPedidosNotificationDeepLink(VoidCallback? onNavigate) {
    _pedidosNotificationDeepLink = onNavigate;
  }

  /// Importador: deep link en pestaña Pedidos (filtro Nuevos) + expande fila.
  static void registerImportadorValidadosNotificationDeepLink(
      VoidCallback? onNavigate) {
    _importadorValidadosNotificationDeepLink = onNavigate;
  }

  /// Importador: pestaña Pedidos (índice 1), filtro Nuevos + expande fila.
  static void navigateToImportadorValidadosForNotification() {
    _importerPedidosPreferNuevosFilter = true;
    _goTo?.call(1);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _importadorValidadosNotificationDeepLink?.call();
    });
  }

  /// [AdminActiveOrdersPanel] expande el pedido del chat tras deep link.
  static void registerAdminActivosNotificationDeepLink(
      VoidCallback? onNavigate) {
    _adminActivosNotificationDeepLink = onNavigate;
  }

  /// [AdminAliadosCreditPanel] expande la fila del aliado en Límites de crédito (KYC).
  static void registerAdminCreditoKycNotificationDeepLink(
      VoidCallback? onNavigate) {
    _adminCreditoKycNotificationDeepLink = onNavigate;
  }

  /// Pestaña Pedidos (índice 1) + expande pedido vinculado a la notificación [mensaje].
  static void navigateToPedidosForNotification() {
    _goTo?.call(1);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pedidosNotificationDeepLink?.call();
    });
  }

  /// Admin: pestaña Activos (índice 0) + expande el pedido del chat.
  static void navigateToAdminActivosForNotification() {
    _goTo?.call(0);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminActivosNotificationDeepLink?.call();
    });
  }

  /// [ProfileB2BForm] (aliado) ancla la sección de documentación para deep links.
  static void registerKycDocumentationSectionKey(GlobalKey? key) {
    _kycDocumentationSectionKey = key;
  }

  /// Pestaña Perfil: scroll a documentación KYC del aliado/importador.
  static void navigateToProfileKycDocumentation() {
    _goTo?.call(_resolvedB2BProfileTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        final ctx = _kycDocumentationSectionKey?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            alignment: 0.12,
          );
        }
      });
    });
  }

  /// Admin: pestaña Crédito (índice 2) donde se revisa KYC / cupos de aliados.
  static void navigateToAdminCreditoForKycNotification() {
    _goTo?.call(2);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminCreditoKycNotificationDeepLink?.call();
    });
  }

  /// Guarda `related_id` de una notificación para que la vista destino lo consuma.
  static void setPendingNotificationRelatedId(String? relatedId) {
    final s = relatedId?.trim();
    _pendingNotificationRelatedId = (s == null || s.isEmpty) ? null : s;
  }

  /// `related_id` pendiente sin consumir (p. ej. esperar a que carguen los pedidos).
  static String? peekPendingNotificationRelatedId() {
    final s = _pendingNotificationRelatedId?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  /// Lee y limpia el `related_id` pendiente de deep link in-app.
  static String? consumePendingNotificationRelatedId() {
    final v = _pendingNotificationRelatedId;
    _pendingNotificationRelatedId = null;
    return v;
  }

  /// [MainShell] registra recarga del centro de notificaciones (p. ej. al abrir el chat).
  static void registerNotificationsReload(VoidCallback? reload) {
    _notificationsReload = reload;
  }

  static void requestNotificationsReload() => _notificationsReload?.call();
}
