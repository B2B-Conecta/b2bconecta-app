import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:motolink_pro_app/app/aliado_shell_tabs.dart';
import 'importer_shell_tabs.dart';
import 'package:motolink_pro_app/features/admin/admin_reports_hub_section.dart';
import 'package:motolink_pro_app/features/admin/admin_users_hub_section.dart';
import '../features/catalog/catalog_filters.dart';
import '../features/catalog/promo_campaign_model.dart';

class AliadoCatalogRequest {
  const AliadoCatalogRequest(
      {this.filters = CatalogFilters.empty,
      this.campaign,
      this.openFilters = false});
  final CatalogFilters filters;
  final PromoCampaignModel? campaign;
  final bool openFilters;
}

/// Permite cambiar la pestaña del [MainShell] desde hijos o rutas apiladas
/// (p. ej. importador → tab Pedidos tras marcar en preparación).
class MainShellTabController {
  MainShellTabController._();

  static void Function(int index)? _goTo;
  static VoidCallback? _refreshImporterInventory;
  static VoidCallback? _refreshImporterHome;
  static VoidCallback? _openAliadoCatalog;
  static VoidCallback? _openReputation;
  static AliadoCatalogRequest? _catalogRequest;

  static void registerAliadoCatalog(VoidCallback? open) =>
      _openAliadoCatalog = open;

  static AliadoCatalogRequest? consumeAliadoCatalogRequest() {
    final request = _catalogRequest;
    _catalogRequest = null;
    return request;
  }

  static void navigateToAliadoCatalog({
    CatalogFilters filters = CatalogFilters.empty,
    PromoCampaignModel? campaign,
    bool openFilters = false,
  }) {
    _catalogRequest = AliadoCatalogRequest(
        filters: filters, campaign: campaign, openFilters: openFilters);
    _goTo?.call(AliadoShellTabs.catalogo);
    SchedulerBinding.instance
        .addPostFrameCallback((_) => _openAliadoCatalog?.call());
  }

  static final importerInventoryRequest = ValueNotifier<String?>(null);

  static void registerImporterHomeReload(VoidCallback? reload) =>
      _refreshImporterHome = reload;
  static void notifyImporterHomeReload() => _refreshImporterHome?.call();

  static VoidCallback? _refreshAliadoHome;
  static void registerAliadoHomeReload(VoidCallback? reload) =>
      _refreshAliadoHome = reload;
  static void notifyAliadoHomeReload() => _refreshAliadoHome?.call();
  static void navigateToImporterInventory({String? filter}) {
    _goTo?.call(ImporterShellTabs.inventario);
    importerInventoryRequest.value = filter ?? 'todos';
  }

  static VoidCallback? _refreshImporterPedidos;
  static String? _pendingNotificationRelatedId;
  static VoidCallback? _pedidosNotificationDeepLink;
  static VoidCallback? _importadorValidadosNotificationDeepLink;
  static VoidCallback? _adminPedidosBandejaNotificationHandler;
  static AdminPedidosNotificationScope? _pendingAdminPedidosScope;
  /// Admin Pedidos: activar chip «Por confirmar».
  static bool _pendingAdminPedidosPendingOnly = false;
  /// Admin Usuarios › Cuentas: chip «Por revisar».
  static bool _pendingUsersPendingReviewOnly = false;
  /// Admin Soporte: filtrar abiertos + en revisión (badge).
  static bool _pendingSupportAttentionOnly = false;
  /// Admin Devoluciones: solo casos `abierta`.
  static bool _pendingReturnsOpenOnly = false;
  static int _homeTabIndex = 0;
  static int _b2bPedidosTabIndex = 1;
  static int _b2bReputationTabIndex = 2;
  static int? _b2bProfileTabIndex;
  static bool _importerPedidosPreferNuevosFilter = false;
  static bool _importerPedidosPreferEnProcesoFilter = false;
  static bool _importerPedidosPreferCerradosFilter = false;
  static String? _pendingImporterPedidosExploreFilter;
  static String? _pendingImporterPedidosSearch;
  static String? _pendingImporterCatalogSearch;
  static String? _pendingNotificationType;
  static bool _pendingOpenOrderChat = false;
  static VoidCallback? _notificationsReload;
  static GlobalKey? _kycDocumentationSectionKey;
  static void Function(int index)? _aliadoProfileSubTab;
  static int _profileSubTabSerial = 0;
  static String? _pendingCommissionSettlementId;
  static VoidCallback? _adminCommissionSettlementDeepLink;
  static VoidCallback? _importerCommissionSettlementDeepLink;
  static bool _importerCommissionPreferPendiente = false;
  static String? _pendingKycProfileId;
  static VoidCallback? _adminKycNotificationDeepLink;
  static String? _pendingAccountProfileId;
  static VoidCallback? _adminAccountNotificationDeepLink;
  /// Filtro de alerta emprendedor (`pending_first_purchase_alert`, etc.).
  static String? _pendingEntrepreneurAlertFilter;
  static AdminUsersHubSection? _pendingAdminUsersSection;
  static VoidCallback? _adminUsersHubDeepLink;
  static AdminReportsHubSection? _pendingAdminReportsSection;
  static VoidCallback? _adminReportsHubDeepLink;
  static VoidCallback? _adminReturnsOpenOnlyDeepLink;
  static String? _pendingSupportTicketId;
  static VoidCallback? _adminSupportNotificationDeepLink;
  static VoidCallback? _b2bSupportNotificationDeepLink;

  /// Admin: Inicio (dashboard de métricas).
  static const int adminInicioTabIndex = 0;

  /// Admin: bandeja de Pedidos.
  static const int adminPedidosTabIndex = 1;

  /// Admin: Reportes y analíticas.
  static const int adminReportesTabIndex = 2;

  /// Admin: pestaña Comisiones.
  static const int adminComisionesTabIndex = 4;

  /// Admin: pestaña Usuarios (hub Cuentas · Actividad).
  static const int adminUsersTabIndex = 5;

  /// Admin: pestaña Soporte.
  static const int adminSupportTabIndex = 6;

  /// Admin: pestaña Perfil.
  static const int adminProfileTabIndexDefault = 7;

  /// Registrado por [MainShell] en [initState]; [unregister] en [dispose].
  static void register(void Function(int index) goTo) => _goTo = goTo;

  static ValueChanged<int>? _selectAliadoTab;
  static void registerAliadoTabSelection(ValueChanged<int> onSelect) => _selectAliadoTab = onSelect;

  /// Usa las mismas recargas de pedidos, favoritos y perfil que la barra del shell.
  static void navigateToAliadoTab(int index) => (_selectAliadoTab ?? _goTo)?.call(index);

  static void unregister() {
    _selectAliadoTab = null;
    _goTo = null;
    _refreshImporterInventory = null;
    _refreshImporterHome = null;
    _refreshAliadoHome = null;
    _openAliadoCatalog = null;
    _openReputation = null;
    _catalogRequest = null;
    importerInventoryRequest.value = null;
    _refreshImporterPedidos = null;
    _pendingNotificationRelatedId = null;
    _pedidosNotificationDeepLink = null;
    _importadorValidadosNotificationDeepLink = null;
    _adminPedidosBandejaNotificationHandler = null;
    _pendingAdminPedidosScope = null;
    _pendingAdminPedidosPendingOnly = false;
    _pendingUsersPendingReviewOnly = false;
    _pendingSupportAttentionOnly = false;
    _pendingReturnsOpenOnly = false;
    _homeTabIndex = 0;
    _b2bPedidosTabIndex = 1;
    _b2bReputationTabIndex = 2;
    _b2bProfileTabIndex = null;
    _importerPedidosPreferNuevosFilter = false;
    _importerPedidosPreferEnProcesoFilter = false;
    _importerPedidosPreferCerradosFilter = false;
    _pendingImporterPedidosExploreFilter = null;
    _pendingImporterPedidosSearch = null;
    _pendingImporterCatalogSearch = null;
    _pendingNotificationType = null;
    _pendingOpenOrderChat = false;
    _notificationsReload = null;
    _kycDocumentationSectionKey = null;
    _aliadoProfileSubTab = null;
    _pendingCommissionSettlementId = null;
    _adminCommissionSettlementDeepLink = null;
    _importerCommissionSettlementDeepLink = null;
    _importerCommissionPreferPendiente = false;
    _pendingKycProfileId = null;
    _adminKycNotificationDeepLink = null;
    _pendingAccountProfileId = null;
    _adminAccountNotificationDeepLink = null;
    _pendingEntrepreneurAlertFilter = null;
    _pendingAdminUsersSection = null;
    _adminUsersHubDeepLink = null;
    _pendingAdminReportsSection = null;
    _adminReportsHubDeepLink = null;
    _adminReturnsOpenOnlyDeepLink = null;
    _pendingSupportTicketId = null;
    _adminSupportNotificationDeepLink = null;
    _b2bSupportNotificationDeepLink = null;
    _adminProfileTabIndex = adminProfileTabIndexDefault;
  }

  /// [ImporterInventoryDashboard] registra [reload] para refrescar stock tras entrega.
  static void registerImporterInventoryReload(VoidCallback? reload) {
    _refreshImporterInventory = reload;
  }

  static void notifyImporterInventoryReload() =>
      _refreshImporterInventory?.call();

  /// [ImporterActiveOrdersPanel] / [AliadoPedidosPanel] registran [reload]
  /// al entrar en Pedidos o tras confirmar un pedido.
  static void registerImporterPedidosReload(VoidCallback? reload) {
    _refreshImporterPedidos = reload;
  }

  static void registerPedidosReload(VoidCallback? reload) =>
      registerImporterPedidosReload(reload);

  static void notifyImporterPedidosReload() => _refreshImporterPedidos?.call();

  static void notifyPedidosReload() => notifyImporterPedidosReload();

  /// Índices de la barra B2B activa. La tienda minorista no usa el orden del proveedor.
  static void registerB2BNavigation({
    required int home,
    required int pedidos,
    required int reputation,
    required int profile,
    VoidCallback? onReputation,
  }) {
    _homeTabIndex = home;
    _b2bPedidosTabIndex = pedidos;
    _b2bReputationTabIndex = reputation;
    _b2bProfileTabIndex = profile;
    _openReputation = onReputation;
  }

  static void registerB2BProfileTabIndex(int index) =>
      _b2bProfileTabIndex = index;

  static int get _resolvedB2BProfileTabIndex => _b2bProfileTabIndex ?? 3;

  static void navigateToHomeTab() => _goTo?.call(_homeTabIndex);

  static void navigateToPedidosTab() => _goTo?.call(_b2bPedidosTabIndex);

  static void notifyPedidosDeepLink() => _pedidosNotificationDeepLink?.call();

  /// Abre Pedidos y prellena el buscador (tienda, folio o estado).
  static void navigateToImporterPedidosSearch(String query) {
    final q = query.trim();
    _pendingImporterPedidosSearch = q.isEmpty ? null : q;
    _goTo?.call(_b2bPedidosTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pedidosNotificationDeepLink?.call();
    });
  }

  static String? consumeImporterPedidosSearch() {
    final v = _pendingImporterPedidosSearch;
    _pendingImporterPedidosSearch = null;
    return v;
  }

  /// Abre Inventario con el buscador de nombre o SKU.
  static void navigateToImporterInventorySearch(String query) {
    final q = query.trim();
    _pendingImporterCatalogSearch = q.isEmpty ? null : q;
    navigateToImporterInventory();
  }

  static String? consumeImporterCatalogSearch() {
    final v = _pendingImporterCatalogSearch;
    _pendingImporterCatalogSearch = null;
    return v;
  }

  /// Abre el pedido en la bandeja del importador.
  static void openImporterOrder(String requestId) {
    setPendingNotificationRelatedId(requestId);
    _goTo?.call(_b2bPedidosTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pedidosNotificationDeepLink?.call();
    });
  }

  static void navigateToAliadoFavorites() =>
      _goTo?.call(AliadoShellTabs.favoritos);

  /// Pestaña Reputación del rol que tiene el shell abierto.
  static void navigateToReputationTab() {
    if (_openReputation != null) {
      _openReputation!();
    } else {
      _goTo?.call(_b2bReputationTabIndex);
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      requestNotificationsReload();
    });
  }

  /// Pestaña Perfil del rol activo (aliado / importador / admin).
  static void navigateToProfileTab() {
    if (_b2bProfileTabIndex != null) {
      _goTo?.call(_resolvedB2BProfileTabIndex);
      return;
    }
    navigateToAdminProfileTab();
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

  /// Desde Desempeño de ventas: `nuevos`, `en_proceso` o `cerrados` (sin filtro moroso).
  static void navigateToImporterPedidosExplore(String filter) {
    _pendingImporterPedidosExploreFilter = filter;
    _goTo?.call(_b2bPedidosTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pedidosNotificationDeepLink?.call();
    });
  }

  static String? consumeImporterPedidosExploreFilter() {
    final v = _pendingImporterPedidosExploreFilter;
    _pendingImporterPedidosExploreFilter = null;
    return v;
  }

  static void setPendingOpenOrderChat(bool value) {
    _pendingOpenOrderChat = value;
  }

  static bool consumePendingOpenOrderChat() {
    final value = _pendingOpenOrderChat;
    _pendingOpenOrderChat = false;
    return value;
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

  static void navigateToImporterInventoryForNotification() {
    navigateToImporterInventory();
    SchedulerBinding.instance
        .addPostFrameCallback((_) => notifyImporterInventoryReload());
  }

  /// Las campañas ahora se consultan en Inicio.
  static void navigateToImporterHomeForNotification() {
    navigateToHomeTab();
    SchedulerBinding.instance
        .addPostFrameCallback((_) => notifyImporterHomeReload());
  }

  /// Importador: pestaña Pedidos (índice 1), filtro Nuevos + expande fila.
  static void navigateToImportadorValidadosForNotification() {
    _importerPedidosPreferNuevosFilter = true;
    _goTo?.call(_b2bPedidosTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _importadorValidadosNotificationDeepLink?.call();
    });
  }

  /// [AdminOrdersPanel] — scope + recarga + expand al abrir desde notificación.
  static void registerAdminPedidosBandejaNotificationHandler(
      VoidCallback? onNavigate) {
    _adminPedidosBandejaNotificationHandler = onNavigate;
  }

  /// Admin: pestaña Pedidos unificada + manejo de notificación in-app.
  static void navigateToAdminActivosForNotification() {
    _pendingAdminPedidosScope = AdminPedidosNotificationScope.enCurso;
    _goTo?.call(adminPedidosTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminPedidosBandejaNotificationHandler?.call();
    });
  }

  /// Admin Pedidos con chip «Por confirmar» preactivado.
  static void navigateToAdminPedidosPendingConfirmation() {
    _pendingAdminPedidosScope = AdminPedidosNotificationScope.enCurso;
    _pendingAdminPedidosPendingOnly = true;
    _goTo?.call(adminPedidosTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminPedidosBandejaNotificationHandler?.call();
    });
  }

  /// Sidebar / badge: activa «Por gestionar» sin cambiar de tab si ya estás ahí.
  static void requestAdminPedidosPendingOnly() {
    _pendingAdminPedidosScope = AdminPedidosNotificationScope.enCurso;
    _pendingAdminPedidosPendingOnly = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminPedidosBandejaNotificationHandler?.call();
    });
  }

  /// Sidebar / badge: chip «Por revisar» en Cuentas.
  static void requestAdminUsersPendingReviewOnly() {
    _pendingUsersPendingReviewOnly = true;
    _pendingAdminUsersSection = AdminUsersHubSection.cuentas;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminUsersHubDeepLink?.call();
      _adminAccountNotificationDeepLink?.call();
    });
  }

  /// Sidebar / badge: filtro «Por atender» en Soporte.
  static void requestAdminSupportAttentionOnly() {
    _pendingSupportAttentionOnly = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminSupportNotificationDeepLink?.call();
    });
  }

  /// Sidebar / badge: «En revisión» en Devoluciones.
  static void requestAdminReturnsOpenOnly() {
    _pendingReturnsOpenOnly = true;
    _pendingAdminReportsSection = AdminReportsHubSection.devoluciones;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminReportsHubDeepLink?.call();
      _adminReturnsOpenOnlyDeepLink?.call();
    });
  }

  static bool consumePendingAdminPedidosPendingOnly() {
    final v = _pendingAdminPedidosPendingOnly;
    _pendingAdminPedidosPendingOnly = false;
    return v;
  }

  /// Admin: misma pestaña Pedidos, vista «Cerrados» + expand moroso.
  static void navigateToAdminCerradosForNotification() {
    _pendingAdminPedidosScope = AdminPedidosNotificationScope.cerrados;
    _goTo?.call(adminPedidosTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminPedidosBandejaNotificationHandler?.call();
    });
  }

  /// Pestaña Pedidos del rol activo + expande el pedido de la notificación.
  static void navigateToPedidosForNotification() {
    _goTo?.call(_b2bPedidosTabIndex);
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

  /// Índices de sub-pestañas Perfil (aliado).
  static const aliadoProfileDatosTab = 0;
  static const aliadoProfileKycTab = 1;
  static const aliadoProfileAlertasTab = 2;
  static const aliadoProfileSeguridadTab = 3;

  /// [_ProfileTab] registra el [TabController].
  static void registerAliadoProfileSubTab(void Function(int index)? go) {
    _aliadoProfileSubTab = go;
  }

  /// Abre Perfil en la sub-pestaña indicada.
  ///
  /// Un llamado posterior anula el post-frame del anterior, para que
  /// Datos no pise a Alertas si el recorrido cambia de paso enseguida.
  static void navigateToAliadoProfileSubTab(int index) {
    final serial = ++_profileSubTabSerial;
    _goTo?.call(_resolvedB2BProfileTabIndex);
    void apply() {
      if (serial != _profileSubTabSerial) return;
      _aliadoProfileSubTab?.call(index);
    }

    apply();
    SchedulerBinding.instance.addPostFrameCallback((_) => apply());
  }

  /// Pestaña Perfil → Verificación KYC + scroll a documentación.
  static void navigateToProfileKycDocumentation() {
    navigateToAliadoProfileSubTab(aliadoProfileKycTab);
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

  static int _adminProfileTabIndex = adminProfileTabIndexDefault;
  static VoidCallback? _openAdminSettings;

  /// Admin: hub Usuarios → Cuentas (deep link `userId` / KYC en expediente).
  static void navigateToAdminKycForNotification() {
    navigateToAdminUsers(
      section: AdminUsersHubSection.cuentas,
      userId: peekPendingKycProfileId() ?? peekPendingAccountProfileId(),
      pendingReviewOnly: true,
    );
  }

  /// Admin: hub Usuarios (sección + ficha `userId` opcional).
  static void navigateToAdminUsers({
    AdminUsersHubSection section = AdminUsersHubSection.cuentas,
    String? userId,
    bool pendingReviewOnly = false,
  }) {
    _pendingAdminUsersSection = section;
    if (pendingReviewOnly) _pendingUsersPendingReviewOnly = true;
    final id = userId?.trim();
    if (id != null && id.isNotEmpty) {
      switch (section) {
        case AdminUsersHubSection.cuentas:
          setPendingAccountProfileId(id);
          setPendingKycProfileId(id);
        case AdminUsersHubSection.actividad:
        case AdminUsersHubSection.sellosYVitrina:
          break;
      }
    }
    _goTo?.call(adminUsersTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminUsersHubDeepLink?.call();
      if (section == AdminUsersHubSection.cuentas) {
        _adminAccountNotificationDeepLink?.call();
        _adminKycNotificationDeepLink?.call();
      }
    });
  }

  static bool consumePendingUsersPendingReviewOnly() {
    final v = _pendingUsersPendingReviewOnly;
    _pendingUsersPendingReviewOnly = false;
    return v;
  }

  /// Admin: índice legado (ya no hay pestaña Perfil en el rail).
  static void registerAdminProfileTabIndex(int index) {
    _adminProfileTabIndex = index;
  }

  /// Admin: abre Ajustes del sistema dentro del shell.
  static void registerAdminSettingsOpen(VoidCallback? open) {
    _openAdminSettings = open;
  }

  static void navigateToAdminProfileTab() {
    if (_openAdminSettings != null) {
      _openAdminSettings!();
      return;
    }
    _goTo?.call(_adminProfileTabIndex);
  }

  /// Cada incremento pide abrir Usuarios → Actividad → Presencia.
  static final ValueNotifier<int> adminPresenceRequest = ValueNotifier<int>(0);

  /// Admin: hub Usuarios → Actividad con la presencia desplegada.
  static void navigateToAdminPresence() {
    _pendingAdminUsersSection = AdminUsersHubSection.actividad;
    _goTo?.call(adminUsersTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminUsersHubDeepLink?.call();
      adminPresenceRequest.value++;
    });
  }

  /// Admin: pestaña Reportes / analíticas (sección opcional del hub).
  static void navigateToAdminReportes({
    AdminReportsHubSection section = AdminReportsHubSection.encomiendas,
    bool openReturnsOnly = false,
  }) {
    _pendingAdminReportsSection = section;
    if (openReturnsOnly) _pendingReturnsOpenOnly = true;
    _goTo?.call(adminReportesTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminReportsHubDeepLink?.call();
      if (openReturnsOnly) _adminReturnsOpenOnlyDeepLink?.call();
    });
  }

  static bool consumePendingReturnsOpenOnly() {
    final v = _pendingReturnsOpenOnly;
    _pendingReturnsOpenOnly = false;
    return v;
  }

  static void registerAdminReportsHubDeepLink(VoidCallback? onNavigate) {
    _adminReportsHubDeepLink = onNavigate;
  }

  static void registerAdminReturnsOpenOnlyDeepLink(VoidCallback? onNavigate) {
    _adminReturnsOpenOnlyDeepLink = onNavigate;
  }

  static AdminReportsHubSection? consumePendingAdminReportsSection() {
    final section = _pendingAdminReportsSection;
    _pendingAdminReportsSection = null;
    return section;
  }

  /// Admin: pestaña Comisiones.
  static void navigateToAdminComisionesForNotification() {
    _goTo?.call(adminComisionesTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminCommissionSettlementDeepLink?.call();
    });
  }

  /// Importador: Perfil, cortes abiertos y filtro azul «Pago pendiente».
  static void navigateToImporterPendingCommissions() {
    _importerCommissionPreferPendiente = true;
    navigateToImporterCommissionSettlementsForNotification();
  }

  static bool consumeImporterCommissionPreferPendiente() {
    final v = _importerCommissionPreferPendiente;
    _importerCommissionPreferPendiente = false;
    return v;
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

  static void registerAdminAccountNotificationDeepLink(
      VoidCallback? onNavigate) {
    _adminAccountNotificationDeepLink = onNavigate;
  }

  static void setPendingAccountProfileId(String? profileId) {
    final s = profileId?.trim();
    _pendingAccountProfileId = (s == null || s.isEmpty) ? null : s;
  }

  static String? peekPendingAccountProfileId() {
    final s = _pendingAccountProfileId?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  static String? consumePendingAccountProfileId() {
    final v = _pendingAccountProfileId;
    _pendingAccountProfileId = null;
    return v;
  }

  static void setPendingEntrepreneurAlertFilter(String? status) {
    final s = status?.trim();
    _pendingEntrepreneurAlertFilter = (s == null || s.isEmpty) ? null : s;
  }

  static String? consumePendingEntrepreneurAlertFilter() {
    final v = _pendingEntrepreneurAlertFilter;
    _pendingEntrepreneurAlertFilter = null;
    return v;
  }

  static void registerAdminUsersHubDeepLink(VoidCallback? onNavigate) {
    _adminUsersHubDeepLink = onNavigate;
  }

  static AdminUsersHubSection? consumePendingAdminUsersSection() {
    final v = _pendingAdminUsersSection;
    _pendingAdminUsersSection = null;
    return v;
  }

  static AdminUsersHubSection? peekPendingAdminUsersSection() =>
      _pendingAdminUsersSection;

  /// Admin: pestaña Soporte.
  static void navigateToAdminSupportForNotification({
    bool attentionOnly = true,
  }) {
    if (attentionOnly) _pendingSupportAttentionOnly = true;
    _goTo?.call(adminSupportTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _adminSupportNotificationDeepLink?.call();
    });
  }

  static bool consumePendingSupportAttentionOnly() {
    final v = _pendingSupportAttentionOnly;
    _pendingSupportAttentionOnly = false;
    return v;
  }

  /// Aliado/importador: pantalla de soporte desde notificación (Perfil → soporte).
  static void navigateToSupportForNotification() {
    _goTo?.call(_resolvedB2BProfileTabIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _b2bSupportNotificationDeepLink?.call();
    });
  }

  static void registerAdminSupportNotificationDeepLink(
      VoidCallback? onNavigate) {
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

  /// Segmento extra del breadcrumb (p. ej. Cuentas › Registro Incompleto).
  static final ValueNotifier<AdminBreadcrumbTrail?> adminBreadcrumbTrail =
      ValueNotifier<AdminBreadcrumbTrail?>(null);

  static void setAdminBreadcrumbTrail(AdminBreadcrumbTrail? trail) {
    adminBreadcrumbTrail.value = trail;
  }

  static void clearAdminBreadcrumbTrail() {
    if (adminBreadcrumbTrail.value != null) {
      adminBreadcrumbTrail.value = null;
    }
  }
}

/// Nivel profundo del breadcrumb admin (filtros / detalle).
class AdminBreadcrumbTrail {
  const AdminBreadcrumbTrail({
    required this.leafLabel,
    required this.onBack,
    this.onPopToParent,
  });

  /// Etiqueta del nivel actual (no clicable).
  final String leafLabel;

  /// Retroceso rápido (flecha / historial inmediato).
  final VoidCallback onBack;

  /// Al pulsar el padre inmediato (p. ej. «Cuentas»).
  final VoidCallback? onPopToParent;
}

/// Alcance de la bandeja admin al abrir desde una notificación in-app.
enum AdminPedidosNotificationScope {
  enCurso,
  cerrados,
}
