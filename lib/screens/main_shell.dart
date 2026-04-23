import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/profile_model.dart';
import '../services/notification_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_active_orders_panel.dart';
import '../widgets/admin_aliados_credit_panel.dart';
import '../widgets/admin_closed_orders_panel.dart';
import '../widgets/admin_encomiendas_report_panel.dart';
import '../widgets/admin_pending_validation_panel.dart';
import '../widgets/aliado_my_requests_panel.dart';
import '../widgets/aliado_pedidos_panel.dart';
import '../widgets/importer_active_orders_panel.dart';
import '../widgets/importer_validated_orders_panel.dart';
import '../widgets/main_shell_tab.dart';
import '../widgets/motolink_app_bar.dart';
import '../widgets/notification_center_sheet.dart';
import '../widgets/profile_b2b_form.dart';
import 'account_settings_screen.dart';
import 'home_screen.dart';

/// Shell principal: navegación por rol (admin: pedidos; resto: catálogo / pedidos / bandeja / perfil).
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

  /// Pestañas admin: Activos, Cerrados, Por validar, Crédito, Perfil (sin catálogo).
  Widget _adminOrdersScaffold({required String title, required Widget child}) {
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
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
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
            title: 'Por validar',
            child: const AdminPendingValidationPanel(),
          ),
          _adminOrdersScaffold(
            title: 'Límites de crédito',
            child: const AdminAliadosCreditPanel(),
          ),
          _adminOrdersScaffold(
            title: 'Reportes de encomiendas',
            child: const AdminEncomiendasReportPanel(),
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
              icon: Icon(Icons.fact_check_outlined),
              activeIcon: Icon(Icons.fact_check),
              label: 'Validar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_outlined),
              activeIcon: Icon(Icons.account_balance),
              label: 'Crédito',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'Reportes',
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
          _MessagesTab(
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
            if (widget.homeRole == AppHomeRole.importador && i == 1) {
              MainShellTabController.notifyImporterPedidosReload();
            }
            if (widget.homeRole == AppHomeRole.aliado && i == 3) {
              unawaited(_refreshProfile());
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                widget.homeRole == AppHomeRole.importador
                    ? Icons.inventory_2_outlined
                    : Icons.grid_view_outlined,
              ),
              activeIcon: Icon(
                widget.homeRole == AppHomeRole.importador
                    ? Icons.inventory_2
                    : Icons.grid_view,
              ),
              label: widget.homeRole == AppHomeRole.importador
                  ? 'Inventario'
                  : 'Catálogo',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'Pedidos',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                widget.homeRole == AppHomeRole.importador
                    ? Icons.check_circle_outline
                    : Icons.list_alt_outlined,
              ),
              activeIcon: Icon(
                widget.homeRole == AppHomeRole.importador
                    ? Icons.check_circle
                    : Icons.list_alt,
              ),
              label: widget.homeRole == AppHomeRole.importador
                  ? 'Validados'
                  : 'Solicitudes',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportistaShell() {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _adminOrdersScaffold(
            title: 'Despacho',
            child: const AdminActiveOrdersPanel(
              isTransportistaView: true,
            ),
          ),
          _ProfileTab(
            profile: _profile,
            homeRole: AppHomeRole.transportista,
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
    if (widget.homeRole == AppHomeRole.transportista) {
      return _buildTransportistaShell();
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
        AppHomeRole.transportista => const SizedBox.shrink(),
      },
    );
  }
}

class _MessagesTab extends StatelessWidget {
  const _MessagesTab({
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
        AppHomeRole.administrador => const SizedBox.shrink(),
        AppHomeRole.importador => const ImporterValidatedOrdersPanel(),
        AppHomeRole.aliado => const AliadoMyRequestsPanel(),
        AppHomeRole.transportista => const SizedBox.shrink(),
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
