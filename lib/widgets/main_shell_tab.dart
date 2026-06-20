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
  static VoidCallback? _adminPedidosBandejaNotificationHandler;
  static AdminPedidosNotificationScope? _pendingAdminPedidosScope;
  static int? _b2bProfileTabIndex;
  static bool _importerPedidosPreferNuevosFilter = false;
  static bool _importerPedidosPreferEnProcesoFilter = false;
  static bool _importerPedidosPreferCerradosFilter = false;
  static String? _pendingNotificationType;
  static VoidCallback? _notificationsReload;
  static GlobalKey? _kycDocumentationSectionKey;
  static String? _pendingCommissionSettlementId;
  static VoidCallback? _adminCommissionSettlementDeepLink;
  static VoidCallback? _importerCommissionSettlementDeepLink;
  static String? _pendingKycProfileId;
  static VoidCallback? _adminKycNotificationDeepLink;
  static String? _pendingSupportTicketId;
  static VoidCallback? _adminSupportNotificationDeepLink;
  static VoidCallback? _b2bSupportNotificationDeepLink;

  /// Registrado por [MainShell] en [initState]; [unregister] en [dispose].
  static void register(void Function(int index) goTo) => _goTo = goTo;

  static void unregister() {
    _goTo = null;
    _refreshImporterPedidos = null;
    _pendingNotificationRelatedId = null;
    _pedidosNotificationDeepLink = null;
    _importadorValidadosNotificationDeepLink = null;
    _adminPedidosBandejaNotificationHandler = null;
    _pendingAdminPedidosScope = null;
    _b2bProfileTabIndex = null;
    _importerPedidosPreferNuevosFilter = false;
    _importerPedidosPreferEnProcesoFilter = false;
    _importerPedidosPreferCerradosFilter = false;
    _pendingNotificationType = null;
    _notificationsReload = null;
    _kycDocumentationSectionKey = null;
    _pendingCommissionSettlementId = null;
    _adminCommissionSettlementDeepLink = null;
    _importerCommissionSettlementDeepLink = null;
    _pendingKycProfileId = null;
    _adminKycNotificationDeepLink = null;
    _pendingSupportTicketId = null;
    _adminSupportNotificationDeepLink = null;
    _b2bSupportNotificationDeepLink = null;
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

  /// Importador y aliado (4 pestañas): Perfil = 3, Reputación = 2.
  static void registerB2BProfileTabIndex(int index) =>
      _b2bProfileTabIndex = index;

  static int get _resolvedB2BProfileTabIndex => _b2bProfileTabIndex ?? 3;

  /// Pestaña Reputación (índice 2) — E2 panel dedicado.
  static void navigateToReputationTab() {
    _goTo?.call(2);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      requestNotificationsReload();
    });
  }

  /// Abrir listado importador en filtro «Nuevos» (p. ej. tras tocar notificación).
  static void setImporterPedidosPreferNuevosFilter(bool value) {
    _importerPedidosPreferNuevosFilter = value;
    if (value) {
      _importerPedidosPreferEnProcesoFilter = false;
      _importerPedidosPreferCerradosFilter = false;
    }
  }

  static bool consumeImporterPedidosPreferNuevosFilter() {
    final v = _importerPedidosPreferNuevosFilter;
    _importerPedidosPreferNuevosFilter = false;
    return v;
  }

  static void setImporterPedidosPreferEnProcesoFilter() {
    _importerPedidosPreferEnProcesoFilter = true;
    _importerPedidosPreferNuevosFilter = false;
    _importerPedidosPreferCerradosFilter = false;
  }

  static bool consumeImporterPedidosPreferEnProcesoFilter() {
    final v = _importerPedidosPreferEnProcesoFilter;
    _importerPedidosPreferEnProcesoFilter = false;
    return v;
  }

  static void setPendingImporterPedidosPreferCerradosFilter() {
    _importerPedidosPreferCerradosFilter = true;
    _importerPedidosPreferNuevosFilter = false;
    _importerPedidosPreferEnProcesoFilter = false;
  }

  static bool consumeImporterPedidosPreferCerradosFilter() {
    final v = _importerPedidosPreferCerradosFilter;
    _importerPedidosPreferCerradosFilter = false;
    return v;
  }

  static void setPendingNotificationType(String? type) {
    final s = type?.trim();
    _pendingNotificationType = (s == null || s.isEmpty) ? null : s;
  }

  static String? peekPendingNotificationType() {
    final s = _pendingNotificationType?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static String? consumePendingNotificationType() {
    final v = _pendingNotificationType;
    _pendingNotificationType = null;
    final s = v?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  /// Índices: 0 Inventario/Catálogo, 1 Pedidos, 2 Reputación, 3 Perfil.
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

  /// Importador: pestaña Inventario (índice 0) tras notificación de campaña promocional.
  static void navigateToImporterInventoryForNotification() {
    _goTo?.call(0);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyImporterInventoryReload();
    });
  }

  /// Importador: pestaña Pedidos (índice 1), filtro Nuevos + expande fila.
  static void navigateToImportadorValidadosForNotification() {
    _importerPedidosPreferNuevosFilter = true;
    _goTo?.call(1);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _importadorValidadosNotificationDeepLink?.call();
    });
  }

  /// [AdminOrdersPanel] — scope + recarga + expand al abrir desde notificación.
  static void registerAdminPedidosBandejaNotificationHandler(
      VoidCallback? onNavigate) {
    _adminPedidosBandejaNotificationHandler = onNavigate;
  }

  /// Admin: pestaña Pedidos unificada (índice 0) + manejo de notificación in-app.
  static void navigateToAdminActivosForNotification() {
    _pendingAdminPedidosScope = AdminPedidosNotificationScope.enCurso;
    _goTo?.call(0);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminPedidosBandejaNotificationHandler?.call();
    });
  }

  /// Admin: misma pestaña Pedidos (índice 0), vista «Cerrados» + expand moroso.
  static void navigateToAdminCerradosForNotification() {
    _pendingAdminPedidosScope = AdminPedidosNotificationScope.cerrados;
    _goTo?.call(0);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminPedidosBandejaNotificationHandler?.call();
    });
  }

  /// Pestaña Pedidos (índice 1) + expande pedido vinculado a la notificación [mensaje].
  static void navigateToPedidosForNotification() {
    _goTo?.call(1);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pedidosNotificationDeepLink?.call();
    });
  }

  /// Lee y limpia el alcance de bandeja pendiente (notificación admin).
  static AdminPedidosNotificationScope? consumePendingAdminPedidosScope() {
    final v = _pendingAdminPedidosScope;
    _pendingAdminPedidosScope = null;
    return v;
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

  /// Admin: pestaña Verificación KYC (índice 4).
  static void navigateToAdminKycForNotification() {
    _goTo?.call(4);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminKycNotificationDeepLink?.call();
    });
  }

  /// Admin: pestaña Perfil (índice 6).
  static void navigateToAdminProfileTab() {
    _goTo?.call(6);
  }

  /// Admin: pestaña Comisiones (índice 3).
  static void navigateToAdminComisionesForNotification() {
    _goTo?.call(3);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminCommissionSettlementDeepLink?.call();
    });
  }

  /// Importador: Perfil + sección cortes de comisión.
  static void navigateToImporterCommissionSettlementsForNotification() {
    _goTo?.call(_resolvedB2BProfileTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _importerCommissionSettlementDeepLink?.call();
    });
  }

  static void registerAdminCommissionSettlementDeepLink(
      VoidCallback? onNavigate) {
    _adminCommissionSettlementDeepLink = onNavigate;
  }

  static void registerImporterCommissionSettlementDeepLink(
      VoidCallback? onNavigate) {
    _importerCommissionSettlementDeepLink = onNavigate;
  }

  static void setPendingCommissionSettlementId(String? id) {
    final s = id?.trim();
    _pendingCommissionSettlementId = (s == null || s.isEmpty) ? null : s;
  }

  static String? peekPendingCommissionSettlementId() {
    final s = _pendingCommissionSettlementId?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static String? consumePendingCommissionSettlementId() {
    final v = _pendingCommissionSettlementId;
    _pendingCommissionSettlementId = null;
    return v;
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

  static void registerAdminKycNotificationDeepLink(VoidCallback? onNavigate) {
    _adminKycNotificationDeepLink = onNavigate;
  }

  static void setPendingKycProfileId(String? profileId) {
    final s = profileId?.trim();
    _pendingKycProfileId = (s == null || s.isEmpty) ? null : s;
  }

  static String? peekPendingKycProfileId() {
    final s = _pendingKycProfileId?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static String? consumePendingKycProfileId() {
    final v = _pendingKycProfileId;
    _pendingKycProfileId = null;
    return v;
  }

  /// Admin: pestaña Soporte (índice 5).
  static void navigateToAdminSupportForNotification() {
    _goTo?.call(5);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminSupportNotificationDeepLink?.call();
    });
  }

  /// Aliado/importador: pantalla de soporte desde notificación (Perfil → soporte).
  static void navigateToSupportForNotification() {
    _goTo?.call(_resolvedB2BProfileTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _b2bSupportNotificationDeepLink?.call();
    });
  }

  static void registerAdminSupportNotificationDeepLink(VoidCallback? onNavigate) {
    _adminSupportNotificationDeepLink = onNavigate;
  }

  static void registerB2BSupportNotificationDeepLink(VoidCallback? onNavigate) {
    _b2bSupportNotificationDeepLink = onNavigate;
  }

  static void setPendingSupportTicketId(String? ticketId) {
    final s = ticketId?.trim();
    _pendingSupportTicketId = (s == null || s.isEmpty) ? null : s;
  }

  static String? peekPendingSupportTicketId() {
    final s = _pendingSupportTicketId?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static String? consumePendingSupportTicketId() {
    final v = _pendingSupportTicketId;
    _pendingSupportTicketId = null;
    return v;
  }

  static VoidCallback? peekB2BSupportNotificationHandler() =>
      _b2bSupportNotificationDeepLink;
}

/// Alcance de la bandeja admin al abrir desde una notificación in-app.
enum AdminPedidosNotificationScope {
  enCurso,
  cerrados,
}
