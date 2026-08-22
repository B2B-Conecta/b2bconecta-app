import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/config/brand_copy.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/core/notifications/notification_provider.dart';
import 'package:motolink_pro_app/core/notifications/push_notification_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/features/commissions/admin_commission_settlements_panel.dart';
import 'package:motolink_pro_app/core/layout/admin_desktop_shell.dart';
import 'package:motolink_pro_app/core/layout/b2b_desktop_shell.dart';
import 'package:motolink_pro_app/features/admin/admin_encomiendas_report_panel.dart';
import 'package:motolink_pro_app/features/kyc/admin_kyc_review_panel.dart';
import 'package:motolink_pro_app/features/reputation/admin_order_ratings_panel.dart';
import 'package:motolink_pro_app/features/orders/admin/admin_orders_panel.dart';
import 'package:motolink_pro_app/features/support/admin_support_tickets_panel.dart';
import 'package:motolink_pro_app/core/notifications/kyc_notification_match.dart';
import 'package:motolink_pro_app/features/kyc/aliado_access_approved_banner.dart';
import 'package:motolink_pro_app/features/orders/aliado/aliado_pedidos_panel.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_active_orders_panel.dart';
import 'main_shell_tab.dart';
import 'package:motolink_pro_app/core/widgets/motolink_app_bar.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_destination.dart';
import 'package:motolink_pro_app/core/notifications/notification_center_sheet.dart';
import 'package:motolink_pro_app/features/profile/profile_b2b_form.dart';
import 'package:motolink_pro_app/features/profile/account_settings_screen.dart';
import 'package:motolink_pro_app/features/cart/cart_screen.dart';
import 'package:motolink_pro_app/features/catalog/home_screen.dart';
import 'package:motolink_pro_app/features/logistics/importer_carriers_screen.dart';
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
  late ProfileModel _profile;
  late final NotificationProvider _notifications;
  bool _showAliadoAccessApprovedBanner = false;
  String _aliadoAccessApprovedMessage =
      'Su acceso a B2B Conecta está habilitado. Ya puede operar en la plataforma.';

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
      if (mounted) setState(() => _tabIndex = index);
    });
    MainShellTabController.registerNotificationsReload(() {
      if (!mounted) return;
      _notifications.reload();
    });
    if (widget.homeRole == AppHomeRole.importador ||
        widget.homeRole == AppHomeRole.aliado) {
      MainShellTabController.registerB2BProfileTabIndex(3);
    }
    unawaited(_ensureDailyTasaBcvNotification());
  }

  Future<void> _ensureDailyTasaBcvNotification() async {
    try {
      await SupabaseService.runDailyTasaBcvNotifyIfDue();
    } catch (_) {}
  }

  @override
  void dispose() {
    PushNotificationService.instance.unregisterTapHandler();
    _notifications.removeListener(_onNotificationsChanged);
    _notifications.dispose();
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

  Future<void> _openNotificationCenter() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => NotificationCenterSheet(provider: _notifications),
    );
  }

  Future<void> _refreshProfile() async {
    final p = await SupabaseService.fetchMyProfile();
    if (!mounted || p == null) return;
    setState(() => _profile = p);
  }

  void _openAccountSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AccountSettingsScreen(),
      ),
    );
  }

  static const _adminDestinations = <AdminShellDestination>[
    AdminShellDestination(
      icon: Icons.local_shipping_outlined,
      selectedIcon: Icons.local_shipping,
      label: 'Pedidos',
      title: 'Pedidos',
      subtitle: 'En curso · Cerrados · Todos',
    ),
    AdminShellDestination(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'Reportes',
      title: 'Reportes',
      subtitle: 'Encomiendas · Promos · Usuarios',
    ),
    AdminShellDestination(
      icon: Icons.star_rate_outlined,
      selectedIcon: Icons.star_rate,
      label: 'Valoraciones',
      title: 'Valoraciones',
      subtitle: 'Aliado ↔ importador',
    ),
    AdminShellDestination(
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      label: 'Comisiones',
      title: 'Comisiones',
      subtitle: 'Devengo · cortes · facturación',
    ),
    AdminShellDestination(
      icon: Icons.verified_user_outlined,
      selectedIcon: Icons.verified_user,
      label: 'KYC',
      title: 'Verificación',
      subtitle: 'Aliados · mayoristas',
    ),
    AdminShellDestination(
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent,
      label: 'Soporte',
      title: 'Soporte',
      subtitle: 'Reclamos · respuesta',
    ),
    AdminShellDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Perfil',
      title: 'Perfil',
      subtitle: 'Cuenta broker',
    ),
  ];

  static const _aliadoDestinations = <ShellDestination>[
    ShellDestination(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view,
      label: 'Catálogo',
      title: 'Catálogo',
      subtitle: 'Repuestos · filtros · carrito',
    ),
    ShellDestination(
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart,
      label: 'Pedidos',
      title: 'Pedidos',
      subtitle: 'En curso · entregas',
    ),
    ShellDestination(
      icon: Icons.star_outline,
      selectedIcon: Icons.star,
      label: 'Reputación',
      title: 'Reputación',
      subtitle: 'Valoraciones · resumen',
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
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      label: 'Inventario',
      title: 'Inventario',
      subtitle: 'Stock · precios · catálogo',
    ),
    ShellDestination(
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart,
      label: 'Pedidos',
      title: 'Pedidos',
      subtitle: 'En curso · historial',
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
    return const [
      AdminOrdersPanel(),
      AdminEncomiendasReportPanel(),
      AdminOrderRatingsPanel(),
      AdminCommissionSettlementsPanel(),
      AdminKycReviewPanel(),
      AdminSupportTicketsPanel(),
    ];
  }

  Widget _adminProfileBody() {
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formMaxWidth,
          ),
          child: ProfileB2BForm(
            key: ValueKey<Object>(
              '${_profile.id}_${_profile.businessName}_${_profile.rif}_${_profile.role}_${_profile.kycStatus}_${_profile.primerosPedidosContadoEntregados}_${_profile.creditLimit}_${_profile.creditoPreactivadoPorAdmin}_${_profile.logoStoragePath}_${_profile.fiscalMapsUrl}',
            ),
            initial: _profile,
            onRelatedDataChanged: _refreshProfile,
            onSaved: _refreshProfile,
          ),
        ),
      ),
    );
  }

  /// Pestañas admin: Pedidos, Reportes, Valoraciones, Comisiones, KYC, Perfil (sin catálogo).
  Widget _adminOrdersScaffold({
    required String title,
    required Widget child,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MotolinkAppBar(
        currentUserProfile: _profile,
        logoHeight: MotolinkAppBarLogoSizes.importador,
        onNotificationTap: _openNotificationCenter,
        unreadNotifications: _notifications.unreadCount,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // En móvil omitimos subtítulos largos: el contenido habla por sí solo.
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildAdminShell() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.adminDesktop) {
          return _buildAdminDesktopShell();
        }
        return _buildAdminMobileShell();
      },
    );
  }

  Widget _buildAdminDesktopShell() {
    final panels = _adminPanelWidgets();
    return AdminDesktopShell(
      selectedIndex: _tabIndex,
      onDestinationSelected: (i) => setState(() => _tabIndex = i),
      destinations: _adminDestinations,
      profile: _profile,
      unreadNotifications: _notifications.unreadCount,
      onNotificationTap: _openNotificationCenter,
      onOpenSettings: _openAccountSettings,
      pages: [
        ...panels,
        _adminProfileBody(),
      ],
    );
  }

  Widget _buildAdminMobileShell() {
    final panels = _adminPanelWidgets();
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          for (var i = 0; i < panels.length; i++)
            _adminOrdersScaffold(
              title: _adminDestinations[i].title,
              child: panels[i],
            ),
          _ProfileTab(
            profile: _profile,
            homeRole: AppHomeRole.administrador,
            onProfileSaved: _refreshProfile,
            onNotificationTap: _openNotificationCenter,
            unreadNotifications: _notifications.unreadCount,
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceTinted,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _tabIndex,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => setState(() => _tabIndex = i),
          items: [
            for (final d in _adminDestinations)
              BottomNavigationBarItem(
                icon: Icon(d.icon),
                activeIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      ),
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
      listenable: CartService.instance,
      builder: (context, _) {
        final n = CartService.instance.itemCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'Carrito',
              onPressed: _openAliadoCart,
              icon: Icon(Icons.shopping_cart_outlined, color: AppColors.textSecondary),
            ),
            if (n > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    n > 99 ? '99+' : '$n',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _onB2bTabSelected(int i, AppHomeRole role) {
    setState(() => _tabIndex = i);
    if (role == AppHomeRole.importador && i == 1) {
      MainShellTabController.notifyImporterPedidosReload();
    }
    if (i == 2 || (role == AppHomeRole.aliado && i == 3)) {
      unawaited(_refreshProfile());
    }
  }

  List<Widget> _b2bPages({
    required AppHomeRole role,
    required bool desktop,
  }) {
    final embedded = desktop;
    return [
      HomeScreen(
        profile: _profile,
        homeRole: role,
        onNotificationTap: _openNotificationCenter,
        unreadNotifications: _notifications.unreadCount,
        embedInDesktopShell: embedded,
      ),
      _OrdersTab(
        profile: _profile,
        homeRole: role,
        onNotificationTap: _openNotificationCenter,
        unreadNotifications: _notifications.unreadCount,
        embedInDesktopShell: embedded,
      ),
      ReputationTab(
        profile: _profile,
        homeRole: role,
        onNotificationTap: _openNotificationCenter,
        unreadNotifications: _notifications.unreadCount,
        onProfileRefresh: _refreshProfile,
        embedInDesktopShell: embedded,
      ),
      _ProfileTab(
        profile: _profile,
        homeRole: role,
        onProfileSaved: _refreshProfile,
        onNotificationTap: _openNotificationCenter,
        unreadNotifications: _notifications.unreadCount,
        embedInDesktopShell: embedded,
      ),
    ];
  }

  Widget _buildB2bDesktopShell({
    required AppHomeRole role,
    required List<ShellDestination> destinations,
    required String railBadgeLabel,
    List<Widget> trailingActions = const [],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showAliadoAccessApprovedBanner && role == AppHomeRole.aliado)
          AliadoAccessApprovedBanner(
            message: _aliadoAccessApprovedMessage,
            onDismiss: _dismissAliadoAccessApprovedBanner,
            compact: true,
          ),
        Expanded(
          child: B2bDesktopShell(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => _onB2bTabSelected(i, role),
            destinations: destinations,
            pages: _b2bPages(role: role, desktop: true),
            profile: _profile,
            unreadNotifications: _notifications.unreadCount,
            onNotificationTap: _openNotificationCenter,
            onOpenSettings: _openAccountSettings,
            railBadgeLabel: railBadgeLabel,
            trailingActions: trailingActions,
          ),
        ),
      ],
    );
  }

  Widget _buildB2bMobileShell({
    required AppHomeRole role,
    required List<BottomNavigationBarItem> navItems,
  }) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showAliadoAccessApprovedBanner && role == AppHomeRole.aliado)
            AliadoAccessApprovedBanner(
              message: _aliadoAccessApprovedMessage,
              onDismiss: _dismissAliadoAccessApprovedBanner,
              compact: true,
            ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: _b2bPages(role: role, desktop: false),
            ),
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceTinted,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _tabIndex,
          type: BottomNavigationBarType.fixed,
          onTap: (i) => _onB2bTabSelected(i, role),
          items: navItems,
        ),
      ),
    );
  }

  Widget _buildDefaultShell() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.b2bDesktop) {
          return _buildB2bDesktopShell(
            role: AppHomeRole.aliado,
            destinations: _aliadoDestinations,
            railBadgeLabel: 'Panel aliado',
            trailingActions: [_aliadoCartTopBarAction()],
          );
        }
        return _buildB2bMobileShell(
          role: AppHomeRole.aliado,
          navItems: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view),
              label: 'Catálogo',
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

  /// Importador: Inventario, Pedidos (unificado), Perfil.
  Widget _buildImportadorShell() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.b2bDesktop) {
          return _buildB2bDesktopShell(
            role: AppHomeRole.importador,
            destinations: _importadorDestinations,
            railBadgeLabel: 'Panel importador',
          );
        }
        return _buildB2bMobileShell(
          role: AppHomeRole.importador,
          navItems: const [
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
    this.embedInDesktopShell = false,
  });

  final ProfileModel profile;
  final AppHomeRole homeRole;
  final VoidCallback onNotificationTap;
  final int unreadNotifications;
  final bool embedInDesktopShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: embedInDesktopShell
          ? null
          : MotolinkAppBar(
        currentUserProfile: profile,
        logoHeight: homeRole == AppHomeRole.aliado
            ? MotolinkAppBarLogoSizes.aliado
            : MotolinkAppBarLogoSizes.importador,
        onNotificationTap: onNotificationTap,
        unreadNotifications: unreadNotifications,
      ),
      body: switch (homeRole) {
        AppHomeRole.importador => const ImporterActiveOrdersPanel(),
        AppHomeRole.administrador => const SizedBox.shrink(),
        AppHomeRole.aliado => const AliadoPedidosPanel(),
      },
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
    this.embedInDesktopShell = false,
  });

  final ProfileModel profile;
  final AppHomeRole homeRole;
  final Future<void> Function() onProfileSaved;
  final VoidCallback onNotificationTap;
  final int unreadNotifications;
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

  Widget _buildSupportEntryCard() {
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
              const Icon(
                Icons.support_agent_outlined,
                color: AppColors.brandBlue,
                size: 28,
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

  Widget _buildCarriersEntryCard() {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const ImporterCarriersScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                color: AppColors.brandBlue,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transportistas',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Registre empresas de transporte y conductores '
                      'para que los aliados elijan en el checkout.',
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedInDesktopShell
          ? null
          : MotolinkAppBar(
        currentUserProfile: widget.profile,
        logoHeight: widget.homeRole == AppHomeRole.aliado
            ? MotolinkAppBarLogoSizes.aliado
            : MotolinkAppBarLogoSizes.importador,
        onNotificationTap: widget.onNotificationTap,
        unreadNotifications: widget.unreadNotifications,
        extraActions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            color: AppColors.textSecondary,
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
      body: SafeArea(
        top: !widget.embedInDesktopShell,
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
                maxWidth: widget.embedInDesktopShell
                    ? AppBreakpoints.formMaxWidth
                    : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              ProfileB2BForm(
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
                afterReputation: showSupportEntry &&
                        widget.homeRole == AppHomeRole.importador
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCarriersEntryCard(),
                          const SizedBox(height: 12),
                          _buildSupportEntryCard(),
                        ],
                      )
                    : showSupportEntry &&
                            widget.homeRole == AppHomeRole.aliado
                        ? _buildSupportEntryCard()
                        : null,
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
