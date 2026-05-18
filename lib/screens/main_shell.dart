import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/profile_model.dart';
import '../services/notification_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_active_orders_panel.dart';
import '../widgets/admin_closed_orders_panel.dart';
import '../widgets/admin_commission_settlements_panel.dart';
import '../widgets/admin_encomiendas_report_panel.dart';
import '../widgets/aliado_pedidos_panel.dart';
import '../widgets/importer_active_orders_panel.dart';
import '../widgets/main_shell_tab.dart';
import '../widgets/motolink_app_bar.dart';
import '../widgets/notification_center_sheet.dart';
import '../widgets/profile_b2b_form.dart';
import 'account_settings_screen.dart';
import 'home_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _notifications = NotificationProvider(homeRole: widget.homeRole)
      ..addListener(_onNotificationsChanged)
      ..start();
    MainShellTabController.register((index) {
      if (mounted) setState(() => _tabIndex = index);
    });
    MainShellTabController.registerNotificationsReload(() {
      if (!mounted) return;
      _notifications.reload();
    });
    if (widget.homeRole == AppHomeRole.importador ||
        widget.homeRole == AppHomeRole.aliado) {
      MainShellTabController.registerB2BProfileTabIndex(2);
    }
  }

  @override
  void dispose() {
    _notifications.removeListener(_onNotificationsChanged);
    _notifications.dispose();
    MainShellTabController.unregister();
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
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

  /// Pestañas admin: Activos, Cerrados, Crédito, Reportes, Perfil (sin catálogo).
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
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _adminOrdersScaffold(
            title: 'Pedidos activos',
            child: const AdminActiveOrdersPanel(),
          ),
          _adminOrdersScaffold(
            title: 'Pedidos cerrados',
            child: const AdminClosedOrdersPanel(),
          ),
          _adminOrdersScaffold(
            title: 'Reportes de encomiendas',
            child: const AdminEncomiendasReportPanel(),
          ),
          _adminOrdersScaffold(
            title: 'Comisiones MotoLink',
            subtitle:
                'Devengo al marcar Recibido · corte semanal y facturación por importador.',
            child: const AdminCommissionSettlementsPanel(),
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_outlined),
              activeIcon: Icon(Icons.local_shipping),
              label: 'Activos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.archive_outlined),
              activeIcon: Icon(Icons.archive),
              label: 'Cerrados',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'Reportes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.payments_outlined),
              activeIcon: Icon(Icons.payments),
              label: 'Comisiones',
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

  Widget _buildDefaultShell() {
    return Scaffold(
      body: IndexedStack(
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
          _ProfileTab(
            profile: _profile,
            homeRole: widget.homeRole,
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
          onTap: (i) {
            setState(() => _tabIndex = i);
            if (widget.homeRole == AppHomeRole.aliado && i == 2) {
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
