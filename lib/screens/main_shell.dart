import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/profile_model.dart';
import '../services/notification_provider.dart';
import '../services/push_notification_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_breakpoints.dart';
import '../widgets/admin_commission_settlements_panel.dart';
import '../widgets/admin_desktop_shell.dart';
import '../widgets/admin_encomiendas_report_panel.dart';
import '../widgets/admin_kyc_review_panel.dart';
import '../widgets/admin_order_ratings_panel.dart';
import '../widgets/admin_orders_panel.dart';
import '../utils/kyc_notification_match.dart';
import '../widgets/aliado_access_approved_banner.dart';
import '../widgets/aliado_pedidos_panel.dart';
import '../widgets/importer_active_orders_panel.dart';
import '../widgets/main_shell_tab.dart';
import '../widgets/motolink_app_bar.dart';
import '../widgets/notification_center_sheet.dart';
import '../widgets/profile_b2b_form.dart';
import 'account_settings_screen.dart';
import 'home_screen.dart';
import 'reputation_tab.dart';

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
      'Su acceso a MotoLink está habilitado. Ya puede operar en la plataforma.';

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
    final message = n != null && n.body.trim().isNotEmpty
        ? n.body.trim()
        : _aliadoAccessApprovedMessage;
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
      backgroundColor: Colors.white,
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
      subtitle:
          'Use «En curso», «Cerrados» o «Todos» y filtre por estado o búsqueda.',
    ),
    AdminShellDestination(
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      label: 'Reportes',
      title: 'Reportes de encomiendas',
    ),
    AdminShellDestination(
      icon: Icons.star_rate_outlined,
      selectedIcon: Icons.star_rate,
      label: 'Valoraciones',
      title: 'Valoraciones',
      subtitle:
          'Expediente aliado ↔ importador tras la entrega. Filtre por dirección y despliegue el detalle.',
    ),
    AdminShellDestination(
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      label: 'Comisiones',
      title: 'Comisiones MotoLink',
      subtitle:
          'Devengo al marcar Recibido · corte semanal y facturación por importador.',
    ),
    AdminShellDestination(
      icon: Icons.verified_user_outlined,
      selectedIcon: Icons.verified_user,
      label: 'KYC',
      title: 'Verificación KYC',
      subtitle:
          'Revise documentación de aliados e importadores; apruebe por archivo o el estado global.',
    ),
    AdminShellDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Perfil',
      title: 'Mi perfil',
      subtitle: 'Datos de la cuenta broker MotoLink.',
    ),
  ];

  List<Widget> _adminPanelWidgets() {
    return const [
      AdminOrdersPanel(),
      AdminEncomiendasReportPanel(),
      AdminOrderRatingsPanel(),
      AdminCommissionSettlementsPanel(),
      AdminKycReviewPanel(),
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
    String? subtitle,
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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
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
              subtitle: _adminDestinations[i].subtitle,
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

  Widget _buildDefaultShell() {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showAliadoAccessApprovedBanner)
            AliadoAccessApprovedBanner(
              message: _aliadoAccessApprovedMessage,
              onDismiss: _dismissAliadoAccessApprovedBanner,
              compact: true,
            ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                HomeScreen(
                  profile: _profile,
                  homeRole: widget.homeRole,
                  onNotificationTap: _openNotificationCenter,
                  unreadNotifications: _notifications.unreadCount,
                ),
                _OrdersTab(
                  profile: _profile,
                  homeRole: widget.homeRole,
                  onNotificationTap: _openNotificationCenter,
                  unreadNotifications: _notifications.unreadCount,
                ),
                ReputationTab(
                  profile: _profile,
                  homeRole: widget.homeRole,
                  onNotificationTap: _openNotificationCenter,
                  unreadNotifications: _notifications.unreadCount,
                  onProfileRefresh: _refreshProfile,
                ),
                _ProfileTab(
                  profile: _profile,
                  homeRole: widget.homeRole,
                  onProfileSaved: _refreshProfile,
                  onNotificationTap: _openNotificationCenter,
                  unreadNotifications: _notifications.unreadCount,
                ),
              ],
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
          onTap: (i) {
            setState(() => _tabIndex = i);
            if (widget.homeRole == AppHomeRole.aliado && i == 3) {
              unawaited(_refreshProfile());
            }
          },
          items: const [
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
        ),
      ),
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

  /// Importador: Inventario, Pedidos (unificado), Perfil.
  Widget _buildImportadorShell() {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          HomeScreen(
            profile: _profile,
            homeRole: AppHomeRole.importador,
            onNotificationTap: _openNotificationCenter,
            unreadNotifications: _notifications.unreadCount,
          ),
          _OrdersTab(
            profile: _profile,
            homeRole: AppHomeRole.importador,
            onNotificationTap: _openNotificationCenter,
            unreadNotifications: _notifications.unreadCount,
          ),
          ReputationTab(
            profile: _profile,
            homeRole: AppHomeRole.importador,
            onNotificationTap: _openNotificationCenter,
            unreadNotifications: _notifications.unreadCount,
            onProfileRefresh: _refreshProfile,
          ),
          _ProfileTab(
            profile: _profile,
            homeRole: AppHomeRole.importador,
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
          onTap: (i) {
            setState(() => _tabIndex = i);
            if (i == 1) {
              MainShellTabController.notifyImporterPedidosReload();
            }
            if (i == 2) {
              unawaited(_refreshProfile());
            }
          },
          items: const [
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
        ),
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({
    required this.profile,
    required this.homeRole,
    required this.onNotificationTap,
    required this.unreadNotifications,
  });

  final ProfileModel profile;
  final AppHomeRole homeRole;
  final VoidCallback onNotificationTap;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MotolinkAppBar(
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

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.profile,
    required this.homeRole,
    required this.onProfileSaved,
    required this.onNotificationTap,
    required this.unreadNotifications,
  });

  final ProfileModel profile;
  final AppHomeRole homeRole;
  final Future<void> Function() onProfileSaved;
  final VoidCallback onNotificationTap;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MotolinkAppBar(
        currentUserProfile: profile,
        logoHeight: homeRole == AppHomeRole.aliado
            ? MotolinkAppBarLogoSizes.aliado
            : MotolinkAppBarLogoSizes.importador,
        onNotificationTap: onNotificationTap,
        unreadNotifications: unreadNotifications,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ProfileB2BForm(
            key: ValueKey<Object>(
              '${profile.id}_${profile.businessName}_${profile.rif}_${profile.role}_${profile.kycStatus}_${profile.primerosPedidosContadoEntregados}_${profile.creditLimit}_${profile.creditoPreactivadoPorAdmin}_${profile.logoStoragePath}_${profile.fiscalMapsUrl}',
            ),
            initial: profile,
            onRelatedDataChanged: onProfileSaved,
            onSaved: () {
              onProfileSaved();
            },
          ),
        ),
      ),
    );
  }
}
