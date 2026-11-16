import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/catalog/importer_promo_widgets.dart';
import 'package:motolink_pro_app/features/dashboard/importer_recent_orders_card.dart';
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
  late Future<double?> _commissionUsd;
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
    _commissionUsd = SupabaseService.sumMyPendingCommissionUsd();
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
      _commissionUsd.then<void>((_) {}, onError: (Object _) {}),
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

  Widget _summary(AsyncSnapshot<InventoryMetrics> metrics) =>
      FutureBuilder<int?>(
        future: _orders,
        builder: (context, orders) => FutureBuilder<int?>(
          future: _commissions,
          builder: (context, commissions) => FutureBuilder<double?>(
            future: _commissionUsd,
            builder: (context, usd) {
              final pending = orders.data;
              final invoiceCount = commissions.data;
              final settled = commissions.connectionState ==
                      ConnectionState.done &&
                  !commissions.hasError &&
                  invoiceCount == 0;
              final amount = usd.data;
              final actions = [
                ImporterPriorityAction(
                  label: 'Pedidos por confirmar',
                  value: _count(orders),
                  icon: Icons.inbox_outlined,
                  glyph: LucideGlyph.shoppingCart,
                  cta: 'Gestionar pedidos →',
                  attention: pending != null && pending > 0,
                  onTap: () => MainShellTabController
                      .navigateToImporterPedidosExplore('nuevos'),
                ),
                ImporterPriorityAction(
                  label: 'Comisiones por pagar',
                  value: _count(commissions),
                  icon: Icons.receipt_long_outlined,
                  glyph: LucideGlyph.badgeDollarSign,
                  footnote: settled
                      ? 'Al día'
                      : (amount == null
                          ? null
                          : 'USD ${formatRefAmount(amount)}'),
                  cta: 'Ver comisiones →',
                  attention: invoiceCount != null && invoiceCount > 0,
                  onTap: MainShellTabController
                      .navigateToImporterPendingCommissions,
                ),
              ];
              final inventory = _inventorySummary(metrics);
              return LayoutBuilder(builder: (context, constraints) {
                final row = constraints.maxWidth >= AppBreakpoints.mobileMenu;
                final cards = [
                  for (final action in actions)
                    ImporterPriorityCard(action: action, compact: row),
                  inventory,
                ];
                if (!row) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        cards[i],
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              });
            },
          ),
        ),
      );

  Widget _inventorySummary(AsyncSnapshot<InventoryMetrics> snapshot) {
    final theme = B2BThemeExtension.of(context);
    final metrics = snapshot.data;
    final active = metrics == null
        ? 0
        : (metrics.totalProducts - metrics.paused)
            .clamp(0, metrics.totalProducts);
    Widget filterChip(String label, [String? filter]) => ActionChip(
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          labelStyle: const TextStyle(fontSize: 12),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onPressed: () => MainShellTabController.navigateToImporterInventory(
            filter: filter,
          ),
        );
    return Material(
      key: const ValueKey('importer-inventory-summary'),
      color: theme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              LucideIcon(LucideGlyph.package, size: 18, color: theme.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Salud de inventario',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                onPressed: () =>
                    MainShellTabController.navigateToImporterInventory(),
                child: const Text('Ver productos'),
              ),
            ]),
            if (snapshot.hasError)
              TextButton(
                onPressed: _reload,
                child: const Text('No se pudo cargar. Reintentar'),
              )
            else if (metrics == null)
              Text(
                'Cargando productos…',
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              )
            else ...[
              Text(
                '${metrics.totalProducts} productos',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  filterChip('$active activos', 'activos'),
                  filterChip('${metrics.outOfStock} sin stock', 'sin_stock'),
                  filterChip('${metrics.paused} pausados', 'pausados'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= AppBreakpoints.mobileMenu;
      final splitOnboarding = constraints.maxWidth >= 1024;
      return RefreshIndicator(
        onRefresh: _refresh,
        color: theme.brand,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            widget.embedInDesktopShell || wide ? 0 : 16,
            12,
            widget.embedInDesktopShell || wide ? 0 : 16,
            24,
          ),
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  'Tu negocio, al día',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: wide ? 22 : 20,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar resumen',
                onPressed: _reload,
                icon: LucideIcon(
                  LucideGlyph.refreshCw,
                  size: 18,
                  color: theme.textSecondary,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            FutureBuilder<InventoryMetrics>(
              future: _metrics,
              builder: (context, snapshot) {
                final metrics = snapshot.data;
                final checklist = ImporterOnboardingChecklist.evaluate(
                  profile: widget.profile,
                  metrics: metrics,
                );
                final onboarding = metrics != null && !checklist.isComplete
                    ? ImporterOnboardingChecklistCard(
                        checklist: checklist,
                        onOpenProfile: MainShellTabController
                            .navigateToProfileKycDocumentation,
                        onAddProduct: () =>
                            MainShellTabController.navigateToImporterInventory(
                          filter: 'agregar',
                        ),
                      )
                    : null;
                final promos = ImporterActivePromoBanner(
                  key: ValueKey('promos-$_revision'),
                  padding: EdgeInsets.zero,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _summary(snapshot),
                    if (onboarding != null) ...[
                      const SizedBox(height: 16),
                      if (splitOnboarding)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: onboarding),
                            const SizedBox(width: 12),
                            Expanded(child: promos),
                          ],
                        )
                      else ...[
                        onboarding,
                        const SizedBox(height: 12),
                        promos,
                      ],
                    ] else ...[
                      const SizedBox(height: 16),
                      promos,
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<ImporterSalesSnapshot>(
              future: _sales,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TextButton.icon(
                    onPressed: _reload,
                    icon: LucideIcon(
                      LucideGlyph.refreshCw,
                      size: 16,
                      color: theme.brand,
                    ),
                    label: const Text(
                      'No se pudieron cargar las ventas. Reintentar',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return LinearProgressIndicator(
                    minHeight: 2,
                    color: theme.brand,
                    backgroundColor: theme.borderSubtle,
                  );
                }
                return ImporterSalesSnapshotCard(
                  snapshot: snapshot.data!,
                  selectedDays: _days,
                  onDaysChanged: (days) => setState(() {
                    _days = days;
                    _sales = SupabaseService.fetchMySalesSnapshot(days: days);
                  }),
                );
              },
            ),
            const SizedBox(height: 16),
            ImporterRecentOrdersCard(reloadToken: _revision),
            const SizedBox(height: 16),
            ImporterThirdPartyAdsCarousel(
              key: ValueKey('ads-$_revision'),
              padding: const EdgeInsets.only(top: 4),
            ),
          ],
        ),
      );
    });
  }
}
