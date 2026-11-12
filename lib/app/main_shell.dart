import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/aliado_shell_tabs.dart';
import 'importer_shell_tabs.dart';
import 'package:motolink_pro_app/features/dashboard/importer_home_dashboard.dart';
import 'package:motolink_pro_app/features/dashboard/aliado_home_dashboard.dart';
import 'package:motolink_pro_app/features/reputation/reputation_overview.dart';
import 'package:motolink_pro_app/app/config/brand_copy.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/core/notifications/notification_provider.dart';
import 'package:motolink_pro_app/core/notifications/push_notification_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/auth/auth_service.dart';
import 'theme/app_theme.dart';
import 'theme/b2b_theme_extension.dart';
import 'theme/theme_controller.dart';
import 'package:motolink_pro_app/core/layout/aliado_bottom_nav.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/features/commissions/admin_commission_settlements_panel.dart';
import 'package:motolink_pro_app/core/layout/admin_desktop_shell.dart';
import 'package:motolink_pro_app/core/layout/admin_mobile_nav.dart';
import 'package:motolink_pro_app/core/layout/admin_shell_drawer.dart';
import 'package:motolink_pro_app/core/layout/b2b_desktop_shell.dart';
import 'package:motolink_pro_app/core/layout/responsive_scaffold.dart';
import 'package:motolink_pro_app/core/layout/shell/admin_shell_badges.dart';
import 'package:motolink_pro_app/core/layout/shell/admin_shell_top_bar.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_user_menu.dart';
import 'package:motolink_pro_app/features/admin/admin_global_search_modal.dart';
import 'package:motolink_pro_app/features/admin/admin_dashboard_panel.dart';
import 'package:motolink_pro_app/features/admin/admin_daily_presence_card.dart';
import 'package:motolink_pro_app/features/admin/user_presence.dart';
import 'package:motolink_pro_app/features/admin/admin_reports_hub_panel.dart';
import 'package:motolink_pro_app/features/admin/admin_reports_hub_section.dart';
import 'package:motolink_pro_app/features/admin/admin_users_hub_panel.dart';
import 'package:motolink_pro_app/features/admin/admin_users_hub_section.dart';
import 'package:motolink_pro_app/features/reputation/admin_order_ratings_panel.dart';
import 'package:motolink_pro_app/features/orders/admin/admin_orders_panel.dart';
import 'package:motolink_pro_app/features/support/admin_support_tickets_panel.dart';
import 'package:motolink_pro_app/core/notifications/kyc_notification_match.dart';
import 'package:motolink_pro_app/features/catalog/importer_daily_store_notice.dart';
import 'package:motolink_pro_app/features/catalog/importer_daily_store_notice_banner.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_count_card.dart';
import 'package:motolink_pro_app/features/kyc/aliado_access_approved_banner.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_pedidos_panel.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_active_orders_panel.dart';
import 'main_shell_tab.dart';
import 'package:motolink_pro_app/core/widgets/aliado_branded_header.dart';
import 'package:motolink_pro_app/core/widgets/header_icon_button.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/motolink_app_bar.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_destination.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_nav_badge.dart';
import 'package:motolink_pro_app/core/notifications/notification_center_popover.dart';
import 'package:motolink_pro_app/core/notifications/web_push_enable_banner.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_inbox_sheet.dart';
import 'package:motolink_pro_app/features/profile/profile_b2b_form.dart';
import 'package:motolink_pro_app/features/profile/account_settings_screen.dart';
import 'package:motolink_pro_app/features/admin/admin_settings_hub.dart';
import 'package:motolink_pro_app/features/admin/admin_settings_tab.dart';
import 'package:motolink_pro_app/features/cart/cart_screen.dart';
import 'package:motolink_pro_app/features/catalog/aliado_favorites_screen.dart';
import 'package:motolink_pro_app/features/catalog/aliado_favorites_service.dart';
import 'package:motolink_pro_app/features/catalog/home_screen.dart';
import 'package:motolink_pro_app/features/reputation/reputation_tab.dart';
import 'package:motolink_pro_app/features/support/support_tickets_screen.dart';
import 'package:motolink_pro_app/features/support/support_ticket_detail_screen.dart';

/// Shell principal: navegación por rol (admin: pedidos; aliado: catálogo / pedidos / perfil).
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.homeRole,
    required this.profile,
  });

  final AppHomeRole homeRole;
  final ProfileModel profile;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;
  AdminUsersHubSection _adminUsersSection = AdminUsersHubSection.cuentas;
  AdminReportsHubSection _adminReportsSection =
      AdminReportsHubSection.encomiendas;
  final _visitedImporterTabs = <int>{ImporterShellTabs.inicio};
  final _visitedAliadoTabs = <int>{AliadoShellTabs.inicio};
  late ProfileModel _profile;
  late final NotificationProvider _notifications;
  AdminShellBadges? _adminShellBadges;
  bool _showAliadoAccessApprovedBanner = false;
  ImporterDailyStoreNotice? _dailyStoreNotice;
  Timer? _presenceTimer;
  String _aliadoAccessApprovedMessage =
      'Su acceso a B2B Conecta está habilitado. Ya puede operar en la plataforma.';
  bool _adminSettingsOpen = false;
  AdminSettingsTab _adminSettingsTab = AdminSettingsTab.perfil;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _notifications = NotificationProvider(homeRole: widget.homeRole)
      ..addListener(_onNotificationsChanged);
    unawaited(
      _notifications.start().then((_) {
        if (mounted) _syncAliadoAccessApprovedBanner();
      }),
    );
    PushNotificationService.instance.registerTapHandler(_onPushNotificationTap);
    unawaited(PushNotificationService.instance.registerForCurrentUser());
    MainShellTabController.register((index) {
      if (mounted) {
        setState(() {
          _tabIndex = index;
          if (widget.homeRole == AppHomeRole.administrador) {
            _adminSettingsOpen = false;
          }
          if (widget.homeRole == AppHomeRole.importador) {
            _visitedImporterTabs.add(index);
          } else if (widget.homeRole == AppHomeRole.aliado) {
            _visitedAliadoTabs.add(index);
          }
        });
      }
    });
    MainShellTabController.registerNotificationsReload(() {
      if (!mounted) return;
      _notifications.reload();
    });
    if (widget.homeRole == AppHomeRole.aliado) {
      _tabIndex = AliadoShellTabs.inicio;
      MainShellTabController.registerB2BNavigation(
        home: AliadoShellTabs.inicio,
        pedidos: AliadoShellTabs.pedidos,
        reputation: AliadoShellTabs.perfil,
        profile: AliadoShellTabs.perfil,
        onReputation: _openAliadoReputation,
      );
      unawaited(_loadAliadoFavorites());
    } else     if (widget.homeRole == AppHomeRole.importador) {
      MainShellTabController.registerB2BNavigation(
        home: ImporterShellTabs.inicio,
        pedidos: ImporterShellTabs.pedidos,
        reputation: ImporterShellTabs.reputacion,
        profile: ImporterShellTabs.perfil,
      );
    }
    if (widget.homeRole == AppHomeRole.administrador) {
      MainShellTabController.registerAdminSettingsOpen(_openAdminProfile);
      _adminShellBadges = AdminShellBadges(notifications: _notifications);
      unawaited(_adminShellBadges!.start());
    }
    unawaited(SupabaseService.touchMyPresence());
    _presenceTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      unawaited(SupabaseService.touchMyPresence());
    });
    if (widget.homeRole == AppHomeRole.importador) {
      unawaited(_loadDailyStoreNotice());
    }
  }

  Future<void> _loadDailyStoreNotice() async {
    final notice = await SupabaseService.fetchImporterDailyStoreNotice();
    if (!mounted || notice.message == null) return;
    setState(() => _dailyStoreNotice = notice);
    unawaited(SupabaseService.ackImporterDailyStoreNotice());
  }

  Future<void> _loadAliadoFavorites() async {
    try {
      await AliadoFavoritesService.instance.refresh();
    } catch (_) {}
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    PushNotificationService.instance.unregisterTapHandler();
    _notifications.removeListener(_onNotificationsChanged);
    _adminShellBadges?.dispose();
    _notifications.dispose();
    MainShellTabController.registerAdminSettingsOpen(null);
    MainShellTabController.unregister();
    super.dispose();
  }

  void _onPushNotificationTap({
    required String type,
    String? relatedId,
    String? notificationId,
    String? title,
  }) {
    if (notificationId != null && notificationId.trim().isNotEmpty) {
      unawaited(_notifications.markAsRead(notificationId.trim()));
    }
    PushNotificationService.navigateTap(
      homeRole: widget.homeRole,
      type: type,
      relatedId: relatedId,
      title: title,
    );
  }

  void _onNotificationsChanged() {
    if (!mounted) return;
    _syncAliadoAccessApprovedBanner();
    setState(() {});
  }

  void _syncAliadoAccessApprovedBanner() {
    if (widget.homeRole != AppHomeRole.aliado) return;
    final pending = _notifications.items.where(
      (n) =>
          !n.isRead &&
          isAliadoAccessApprovedNotification(type: n.type, title: n.title),
    );
    final n = pending.isEmpty ? null : pending.first;
    final show = n != null;
    final raw = n != null && n.body.trim().isNotEmpty
        ? n.body.trim()
        : _aliadoAccessApprovedMessage;
    final message = BrandCopy.display(raw);
    if (show == _showAliadoAccessApprovedBanner &&
        message == _aliadoAccessApprovedMessage) {
      return;
    }
    setState(() {
      _showAliadoAccessApprovedBanner = show;
      _aliadoAccessApprovedMessage = message;
    });
  }

  Future<void> _dismissAliadoAccessApprovedBanner() async {
    final pending = _notifications.items.where(
      (n) =>
          !n.isRead &&
          isAliadoAccessApprovedNotification(type: n.type, title: n.title),
    );
    if (pending.isNotEmpty) {
      try {
        await _notifications.markAsRead(pending.first.id);
      } catch (_) {}
    }
    if (mounted) setState(() => _showAliadoAccessApprovedBanner = false);
  }

  Future<void> _openNotificationCenter([BuildContext? anchor]) async {
    await openNotificationCenter(
      context: context,
      provider: _notifications,
      anchorContext: anchor,
    );
  }

  Future<void> _openMessagesInbox() {
    return showOrderChatInboxSheet(
      context: context,
      homeRole: widget.homeRole,
    );
  }

  Future<void> _refreshProfile() async {
    final p = await SupabaseService.fetchMyProfile();
    if (!mounted || p == null) return;
    setState(() => _profile = p);
  }

  final GlobalKey<ScaffoldState> _adminMobileScaffoldKey =
      GlobalKey<ScaffoldState>();
  final GlobalKey<ScaffoldState> _b2bMobileScaffoldKey =
      GlobalKey<ScaffoldState>();

  void _openAccountSettings({
    AdminSettingsTab initialTab = AdminSettingsTab.perfil,
  }) {
    if (widget.homeRole == AppHomeRole.administrador) {
      setState(() {
        _adminSettingsOpen = true;
        _adminSettingsTab = initialTab;
      });
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AccountSettingsScreen(),
      ),
    );
  }

  void _openAdminProfile() {
    _openAccountSettings(initialTab: AdminSettingsTab.perfil);
  }

  void _openNotificationPrefs() {
    _openAccountSettings(initialTab: AdminSettingsTab.notificaciones);
  }

  void _handleShellUserMenuAction(ShellUserMenuAction action) {
    switch (action) {
      case ShellUserMenuAction.profile:
        _openAdminProfile();
      case ShellUserMenuAction.accountSettings:
        _openAccountSettings();
      case ShellUserMenuAction.notificationPrefs:
        _openNotificationPrefs();
      case ShellUserMenuAction.signOut:
        unawaited(AuthService.signOut());
    }
  }

  static const _adminPanelDestinations = <AdminShellDestination>[
    AdminShellDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      lucideIcon: LucideGlyph.layoutDashboard,
      label: 'Inicio',
      title: 'Inicio',
      subtitle: 'Métricas · actividad',
    ),
    AdminShellDestination(
      icon: Icons.local_shipping_outlined,
      selectedIcon: Icons.local_shipping,
      lucideIcon: LucideGlyph.package,
      badgeKey: AdminShellBadgeKey.pedidos,
      label: 'Pedidos',
      title: 'Pedidos',
      subtitle: 'En curso · Cerrados · Todos',
    ),
    AdminShellDestination(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      lucideIcon: LucideGlyph.barChart3,
      label: 'Reportes',
      title: 'Reportes',
      subtitle: 'Encomiendas · promos · referidos · devoluciones',
      children: [
        ShellDestination(
          icon: Icons.local_shipping_outlined,
          selectedIcon: Icons.local_shipping,
          lucideIcon: LucideGlyph.package,
          id: AdminReportsHubSection.encomiendas,
          label: 'Encomiendas',
          title: 'Encomiendas',
          subtitle:
              'Métricas, exportación Excel y detalle de pedidos en el periodo.',
        ),
        ShellDestination(
          icon: Icons.campaign_outlined,
          selectedIcon: Icons.campaign,
          lucideIcon: LucideGlyph.megaphone,
          id: AdminReportsHubSection.promos,
          label: 'Promos',
          title: 'Promos',
          subtitle: 'Campañas y banners promocionales del marketplace.',
        ),
        ShellDestination(
          icon: Icons.group_add_outlined,
          selectedIcon: Icons.group_add,
          lucideIcon: LucideGlyph.users,
          id: AdminReportsHubSection.referidos,
          label: 'Referidos',
          title: 'Referidos',
          subtitle: 'Red de referidos y comisiones de captación.',
        ),
        ShellDestination(
          icon: Icons.assignment_return_outlined,
          selectedIcon: Icons.assignment_return,
          lucideIcon: LucideGlyph.undo2,
          id: AdminReportsHubSection.devoluciones,
          label: 'Devoluciones',
          title: 'Devoluciones',
          subtitle: 'Postventa, frecuencia y saldo por importador.',
        ),
      ],
    ),
    AdminShellDestination(
      icon: Icons.star_rate_outlined,
      selectedIcon: Icons.star_rate,
      lucideIcon: LucideGlyph.star,
      label: 'Valoraciones',
      title: 'Valoraciones',
      subtitle: 'Tienda minorista ↔ importador',
    ),
    AdminShellDestination(
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      lucideIcon: LucideGlyph.zap,
      label: 'Comisiones',
      title: 'Comisiones',
      subtitle: 'Devengo · cortes · facturación',
    ),
    AdminShellDestination(
      icon: Icons.manage_accounts_outlined,
      selectedIcon: Icons.manage_accounts,
      lucideIcon: LucideGlyph.userRound,
      label: 'Usuarios',
      title: 'Usuarios',
      subtitle: 'Cuentas · actividad · sellos',
      children: [
        ShellDestination(
          icon: Icons.manage_accounts_outlined,
          selectedIcon: Icons.manage_accounts,
          lucideIcon: LucideGlyph.userRound,
          id: AdminUsersHubSection.cuentas,
          label: 'Cuentas',
          title: 'Cuentas',
          subtitle: 'Datos fiscales, KYC, roles, alta y baja.',
        ),
        ShellDestination(
          icon: Icons.monitor_heart_outlined,
          selectedIcon: Icons.monitor_heart,
          lucideIcon: LucideGlyph.refreshCw,
          id: AdminUsersHubSection.actividad,
          label: 'Actividad',
          title: 'Actividad',
          subtitle: 'Presencia e ingresos recientes.',
        ),
        ShellDestination(
          icon: Icons.verified_outlined,
          selectedIcon: Icons.verified,
          lucideIcon: LucideGlyph.shieldCheck,
          id: AdminUsersHubSection.sellosYVitrina,
          label: 'Sellos y Vitrina',
          title: 'Sellos y Vitrina',
          subtitle:
              'Verificado y Destacado de mayoristas en el marketplace.',
        ),
      ],
    ),
    AdminShellDestination(
      icon: Icons.headset_mic_outlined,
      selectedIcon: Icons.headset_mic,
      lucideIcon: LucideGlyph.headset,
      badgeKey: AdminShellBadgeKey.mensajes,
      label: 'Soporte',
      title: 'Soporte',
      subtitle: 'Reclamos · respuesta',
    ),
  ];

  List<AdminShellDestination> get _adminDestinations => _adminPanelDestinations;

  static const _aliadoDestinations = <ShellDestination>[
    ShellDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Inicio',
      title: 'Inicio',
      subtitle: 'Descubre · compra · repón',
      compactHeaderOnScroll: true,
      bottomContentPadding: 8,
    ),
    ShellDestination(
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart,
      label: 'Pedidos',
      title: 'Pedidos',
      subtitle: 'En curso · entregas',
      bottomContentPadding: 8,
      compactHeaderOnScroll: true,
    ),
    ShellDestination(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view,
      label: 'Catálogo',
      title: 'Catálogo',
      subtitle: 'Inicio · repuestos · carrito',
      compactHeaderOnScroll: true,
    ),
    ShellDestination(
      icon: Icons.favorite_border,
      selectedIcon: Icons.favorite,
      label: 'Favoritos',
      title: 'Favoritos',
      subtitle: 'Repuestos guardados',
    ),
    ShellDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Perfil',
      title: 'Perfil',
      subtitle: 'Datos · KYC · cuenta',
    ),
  ];

  static const _importadorDestinations = <ShellDestination>[
    ShellDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: 'Inicio',
        title: 'Inicio',
        subtitle: 'Resumen de tu negocio',
        bottomContentPadding: 8),
    ShellDestination(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: 'Inventario',
      title: 'Inventario',
      subtitle: 'Productos · stock · precios',
      bottomContentPadding: 8,
      compactHeaderOnScroll: true,
    ),
    ShellDestination(
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart,
      label: 'Pedidos',
      title: 'Pedidos',
      subtitle: 'En curso · historial',
      bottomContentPadding: 8,
      compactHeaderOnScroll: true,
    ),
    ShellDestination(
      icon: Icons.star_outline,
      selectedIcon: Icons.star,
      label: 'Reputación',
      title: 'Reputación',
      subtitle: 'Métricas · comentarios',
    ),
    ShellDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Perfil',
      title: 'Perfil',
      subtitle: 'Datos · cuenta',
    ),
  ];

  List<Widget> _adminPanelWidgets() {
    return [
      AdminDashboardPanel(allowAdminRole: _profile.isOwner),
      const AdminOrdersPanel(),
      AdminReportsHubPanel(
        section: _adminReportsSection,
        onSectionChanged: (section) {
          if (!mounted) return;
          setState(() => _adminReportsSection = section);
        },
      ),
      const AdminOrderRatingsPanel(),
      AdminCommissionSettlementsPanel(viewerRole: _profile.role),
      AdminUsersHubPanel(
        viewer: _profile,
        section: _adminUsersSection,
        onSectionChanged: (section) {
          if (!mounted) return;
          setState(() => _adminUsersSection = section);
        },
      ),
      const AdminSupportTicketsPanel(),
    ];
  }

  Widget _adminSettingsBody() {
    return AdminSettingsHub(
      key: ValueKey('admin-settings-$_adminSettingsTab'),
      embedded: true,
      initialTab: _adminSettingsTab,
      onProfileSaved: _refreshProfile,
    );
  }

  List<AdminShellBreadcrumb> get _adminSettingsBreadcrumbs => [
        AdminShellBreadcrumb(
          label: 'Inicio',
          onTap: () => setState(() {
            _tabIndex = 0;
            _adminSettingsOpen = false;
            MainShellTabController.clearAdminBreadcrumbTrail();
          }),
        ),
        const AdminShellBreadcrumb(label: 'Ajustes del sistema'),
      ];

  List<AdminShellBreadcrumb> _adminShellBreadcrumbs() {
    if (_adminSettingsOpen) return _adminSettingsBreadcrumbs;
    final dest = _adminDestinations;
    final index = _tabIndex.clamp(0, dest.length - 1);
    final crumbs = adminShellBreadcrumbsFor(
      destinations: dest,
      selectedIndex: index,
      nestedId: index == MainShellTabController.adminUsersTabIndex
          ? _adminUsersSection
          : index == MainShellTabController.adminReportesTabIndex
              ? _adminReportsSection
              : null,
      onHome: () => setState(() {
            _tabIndex = 0;
            _adminSettingsOpen = false;
            MainShellTabController.clearAdminBreadcrumbTrail();
          }),
      onSelectParent: (i) => setState(() {
            _tabIndex = i;
            _adminSettingsOpen = false;
            MainShellTabController.clearAdminBreadcrumbTrail();
          }),
    );
    final trail = MainShellTabController.adminBreadcrumbTrail.value;
    if (trail == null) return crumbs;
    if (crumbs.isEmpty) {
      return [AdminShellBreadcrumb(label: trail.leafLabel)];
    }
    final parent = crumbs.removeLast();
    crumbs.add(
      AdminShellBreadcrumb(
        label: parent.label,
        onTap: () {
          trail.onPopToParent?.call();
          MainShellTabController.clearAdminBreadcrumbTrail();
        },
      ),
    );
    crumbs.add(AdminShellBreadcrumb(label: trail.leafLabel));
    return crumbs;
  }

  /// Título corto móvil (sin breadcrumbs largos que se truncan).
  List<AdminShellBreadcrumb> _adminMobilePageTitle() {
    if (_adminSettingsOpen) {
      return const [AdminShellBreadcrumb(label: 'Ajustes del sistema')];
    }
    final trail = MainShellTabController.adminBreadcrumbTrail.value;
    if (trail != null) {
      return [AdminShellBreadcrumb(label: trail.leafLabel)];
    }
    final dest = _adminDestinations;
    final index = _tabIndex.clamp(0, dest.length - 1);
    final crumbs = adminShellBreadcrumbsFor(
      destinations: dest,
      selectedIndex: index,
      nestedId: index == MainShellTabController.adminUsersTabIndex
          ? _adminUsersSection
          : index == MainShellTabController.adminReportesTabIndex
              ? _adminReportsSection
              : null,
      onHome: () {},
      onSelectParent: (_) {},
    );
    final label = crumbs.isEmpty ? dest[index].title : crumbs.last.label;
    return [AdminShellBreadcrumb(label: label)];
  }

  /// Shell móvil: header con título de vista (sin hamburguesa / drawer).
  Widget _adminOrdersScaffold({
    required String title,
    required Widget child,
  }) {
    final trail = MainShellTabController.adminBreadcrumbTrail.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AdminShellTopBar(
        breadcrumbs: _adminMobilePageTitle(),
        onBreadcrumbBack: trail?.onBack,
        profile: _profile,
        unreadNotifications: _notifications.unreadCount,
        onNotificationTap: _openNotificationCenter,
        onOpenGlobalSearch: _openAdminGlobalSearch,
        onUserMenuAction: _handleShellUserMenuAction,
      ),
      body: child,
    );
  }

  void _openAdminGlobalSearch() {
    showAdminGlobalSearchModal(context);
  }

  Widget _buildAdminShell() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Rail fijo ≥768; cajón deslizable por debajo (AppShell móvil).
        if (constraints.maxWidth >= AppBreakpoints.mobileMenu) {
          return _buildAdminDesktopShell();
        }
        return _buildAdminMobileShell();
      },
    );
  }

  Widget _buildAdminDesktopShell() {
    final dest = _adminDestinations;
    final index = _tabIndex.clamp(0, dest.length - 1);
    final panels = _adminPanelWidgets();
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.instance,
        MainShellTabController.adminBreadcrumbTrail,
      ]),
      builder: (context, _) {
        AppColors.brightness = ThemeController.instance.effectiveBrightness;
        final trail = MainShellTabController.adminBreadcrumbTrail.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WebPushEnableBanner(),
            Expanded(
              child: AdminDesktopShell(
                selectedIndex: index,
                onDestinationSelected: (i) => setState(() {
                  _tabIndex = i;
                  _adminSettingsOpen = false;
                  MainShellTabController.clearAdminBreadcrumbTrail();
                }),
                selectedNestedId:
                    index == MainShellTabController.adminUsersTabIndex
                        ? _adminUsersSection
                        : index == MainShellTabController.adminReportesTabIndex
                            ? _adminReportsSection
                            : null,
                onNestedDestinationSelected: (parent, nestedId) {
                  setState(() {
                    _tabIndex = parent;
                    _adminSettingsOpen = false;
                    MainShellTabController.clearAdminBreadcrumbTrail();
                    if (nestedId is AdminUsersHubSection) {
                      _adminUsersSection = nestedId;
                    } else if (nestedId is AdminReportsHubSection) {
                      _adminReportsSection = nestedId;
                    }
                  });
                },
                destinations: dest,
                profile: _profile,
                unreadNotifications: _notifications.unreadCount,
                onNotificationTap: _openNotificationCenter,
                onMessagesTap: _openMessagesInbox,
                unreadMessages: _notifications.unreadChatCount,
                onOpenSettings: _openAccountSettings,
                onOpenProfile: _openAdminProfile,
                onOpenNotificationPrefs: _openNotificationPrefs,
                onSignOut: AuthService.signOut,
                navBadges: _adminShellBadges,
                resolveNavBadge: _adminShellBadges?.badgeFor,
                onOpenGlobalSearch: _openAdminGlobalSearch,
                breadcrumbsOverride: _adminShellBreadcrumbs(),
                onBreadcrumbBack: trail?.onBack,
                contentOverride:
                    _adminSettingsOpen ? _adminSettingsBody() : null,
                railStatusBuilder: canQueryAdminPresence(_profile.role)
                    ? (extended) => AdminDailyPresenceCard(
                          extended: extended,
                          darkRail: true,
                          onOpenDetails:
                              MainShellTabController.navigateToAdminPresence,
                        )
                    : null,
                pages: panels,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAdminMobileShell() {
    final dest = _adminDestinations;
    final index = _tabIndex.clamp(0, dest.length - 1);
    final panels = _adminPanelWidgets();
    // Móvil: solo NavigationBar (Inicio · Pedidos · Reportes · Usuarios · Más).
    // Sin drawer / hamburguesa — evita triple navegación redundante.
    return ListenableBuilder(
      listenable: MainShellTabController.adminBreadcrumbTrail,
      builder: (context, _) {
        return ResponsiveScaffold(
          scaffoldKey: _adminMobileScaffoldKey,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WebPushEnableBanner(),
              Expanded(
                child: _adminSettingsOpen
                    ? _adminOrdersScaffold(
                        title: 'Ajustes del sistema',
                        child: _adminSettingsBody(),
                      )
                    : IndexedStack(
                        index: index,
                        children: [
                          for (var i = 0; i < panels.length; i++)
                            _adminOrdersScaffold(
                              title: dest[i].title,
                              child: panels[i],
                            ),
                        ],
                      ),
              ),
            ],
          ),
          bottomNavigationBar: AdminMobileNav(
            currentIndex: index,
            destinations: dest,
            primaryIndices: const [0, 1, 2, 5],
            onSelect: (i) => setState(() {
              _tabIndex = i;
              _adminSettingsOpen = false;
              MainShellTabController.clearAdminBreadcrumbTrail();
            }),
            onOpenAccountMenu: _openAccountSettings,
            navBadges: _adminShellBadges,
            resolveNavBadge: _adminShellBadges?.badgeFor,
          ),
        );
      },
    );
  }

  void _openAliadoCart() {
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CartScreen(
          profile: _profile,
          liveTasaBcv: null,
        ),
      ),
    );
  }

  Widget _aliadoCartTopBarAction() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        CartService.instance,
        ThemeController.instance,
      ]),
      builder: (context, _) {
        final n = CartService.instance.itemCount;
        return HeaderIconButton(
          tooltip: 'Carrito',
          onPressed: _openAliadoCart,
          count: n,
          icon: n > 0 ? Icons.shopping_cart : Icons.shopping_cart_outlined,
        );
      },
    );
  }

  void _onB2bTabSelected(int i, AppHomeRole role) {
    setState(() {
      _tabIndex = i;
      if (role == AppHomeRole.importador) _visitedImporterTabs.add(i);
      if (role == AppHomeRole.aliado) _visitedAliadoTabs.add(i);
    });
    if (role == AppHomeRole.aliado) {
      if (i == AliadoShellTabs.pedidos) {
        MainShellTabController.notifyPedidosReload();
      }
      if (i == AliadoShellTabs.favoritos) {
        unawaited(_loadAliadoFavorites());
      }
      if (i == AliadoShellTabs.perfil) {
        unawaited(_refreshProfile());
      }
      return;
    }
    if (i == ImporterShellTabs.pedidos && role == AppHomeRole.importador) {
      MainShellTabController.notifyPedidosReload();
    }
    if (i == ImporterShellTabs.inicio) {
      MainShellTabController.notifyImporterHomeReload();
    }
    if (i == ImporterShellTabs.reputacion || i == ImporterShellTabs.perfil) {
      unawaited(_refreshProfile());
    }
  }

  List<Widget> _b2bPages({
    required AppHomeRole role,
    required bool desktop,
  }) {
    if (role == AppHomeRole.aliado) {
      return _aliadoPages(desktop: desktop);
    }
    final embedded = desktop;
    return [
      Scaffold(
        backgroundColor: AppColors.background,
        appBar: desktop
            ? null
            : MotolinkAppBar(
                currentUserProfile: _profile,
                onNotificationTap: _openNotificationCenter,
                unreadNotifications: _notifications.unreadCount,
                onMessagesTap: _openMessagesInbox,
                unreadMessages: _notifications.unreadChatCount),
        body: ImporterHomeDashboard(
            profile: _profile, embedInDesktopShell: desktop),
      ),
      if (_visitedImporterTabs.contains(ImporterShellTabs.inventario))
        HomeScreen(
          profile: _profile,
          homeRole: role,
          onNotificationTap: _openNotificationCenter,
          unreadNotifications: _notifications.unreadCount,
          onMessagesTap: _openMessagesInbox,
          unreadMessages: _notifications.unreadChatCount,
          embedInDesktopShell: embedded,
        )
      else
        const SizedBox.shrink(),
      _OrdersTab(
        profile: _profile,
        homeRole: role,
        onNotificationTap: _openNotificationCenter,
        unreadNotifications: _notifications.unreadCount,
        onMessagesTap: _openMessagesInbox,
        unreadMessages: _notifications.unreadChatCount,
        embedInDesktopShell: embedded,
      ),
      ReputationTab(
        profile: _profile,
        homeRole: role,
        onNotificationTap: _openNotificationCenter,
        unreadNotifications: _notifications.unreadCount,
        onMessagesTap: _openMessagesInbox,
        unreadMessages: _notifications.unreadChatCount,
        onProfileRefresh: _refreshProfile,
        embedInDesktopShell: embedded,
      ),
      _ProfileTab(
        profile: _profile,
        homeRole: role,
        onProfileSaved: _refreshProfile,
        onNotificationTap: _openNotificationCenter,
        unreadNotifications: _notifications.unreadCount,
        onMessagesTap: _openMessagesInbox,
        unreadMessages: _notifications.unreadChatCount,
        embedInDesktopShell: embedded,
      ),
    ];
  }

  List<Widget> _aliadoPages({required bool desktop}) {
    final embedded = desktop;
    final pages = <Widget>[
      AliadoHomeDashboard(
        profile: _profile,
        isActiveTab: _tabIndex == AliadoShellTabs.inicio,
        onNotificationTap: _openNotificationCenter,
        unreadNotifications: _notifications.unreadCount,
        onMessagesTap: _openMessagesInbox,
        unreadMessages: _notifications.unreadChatCount,
        embedInDesktopShell: embedded,
      ),
      _OrdersTab(
        profile: _profile,
        homeRole: AppHomeRole.aliado,
        onNotificationTap: _openNotificationCenter,
        unreadNotifications: _notifications.unreadCount,
        onMessagesTap: _openMessagesInbox,
        unreadMessages: _notifications.unreadChatCount,
        embedInDesktopShell: embedded,
      ),
      HomeScreen(
        profile: _profile,
        homeRole: AppHomeRole.aliado,
        isActiveTab: _tabIndex == AliadoShellTabs.catalogo,
        onNotificationTap: _openNotificationCenter,
        unreadNotifications: _notifications.unreadCount,
        onMessagesTap: _openMessagesInbox,
        unreadMessages: _notifications.unreadChatCount,
        embedInDesktopShell: embedded,
      ),
      AliadoFavoritesScreen(
        profile: _profile,
        onNotificationTap: _openNotificationCenter,
        unreadNotifications: _notifications.unreadCount,
        onMessagesTap: _openMessagesInbox,
        unreadMessages: _notifications.unreadChatCount,
        embedInDesktopShell: embedded,
      ),
      _ProfileTab(
        profile: _profile,
        homeRole: AppHomeRole.aliado,
        onProfileSaved: _refreshProfile,
        onNotificationTap: _openNotificationCenter,
        unreadNotifications: _notifications.unreadCount,
        onMessagesTap: _openMessagesInbox,
        unreadMessages: _notifications.unreadChatCount,
        embedInDesktopShell: embedded,
      ),
    ];
    return [
      for (var i = 0; i < pages.length; i++)
        _visitedAliadoTabs.contains(i) ? pages[i] : const SizedBox.shrink()
    ];
  }

  void _openAliadoReputation() {
    Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Mi reputación')),
              body: StatefulBuilder(
                  builder: (context, update) => ReputationOverview(
                      profile: _profile,
                      isImporter: false,
                      showHeading: false,
                      onProfileRefresh: () async {
                        await _refreshProfile();
                        if (context.mounted) update(() {});
                      })),
            )));
  }

  Widget _buildB2bDesktopShell({
    required AppHomeRole role,
    required List<ShellDestination> destinations,
    required String railBadgeLabel,
    List<Widget> trailingActions = const [],
    Widget Function(bool extended)? railStatusBuilder,
  }) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        AppColors.brightness = ThemeController.instance.effectiveBrightness;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WebPushEnableBanner(),
            if (_showAliadoAccessApprovedBanner && role == AppHomeRole.aliado)
              AliadoAccessApprovedBanner(
                message: _aliadoAccessApprovedMessage,
                onDismiss: _dismissAliadoAccessApprovedBanner,
                compact: true,
              ),
            if (role == AppHomeRole.importador && _dailyStoreNotice != null)
              ImporterDailyStoreNoticeBanner(
                notice: _dailyStoreNotice!,
                onDismiss: () => setState(() => _dailyStoreNotice = null),
              ),
            Expanded(
              child: B2bDesktopShell(
                selectedIndex: _tabIndex,
                onDestinationSelected: (i) => _onB2bTabSelected(i, role),
                destinations: destinations,
                // Nuevas instancias de página → IndexedStack redibuja con AppColors actual.
                pages: _b2bPages(role: role, desktop: true),
                profile: _profile,
                unreadNotifications: _notifications.unreadCount,
                onNotificationTap: _openNotificationCenter,
                onMessagesTap: _openMessagesInbox,
                unreadMessages: _notifications.unreadChatCount,
                onOpenSettings: _openAccountSettings,
                onSignOut: AuthService.signOut,
                railBadgeLabel: railBadgeLabel,
                trailingActions: trailingActions,
                railStatusBuilder: railStatusBuilder,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildB2bMobileShell({
    required AppHomeRole role,
    required List<BottomNavigationBarItem> navItems,
    required List<ShellDestination> destinations,
  }) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        AppColors.brightness = ThemeController.instance.effectiveBrightness;
        final theme = B2BThemeExtension.of(context);
        return ResponsiveScaffold(
          scaffoldKey: _b2bMobileScaffoldKey,
          extendBody:
              role == AppHomeRole.aliado && _tabIndex == AliadoShellTabs.inicio,
          drawer: AdminShellDrawer(
            profile: _profile,
            destinations: destinations,
            selectedIndex: _tabIndex.clamp(0, destinations.length - 1),
            onDestinationSelected: (i) => _onB2bTabSelected(i, role),
            onAction: _handleShellUserMenuAction,
            subtitle: role == AppHomeRole.importador
                ? 'Portal mayorista'
                : 'Portal tienda',
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WebPushEnableBanner(),
              if (_showAliadoAccessApprovedBanner && role == AppHomeRole.aliado)
                AliadoAccessApprovedBanner(
                  message: _aliadoAccessApprovedMessage,
                  onDismiss: _dismissAliadoAccessApprovedBanner,
                  compact: true,
                ),
              if (role == AppHomeRole.importador && _dailyStoreNotice != null)
                ImporterDailyStoreNoticeBanner(
                  notice: _dailyStoreNotice!,
                  onDismiss: () => setState(() => _dailyStoreNotice = null),
                ),
              Expanded(
                child: IndexedStack(
                  index: _tabIndex,
                  children: _b2bPages(role: role, desktop: false),
                ),
              ),
            ],
          ),
          bottomNavigationBar: role == AppHomeRole.aliado
              ? AliadoBottomNav(
                  currentIndex: _tabIndex,
                  onTap: (i) => _onB2bTabSelected(i, role),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.surfaceCard,
                    boxShadow: [
                      BoxShadow(
                        color: theme.textPrimary.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: AppBreakpoints.minTouchTarget + 12,
                      child: BottomNavigationBar(
                        currentIndex: _tabIndex,
                        type: BottomNavigationBarType.fixed,
                        backgroundColor: theme.surfaceCard,
                        selectedItemColor: theme.brand,
                        unselectedItemColor: theme.textSecondary,
                        selectedFontSize: 12,
                        unselectedFontSize: 11,
                        onTap: (i) => _onB2bTabSelected(i, role),
                        items: navItems,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildDefaultShell() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.mobileMenu) {
          return _buildB2bDesktopShell(
            role: AppHomeRole.aliado,
            destinations: _aliadoDestinations,
            railBadgeLabel: 'Panel tienda minorista',
            trailingActions: [_aliadoCartTopBarAction()],
          );
        }
        return _buildB2bMobileShell(
          role: AppHomeRole.aliado,
          destinations: _aliadoDestinations,
          navItems: [
            for (final destination in _aliadoDestinations)
              BottomNavigationBarItem(
                  icon: Icon(destination.icon),
                  activeIcon: Icon(destination.selectedIcon),
                  label: destination.label)
          ],
        );
      },
    );
  }

  /// Importador: Inicio, Inventario, Pedidos, Reputación y Perfil.
  Widget _buildImportadorShell() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.mobileMenu) {
          return _buildB2bDesktopShell(
            role: AppHomeRole.importador,
            destinations: _importadorDestinations,
            railBadgeLabel: 'Panel importador',
            railStatusBuilder: (extended) =>
                ImporterStoreCountCard(extended: extended),
          );
        }
        return _buildB2bMobileShell(
          role: AppHomeRole.importador,
          destinations: _importadorDestinations,
          navItems: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Inicio'),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Inventario',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'Pedidos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.star_outline),
              activeIcon: Icon(Icons.star),
              label: 'Reputación',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.homeRole == AppHomeRole.administrador) {
      return _buildAdminShell();
    }
    if (widget.homeRole == AppHomeRole.importador) {
      return _buildImportadorShell();
    }
    return _buildDefaultShell();
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({
    required this.profile,
    required this.homeRole,
    required this.onNotificationTap,
    required this.unreadNotifications,
    this.onMessagesTap,
    this.unreadMessages = 0,
    this.embedInDesktopShell = false,
  });

  final ProfileModel profile;
  final AppHomeRole homeRole;
  final VoidCallback onNotificationTap;
  final int unreadNotifications;
  final VoidCallback? onMessagesTap;
  final int unreadMessages;
  final bool embedInDesktopShell;

  @override
  Widget build(BuildContext context) {
    final useBranded =
        homeRole == AppHomeRole.aliado && !embedInDesktopShell;
    final panel = switch (homeRole) {
      AppHomeRole.importador => const ImporterActiveOrdersPanel(),
      AppHomeRole.administrador => const SizedBox.shrink(),
      AppHomeRole.aliado => const AliadoPedidosPanel(),
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: useBranded || embedInDesktopShell
          ? null
          : MotolinkAppBar(
              currentUserProfile: profile,
              logoHeight: MotolinkAppBarLogoSizes.importador,
              onNotificationTap: onNotificationTap,
              unreadNotifications: unreadNotifications,
              onMessagesTap: onMessagesTap,
              unreadMessages: unreadMessages,
            ),
      body: useBranded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AliadoBrandedHeader(
                  profile: profile,
                  onMessagesTap: onMessagesTap,
                  onNotificationTap: onNotificationTap,
                  unreadMessages: unreadMessages,
                  unreadNotifications: unreadNotifications,
                ),
                Expanded(child: panel),
              ],
            )
          : panel,
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({
    required this.profile,
    required this.homeRole,
    required this.onProfileSaved,
    required this.onNotificationTap,
    required this.unreadNotifications,
    this.onMessagesTap,
    this.unreadMessages = 0,
    this.embedInDesktopShell = false,
  });

  final ProfileModel profile;
  final AppHomeRole homeRole;
  final Future<void> Function() onProfileSaved;
  final VoidCallback onNotificationTap;
  final int unreadNotifications;
  final VoidCallback? onMessagesTap;
  final int unreadMessages;
  final bool embedInDesktopShell;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  @override
  void initState() {
    super.initState();
    if (widget.homeRole == AppHomeRole.aliado ||
        widget.homeRole == AppHomeRole.importador) {
      MainShellTabController.registerB2BSupportNotificationDeepLink(
        _onSupportNotificationDeepLink,
      );
    }
  }

  @override
  void dispose() {
    if (widget.homeRole == AppHomeRole.aliado ||
        widget.homeRole == AppHomeRole.importador) {
      MainShellTabController.registerB2BSupportNotificationDeepLink(null);
    }
    super.dispose();
  }

  Future<void> _onSupportNotificationDeepLink() async {
    if (!mounted) return;
    await _openSupportTickets(openPendingTicket: true);
  }

  Future<void> _openSupportTickets({bool openPendingTicket = false}) async {
    if (openPendingTicket) {
      final ticketId = MainShellTabController.peekPendingSupportTicketId() ??
          MainShellTabController.peekPendingNotificationRelatedId();
      if (ticketId != null && ticketId.isNotEmpty) {
        MainShellTabController.consumePendingSupportTicketId();
        MainShellTabController.consumePendingNotificationRelatedId();
        final ticket = await SupabaseService.fetchSupportTicketById(ticketId);
        if (!mounted) return;
        if (ticket != null) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => SupportTicketDetailScreen(
                ticket: ticket,
                isAdminView: false,
              ),
            ),
          );
          return;
        }
      }
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SupportTicketsScreen(),
      ),
    );
  }

  Widget _buildSupportEntryCard({bool inProfileGroup = false}) {
    final theme = B2BThemeExtension.of(context);
    if (inProfileGroup) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: LucideIcon(
          LucideGlyph.headset,
          size: 22,
          color: theme.brand,
        ),
        title: const Text('Atención al cliente',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: const Text('Gestiona tus reclamos (máx. 3 abiertos).',
            style: TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => _openSupportTickets(),
      );
    }
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openSupportTickets(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              LucideIcon(
                LucideGlyph.headset,
                size: 28,
                color: theme.brand,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atención al cliente',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Abra un reclamo con el equipo B2B Conecta '
                      '(máx. 3 abiertos).',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.brand,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showSupportEntry = widget.homeRole == AppHomeRole.aliado ||
        widget.homeRole == AppHomeRole.importador;

    final useBranded =
        widget.homeRole == AppHomeRole.aliado && !widget.embedInDesktopShell;
    final profileBody = SafeArea(
      top: !useBranded && !widget.embedInDesktopShell,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          widget.embedInDesktopShell ? 0 : 20,
          widget.embedInDesktopShell ? 0 : 8,
          widget.embedInDesktopShell ? 0 : 20,
          24,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: widget.embedInDesktopShell ? 1120 : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileB2BForm(
                  summaryFirst: true,
                  accountActionsInShell: widget.embedInDesktopShell,
                  overviewSupport: showSupportEntry
                      ? _buildSupportEntryCard(
                          inProfileGroup: widget.embedInDesktopShell)
                      : null,
                  key: ValueKey<Object>(
                    '${widget.profile.id}_${widget.profile.businessName}_${widget.profile.rif}_${widget.profile.role}_${widget.profile.kycStatus}_${widget.profile.primerosPedidosContadoEntregados}_${widget.profile.creditLimit}_${widget.profile.creditoPreactivadoPorAdmin}_${widget.profile.logoStoragePath}_${widget.profile.fiscalMapsUrl}',
                  ),
                  initial: widget.profile,
                  onRelatedDataChanged: widget.onProfileSaved,
                  onSaved: () {
                    widget.onProfileSaved();
                  },
                  beforeSignOut: showSupportEntry &&
                          widget.homeRole == AppHomeRole.aliado
                      ? _buildSupportEntryCard()
                      : null,
                  afterReputation:
                      showSupportEntry ? _buildSupportEntryCard() : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: useBranded || widget.embedInDesktopShell
          ? null
          : MotolinkAppBar(
              currentUserProfile: widget.profile,
              logoHeight: MotolinkAppBarLogoSizes.importador,
              onNotificationTap: widget.onNotificationTap,
              unreadNotifications: widget.unreadNotifications,
              onMessagesTap: widget.onMessagesTap,
              unreadMessages: widget.unreadMessages,
              extraActions:
                  widget.profile.hasActiveAccountAccess && showSupportEntry
                      ? const []
                      : [
                          HeaderIconButton(
                            tooltip: 'Ajustes',
                            icon: Icons.settings_outlined,
                            onPressed: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => const AccountSettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
            ),
      body: useBranded
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AliadoBrandedHeader(
                  profile: widget.profile,
                  onMessagesTap: widget.onMessagesTap,
                  onNotificationTap: widget.onNotificationTap,
                  unreadMessages: widget.unreadMessages,
                  unreadNotifications: widget.unreadNotifications,
                ),
                Expanded(child: profileBody),
              ],
            )
          : profileBody,
    );
  }
}
