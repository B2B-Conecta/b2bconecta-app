import 'package:flutter/material.dart';

import '../models/app_home_role.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_approval_inbox_panel.dart';
import '../widgets/aliado_my_requests_panel.dart';
import '../widgets/importer_validated_orders_panel.dart';
import '../widgets/motolink_app_bar.dart';
import '../widgets/profile_b2b_form.dart';
import 'account_settings_screen.dart';
import 'home_screen.dart';

/// Shell principal: catálogo, pedidos, mensajes y perfil (referencia visual).
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

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  Future<void> _refreshProfile() async {
    final p = await SupabaseService.fetchMyProfile();
    if (!mounted || p == null) return;
    setState(() => _profile = p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          HomeScreen(homeRole: widget.homeRole),
          _OrdersTab(homeRole: widget.homeRole),
          _MessagesTab(homeRole: widget.homeRole),
          _ProfileTab(
            profile: _profile,
            homeRole: widget.homeRole,
            onProfileSaved: _refreshProfile,
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
          onTap: (i) => setState(() => _tabIndex = i),
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
                widget.homeRole == AppHomeRole.administrador
                    ? Icons.inbox_outlined
                    : widget.homeRole == AppHomeRole.importador
                        ? Icons.check_circle_outline
                        : Icons.list_alt_outlined,
              ),
              activeIcon: Icon(
                widget.homeRole == AppHomeRole.administrador
                    ? Icons.inbox
                    : widget.homeRole == AppHomeRole.importador
                        ? Icons.check_circle
                        : Icons.list_alt,
              ),
              label: widget.homeRole == AppHomeRole.administrador
                  ? 'Bandeja'
                  : widget.homeRole == AppHomeRole.importador
                      ? 'Pedidos validados'
                      : 'Mis solicitudes',
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
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.homeRole});

  final AppHomeRole homeRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MotolinkAppBar(
        logoHeight: homeRole == AppHomeRole.aliado
            ? MotolinkAppBarLogoSizes.aliado
            : MotolinkAppBarLogoSizes.importador,
        onNotificationTap: () {},
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  homeRole == AppHomeRole.administrador
                      ? Icons.admin_panel_settings_outlined
                      : Icons.inventory_2_outlined,
                  size: 44,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                homeRole == AppHomeRole.administrador
                    ? 'Pedidos (broker)'
                    : 'Mis Pedidos',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                homeRole == AppHomeRole.administrador
                    ? 'La operación de pedidos B2B se gestiona desde la bandeja de aprobación.'
                    : 'Aún no tiene pedidos activos',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesTab extends StatelessWidget {
  const _MessagesTab({required this.homeRole});

  final AppHomeRole homeRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MotolinkAppBar(
        logoHeight: homeRole == AppHomeRole.aliado
            ? MotolinkAppBarLogoSizes.aliado
            : MotolinkAppBarLogoSizes.importador,
        onNotificationTap: () {},
      ),
      body: switch (homeRole) {
        AppHomeRole.administrador => const AdminApprovalInboxPanel(),
        AppHomeRole.importador => const ImporterValidatedOrdersPanel(),
        AppHomeRole.aliado => const AliadoMyRequestsPanel(),
      },
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.profile,
    required this.homeRole,
    required this.onProfileSaved,
  });

  final ProfileModel profile;
  final AppHomeRole homeRole;
  final Future<void> Function() onProfileSaved;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: MotolinkAppBar(
        logoHeight: homeRole == AppHomeRole.aliado
            ? MotolinkAppBarLogoSizes.aliado
            : MotolinkAppBarLogoSizes.importador,
        onNotificationTap: () {},
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
              '${profile.id}_${profile.businessName}_${profile.rif}_${profile.role}',
            ),
            initial: profile,
            onSaved: () {
              onProfileSaved();
            },
          ),
        ),
      ),
    );
  }
}
