import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/catalog/importer_promo_widgets.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_count_card.dart';
import 'package:motolink_pro_app/features/dashboard/importer_recent_orders_card.dart';
import 'package:motolink_pro_app/features/inventory/importer_onboarding_checklist.dart';
import 'package:motolink_pro_app/features/onboarding/importer_web_induction.dart';
import 'package:motolink_pro_app/features/inventory/importer_onboarding_checklist_card.dart';
import 'package:motolink_pro_app/features/inventory/importer_priority_actions.dart';
import 'package:motolink_pro_app/features/inventory/importer_sales_snapshot.dart';
import 'package:motolink_pro_app/features/cart/min_order_currency.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica.dart';
import 'package:motolink_pro_app/features/profile/importer_commercial_settings.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Resumen del negocio. La edición de productos vive en Inventario.
class ImporterHomeDashboard extends StatefulWidget {
  const ImporterHomeDashboard({
    super.key,
    required this.profile,
    this.embedInDesktopShell = false,
    this.mobileLayout = false,
    this.onSearch,
    this.onRefreshSummary,
    this.onProfileRefresh,
  });

  final ProfileModel profile;
  final bool embedInDesktopShell;
  final bool mobileLayout;
  final VoidCallback? onSearch;
  final VoidCallback? onRefreshSummary;
  final VoidCallback? onProfileRefresh;

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
              final settled =
                  commissions.connectionState == ConnectionState.done &&
                      !commissions.hasError &&
                      invoiceCount == 0;
              final amount = usd.data;
              final actions = [
                ImporterPriorityAction(
                  label: 'Pedidos por confirmar',
                  value: _count(orders),
                  icon: Icons.inbox_outlined,
                  glyph: LucideGlyph.handbag,
                  cta: 'Gestionar pedidos →',
                  attention: pending != null && pending > 0,
                  onTap: () =>
                      MainShellTabController.navigateToImporterPedidosExplore(
                          'nuevos'),
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
              if (widget.mobileLayout) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ImporterPriorityActions(actions: actions),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: ImporterStoreCountCard(
                        key: ValueKey('mobile-stores-$_revision'),
                        extended: true,
                        inline: true,
                      ),
                    ),
                    inventory,
                  ],
                );
              }
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
                      Expanded(
                        child: row && i == 0
                            ? ImporterTourAnchor(
                                target: ImporterTourTarget.homePriorities,
                                priority: 2,
                                child: cards[i],
                              )
                            : cards[i],
                      ),
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
      final horizontalPadding =
          widget.mobileLayout || (!widget.embedInDesktopShell && !wide)
              ? 16.0
              : 0.0;
      return RefreshIndicator(
        onRefresh: _refresh,
        color: theme.brand,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            24,
          ),
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  widget.mobileLayout ? 'Tu negocio, al día' : 'Resumen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: wide ? 22 : 20,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                  ),
                ),
              ),
              if (widget.onSearch case final onSearch?)
                IconButton(
                  tooltip: 'Buscar en el panel',
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                ),
              if (wide && !widget.mobileLayout)
                TextButton.icon(
                  onPressed: () => ImporterWebInduction.show(
                    context: context,
                    profileId: widget.profile.id,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.textSecondary,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: LucideIcon(
                    LucideGlyph.sparkles,
                    size: 16,
                    color: theme.brand,
                  ),
                  label: const Text(
                    'Ver inducción',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Actualizar resumen',
                onPressed: widget.onRefreshSummary ?? _reload,
                icon: LucideIcon(
                  LucideGlyph.refreshCw,
                  size: 18,
                  color: theme.textSecondary,
                ),
              ),
            ]),
            if (wide && !widget.mobileLayout) ...[
              const SizedBox(height: 12),
              _ImporterMinAmountNotice(
                profile: widget.profile,
                onDefine: () => ImporterCommercialSettings.openDesktop(
                  context,
                  profile: widget.profile,
                  onChanged: widget.onProfileRefresh,
                ),
              ),
              if (EnvioPolitica.normalize(widget.profile.envioTipo) ==
                  EnvioPolitica.noDefinido) ...[
                const SizedBox(height: 12),
                _ImporterShippingNotice(
                  onDefine: () => ImporterCommercialSettings.openDesktop(
                    context,
                    profile: widget.profile,
                    onChanged: widget.onProfileRefresh,
                  ),
                ),
              ],
            ],
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

class _ImporterShippingNotice extends StatelessWidget {
  const _ImporterShippingNotice({required this.onDefine});

  final VoidCallback onDefine;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: LucideIcon(
                LucideGlyph.truck,
                size: 18,
                color: theme.brand,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Política de envío',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aún no definiste si el flete va incluido o es un cobro adicional.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: theme.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: onDefine,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.brand,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    child: const Text(
                      'Configurar envío',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImporterMinAmountNotice extends StatelessWidget {
  const _ImporterMinAmountNotice({
    required this.profile,
    required this.onDefine,
  });

  final ProfileModel profile;
  final VoidCallback onDefine;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final custom = profile.hasMinOrderAmount;
    final currency = MinOrderCurrency.parse(profile.minOrderCurrency);
    final units = profile.minOrderUnits;
    final hasUnits = units != null && units >= 1;
    final status = custom
        ? 'Tu monto mínimo es ${formatMinOrderAmount(profile.minOrderAmountRef, currency)}. '
            'Los pedidos por debajo de ese monto no se confirman.'
        : hasUnits
            ? 'No definiste un monto mínimo. Tus pedidos exigen $units unidades.'
            : 'Aún no definiste monto ni unidades mínimas. Los pedidos se confirman sin ese piso.';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: LucideIcon(
                LucideGlyph.badgeDollarSign,
                size: 18,
                color: theme.brand,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monto mínimo por pedido',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: theme.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: onDefine,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.brand,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    child: Text(
                      custom ? 'Ajustar monto mínimo' : 'Definir condiciones',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
