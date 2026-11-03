import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/features/catalog/importer_promo_widgets.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_count_card.dart';
import 'package:motolink_pro_app/features/inventory/importer_onboarding_checklist.dart';
import 'package:motolink_pro_app/features/inventory/importer_onboarding_checklist_card.dart';
import 'package:motolink_pro_app/features/inventory/importer_priority_actions.dart';
import 'package:motolink_pro_app/features/inventory/importer_sales_snapshot.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Resumen del negocio. La edición de productos vive en Inventario.
class ImporterHomeDashboard extends StatefulWidget {
  const ImporterHomeDashboard({super.key, required this.profile});

  final ProfileModel profile;

  @override
  State<ImporterHomeDashboard> createState() => _ImporterHomeDashboardState();
}

class _ImporterHomeDashboardState extends State<ImporterHomeDashboard> {
  late Future<InventoryMetrics> _metrics;
  late Future<int?> _orders;
  late Future<int?> _commissions;
  late Future<ImporterSalesSnapshot> _sales;
  int _days = 30;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _load();
    MainShellTabController.registerImporterHomeReload(_reload);
  }

  void _load() {
    _metrics = SupabaseService.fetchMyInventoryMetrics();
    _orders = SupabaseService.countMyNewOrders();
    _commissions = SupabaseService.countMyPendingCommissionInvoices();
    _sales = SupabaseService.fetchMySalesSnapshot(days: _days);
  }

  void _reload() => setState(() {
        _revision++;
        _load();
      });

  Future<void> _refresh() async {
    _reload();
    // Cada sección conserva su estado de error y su opción de reintentar.
    await Future.wait([
      _metrics.then<void>((_) {}, onError: (Object _) {}),
      _orders.then<void>((_) {}, onError: (Object _) {}),
      _commissions.then<void>((_) {}, onError: (Object _) {}),
      _sales.then<void>((_) {}, onError: (Object _) {}),
    ]);
  }

  @override
  void dispose() {
    MainShellTabController.registerImporterHomeReload(null);
    super.dispose();
  }

  String _count(AsyncSnapshot<int?> snapshot) =>
      snapshot.connectionState != ConnectionState.done
          ? '…'
          : snapshot.hasError || snapshot.data == null
              ? '—'
              : '${snapshot.data}';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(wide ? 0 : 16, 12, wide ? 0 : 16, 24),
          children: [
            Row(children: [
              Expanded(
                child: Text('Tu negocio, al día',
                    style: TextStyle(
                        fontSize: wide ? 22 : 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
              ),
              IconButton(
                  tooltip: 'Actualizar resumen',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh)),
            ]),
            const SizedBox(height: 12),
            FutureBuilder<int?>(
                future: _orders,
                builder: (context, orders) {
                  return FutureBuilder<int?>(
                      future: _commissions,
                      builder: (context, commissions) =>
                          ImporterPriorityActions(actions: [
                            ImporterPriorityAction(
                                label: 'Pedidos por confirmar',
                                value: _count(orders),
                                icon: Icons.inbox_outlined,
                                onTap: () => MainShellTabController
                                    .navigateToImporterPedidosExplore(
                                        'nuevos')),
                            ImporterPriorityAction(
                                label: 'Comisiones por pagar',
                                value: _count(commissions),
                                icon: Icons.receipt_long_outlined,
                                onTap: MainShellTabController
                                    .navigateToImporterPendingCommissions),
                          ]));
                }),
            const SizedBox(height: 16),
            FutureBuilder<InventoryMetrics>(
                future: _metrics,
                builder: (context, snapshot) {
                  final metrics = snapshot.data;
                  final checklist = ImporterOnboardingChecklist.evaluate(
                      profile: widget.profile, metrics: metrics);
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Material(
                            color: AppColors.fieldFill,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        const Icon(Icons.inventory_2_outlined,
                                            size: 20),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                            child: Text('Tu inventario',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700))),
                                        TextButton(
                                            onPressed: () => MainShellTabController
                                                .navigateToImporterInventory(),
                                            child: const Text('Ver productos')),
                                      ]),
                                      if (snapshot.hasError)
                                        TextButton(
                                            onPressed: _reload,
                                            child: const Text(
                                                'No se pudo cargar. Reintentar'))
                                      else if (metrics == null)
                                        const Text('Cargando productos…')
                                      else
                                        Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              ActionChip(
                                                  label: Text(
                                                      '${metrics.totalProducts} productos'),
                                                  onPressed: () =>
                                                      MainShellTabController
                                                          .navigateToImporterInventory()),
                                              ActionChip(
                                                  label: Text(
                                                      '${metrics.outOfStock} sin stock'),
                                                  onPressed: () =>
                                                      MainShellTabController
                                                          .navigateToImporterInventory(
                                                              filter:
                                                                  'sin_stock')),
                                              ActionChip(
                                                  label: Text(
                                                      '${metrics.paused} pausados'),
                                                  onPressed: () =>
                                                      MainShellTabController
                                                          .navigateToImporterInventory(
                                                              filter:
                                                                  'pausados')),
                                            ]),
                                    ]))),
                        if (metrics != null && !checklist.isComplete) ...[
                          const SizedBox(height: 16),
                          ImporterOnboardingChecklistCard(
                              checklist: checklist,
                              onOpenProfile: MainShellTabController
                                  .navigateToProfileKycDocumentation,
                              onAddProduct: () => MainShellTabController
                                  .navigateToImporterInventory(
                                      filter: 'agregar')),
                        ],
                      ]);
                }),
            const SizedBox(height: 16),
            FutureBuilder<ImporterSalesSnapshot>(
                future: _sales,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return TextButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text(
                            'No se pudieron cargar las ventas. Reintentar'));
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  return ImporterSalesSnapshotCard(
                      snapshot: snapshot.data!,
                      selectedDays: _days,
                      onDaysChanged: (days) => setState(() {
                            _days = days;
                            _sales = SupabaseService.fetchMySalesSnapshot(
                                days: days);
                          }));
                }),
            const SizedBox(height: 16),
            ImporterStoreCountCard(
                key: ValueKey('stores-$_revision'),
                extended: true,
                inline: true),
            const SizedBox(height: 4),
            ImporterActivePromoBanner(
                key: ValueKey('promos-$_revision'),
                padding: const EdgeInsets.only(top: 12)),
            ImporterThirdPartyAdsCarousel(
                key: ValueKey('ads-$_revision'),
                padding: const EdgeInsets.only(top: 12)),
          ],
        ),
      );
    });
  }
}
