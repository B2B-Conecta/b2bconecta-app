import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/features/catalog/importer_promo_widgets.dart';
import 'package:motolink_pro_app/features/inventory/importer_onboarding_checklist.dart';
import 'package:motolink_pro_app/features/inventory/importer_onboarding_checklist_card.dart';
import 'package:motolink_pro_app/features/inventory/importer_priority_actions.dart';
import 'package:motolink_pro_app/features/inventory/importer_sales_snapshot.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Resumen del negocio. La edición de productos vive en Inventario.
class ImporterHomeDashboard extends StatefulWidget {
  const ImporterHomeDashboard(
      {super.key, required this.profile, this.embedInDesktopShell = false});

  final ProfileModel profile;
  final bool embedInDesktopShell;

  @override
  State<ImporterHomeDashboard> createState() => _ImporterHomeDashboardState();
}

class _ImporterHomeDashboardState extends State<ImporterHomeDashboard> {
  late Future<InventoryMetrics> _metrics;
  late Future<int?> _orders;
  late Future<int?> _commissions;
  late Future<int?> _stores;
  Timer? _storeRefresh;
  late Future<ImporterSalesSnapshot> _sales;
  int _days = 30;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _configureStoreRefresh();
    MainShellTabController.registerImporterHomeReload(_reload);
  }

  void _load() {
    _metrics = SupabaseService.fetchMyInventoryMetrics();
    _orders = SupabaseService.countMyNewOrders();
    _commissions = SupabaseService.countMyPendingCommissionInvoices();
    _stores = widget.embedInDesktopShell ? Future.value(null) : _loadStores();
    _sales = SupabaseService.fetchMySalesSnapshot(days: _days);
  }

  Future<int?> _loadStores() async =>
      (await SupabaseService.fetchImporterDailyStoreNotice()).panelCount;

  void _configureStoreRefresh() {
    _storeRefresh?.cancel();
    if (!widget.embedInDesktopShell) {
      _storeRefresh = Timer.periodic(const Duration(minutes: 5), (_) {
        setState(() => _stores = _loadStores());
      });
    }
  }

  @override
  void didUpdateWidget(covariant ImporterHomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.embedInDesktopShell != widget.embedInDesktopShell) {
      _stores = widget.embedInDesktopShell ? Future.value(null) : _loadStores();
      _configureStoreRefresh();
    }
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
      _stores.then<void>((_) {}, onError: (Object _) {}),
      _sales.then<void>((_) {}, onError: (Object _) {}),
    ]);
  }

  @override
  void dispose() {
    _storeRefresh?.cancel();
    MainShellTabController.registerImporterHomeReload(null);
    super.dispose();
  }

  String _count(AsyncSnapshot<int?> snapshot) =>
      snapshot.connectionState != ConnectionState.done
          ? '…'
          : snapshot.hasError || snapshot.data == null
              ? '—'
              : '${snapshot.data}';

  Widget _summary(AsyncSnapshot<InventoryMetrics> metrics) =>
      FutureBuilder<int?>(
          future: _orders,
          builder: (context, orders) => FutureBuilder<int?>(
              future: _commissions,
              builder: (context, commissions) {
                final actions = [
                  ImporterPriorityAction(
                      label: 'Pedidos por confirmar',
                      value: _count(orders),
                      icon: Icons.inbox_outlined,
                      onTap: () => MainShellTabController
                          .navigateToImporterPedidosExplore('nuevos')),
                  ImporterPriorityAction(
                      label: 'Comisiones por pagar',
                      value: _count(commissions),
                      icon: Icons.receipt_long_outlined,
                      onTap: MainShellTabController
                          .navigateToImporterPendingCommissions),
                ];
                final inventory = _inventorySummary(metrics);
                if (widget.embedInDesktopShell) {
                  return LayoutBuilder(builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 24) / 4;
                    return IntrinsicHeight(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                          for (final action in actions) ...[
                            SizedBox(
                                width: cardWidth,
                                child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(minHeight: 112),
                                    child: ImporterPriorityCard(
                                        action: action, compact: true))),
                            const SizedBox(width: 12),
                          ],
                          SizedBox(width: cardWidth * 2, child: inventory),
                        ]));
                  });
                }
                return FutureBuilder<int?>(
                    future: _stores,
                    builder: (context, stores) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ImporterPriorityActions(actions: [
                                ...actions,
                                ImporterPriorityAction(
                                    label: stores.data == 1
                                        ? 'Tienda activa'
                                        : 'Tiendas activas',
                                    value: _count(stores),
                                    icon: Icons.storefront_outlined,
                                    iconColor: AppColors.successGreen,
                                    tooltip:
                                        'Tiendas minoristas con verificación aprobada, '
                                        'cuenta activa y RIF distinto.'),
                              ]),
                              const SizedBox(height: 16),
                              inventory,
                            ]));
              }));

  Widget _inventorySummary(AsyncSnapshot<InventoryMetrics> snapshot) {
    final metrics = snapshot.data;
    Widget filterChip(String label, [String? filter]) => ActionChip(
        label: Text(label),
        labelStyle:
            widget.embedInDesktopShell ? const TextStyle(fontSize: 12) : null,
        visualDensity:
            widget.embedInDesktopShell ? VisualDensity.compact : null,
        materialTapTargetSize: widget.embedInDesktopShell
            ? MaterialTapTargetSize.shrinkWrap
            : null,
        onPressed: () =>
            MainShellTabController.navigateToImporterInventory(filter: filter));
    final chips = metrics == null
        ? <Widget>[]
        : [
            filterChip('${metrics.totalProducts} productos'),
            filterChip('${metrics.outOfStock} sin stock', 'sin_stock'),
            filterChip('${metrics.paused} pausados', 'pausados'),
          ];
    return Material(
        key: const ValueKey('importer-inventory-summary'),
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.inventory_2_outlined, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: Text('Tu inventario',
                            style: TextStyle(fontWeight: FontWeight.w700))),
                    TextButton(
                        style: widget.embedInDesktopShell
                            ? TextButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                textStyle: const TextStyle(fontSize: 12))
                            : null,
                        onPressed: () => MainShellTabController
                            .navigateToImporterInventory(),
                        child: const Text('Ver productos')),
                  ]),
                  if (snapshot.hasError)
                    TextButton(
                        onPressed: _reload,
                        child: const Text('No se pudo cargar. Reintentar'))
                  else if (metrics == null)
                    const Text('Cargando productos…')
                  else
                    Wrap(spacing: 8, runSpacing: 4, children: chips),
                ])));
  }

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
            FutureBuilder<InventoryMetrics>(
                future: _metrics,
                builder: (context, snapshot) {
                  final metrics = snapshot.data;
                  final checklist = ImporterOnboardingChecklist.evaluate(
                      profile: widget.profile, metrics: metrics);
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _summary(snapshot),
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
            ImporterActivePromoBanner(
                key: ValueKey('promos-$_revision'),
                padding: const EdgeInsets.only(bottom: 16)),
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
            ImporterThirdPartyAdsCarousel(
                key: ValueKey('ads-$_revision'),
                padding: const EdgeInsets.only(top: 12)),
          ],
        ),
      );
    });
  }
}
