import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'importer_sales_explore.dart';
import 'importer_sales_product_sheet.dart';

class ImporterSalesProductStat {
  const ImporterSalesProductStat({
    required this.productId,
    required this.name,
    required this.units,
    this.revenue = 0,
  });

  final String productId;
  final String name;
  final int units;
  final double revenue;

  factory ImporterSalesProductStat.fromJson(Map<String, dynamic> json) {
    return ImporterSalesProductStat(
      productId: json['product_id']?.toString() ?? '',
      name: (json['name']?.toString().trim().isNotEmpty == true)
          ? json['name'].toString().trim()
          : 'Producto',
      units: _asInt(json['units']),
      revenue: _asDouble(json['revenue']),
    );
  }
}

class ImporterSalesSnapshot {
  const ImporterSalesSnapshot({
    this.importadorId,
    this.businessName,
    this.catalogFeaturedUntil,
    this.catalogVerifiedAt,
    this.days = 30,
    this.ordersCount = 0,
    this.ordersActive = 0,
    this.ordersEntregados = 0,
    this.unitsSold = 0,
    this.revenueRef = 0,
    this.productsActive = 0,
    this.productsPaused = 0,
    this.topProducts = const [],
    this.lowRotation = const [],
    this.topTotal,
    this.lowTotal,
  });

  static const ImporterSalesSnapshot empty = ImporterSalesSnapshot();

  final String? importadorId;
  final String? businessName;
  final DateTime? catalogFeaturedUntil;
  final DateTime? catalogVerifiedAt;
  final int days;
  final int ordersCount;
  final int ordersActive;
  final int ordersEntregados;
  final int unitsSold;
  final double revenueRef;
  final int productsActive;
  final int productsPaused;
  final List<ImporterSalesProductStat> topProducts;
  final List<ImporterSalesProductStat> lowRotation;
  final int? topTotal;
  final int? lowTotal;

  bool get isCatalogFeatured {
    final until = catalogFeaturedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  bool get isCatalogVerified => catalogVerifiedAt != null;

  /// Ticket medio del período (REF / pedido, sin rechazados).
  double get averageTicketRef =>
      ordersCount <= 0 ? 0 : revenueRef / ordersCount;

  double get unitsPerDay => days <= 0 ? 0 : unitsSold / days;

  double get revenuePerDay => days <= 0 ? 0 : revenueRef / days;

  /// Participación de un SKU sobre lo facturado en el período.
  double productRevenueShare(ImporterSalesProductStat product) {
    if (revenueRef <= 0) return 0;
    return (product.revenue / revenueRef).clamp(0, 1);
  }

  factory ImporterSalesSnapshot.fromJson(Map<String, dynamic> json) {
    return ImporterSalesSnapshot(
      importadorId: json['importador_id']?.toString(),
      businessName: json['business_name']?.toString().trim(),
      catalogFeaturedUntil: json['catalog_featured_until'] != null
          ? DateTime.tryParse(json['catalog_featured_until'].toString())
          : null,
      catalogVerifiedAt: json['catalog_verified_at'] != null
          ? DateTime.tryParse(json['catalog_verified_at'].toString())
          : null,
      days: _asInt(json['days'], fallback: 30),
      ordersCount: _asInt(json['orders_count']),
      ordersActive: _asInt(json['orders_active']),
      ordersEntregados: _asInt(json['orders_entregados']),
      unitsSold: _asInt(json['units_sold']),
      revenueRef: _asDouble(json['revenue_ref']),
      productsActive: _asInt(json['products_active']),
      productsPaused: _asInt(json['products_paused']),
      topProducts: _stats(json['top_products']),
      lowRotation: _stats(json['low_rotation']),
      topTotal: _asInt(json['top_total']),
      lowTotal: _asInt(json['low_total']),
    );
  }
}

int _asInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? fallback;
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

class ImporterSalesProductPage {
  const ImporterSalesProductPage({
    this.kind = 'top',
    this.days = 30,
    this.total = 0,
    this.limit = 25,
    this.offset = 0,
    this.items = const [],
  });

  final String kind;
  final int days;
  final int total;
  final int limit;
  final int offset;
  final List<ImporterSalesProductStat> items;

  bool get hasMore => offset + items.length < total;

  factory ImporterSalesProductPage.fromJson(Map<String, dynamic> json) {
    return ImporterSalesProductPage(
      kind: json['kind']?.toString() ?? 'top',
      days: _asInt(json['days'], fallback: 30),
      total: _asInt(json['total']),
      limit: _asInt(json['limit'], fallback: 25),
      offset: _asInt(json['offset']),
      items: _stats(json['items']),
    );
  }
}

List<ImporterSalesProductStat> _stats(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => ImporterSalesProductStat.fromJson(
            Map<String, dynamic>.from(e),
          ))
      .toList();
}

/// Panel de desempeño de ventas en inventario del mayorista.
class ImporterSalesSnapshotCard extends StatelessWidget {
  const ImporterSalesSnapshotCard({
    super.key,
    required this.snapshot,
    this.daysOptions = const [7, 30],
    this.selectedDays,
    this.onDaysChanged,
  });

  final ImporterSalesSnapshot snapshot;
  final List<int> daysOptions;
  final int? selectedDays;
  final ValueChanged<int>? onDaysChanged;

  int get _days => selectedDays ?? snapshot.days;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final maxUnits = snapshot.topProducts.fold<int>(
      0,
      (m, p) => p.units > m ? p.units : m,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.brandBlue,
                  Color.lerp(AppColors.brandBlue, AppColors.brandAccent, 0.55)!,
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_graph_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Desempeño de ventas',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Pedidos, facturación y rotación de SKUs',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onDaysChanged != null)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            for (final d in daysOptions)
                              _PeriodChip(
                                label: d == 7 ? '7 días' : '30 días',
                                selected: _days == d,
                                onTap: () => onDaysChanged!(d),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  snapshot.ordersCount == 0
                      ? 'Aún no hay movimiento en los últimos $_days días. Toque una métrica cuando haya pedidos.'
                      : '${snapshot.ordersEntregados} entregados · ${snapshot.ordersActive} en curso · ticket ${formatRefAmount(snapshot.averageTicketRef)} REF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final twoCol = c.maxWidth < 560;
                    final tiles = [
                      _MetricTile(
                        icon: Icons.local_shipping_outlined,
                        label: 'En curso',
                        value: '${snapshot.ordersActive}',
                        hint: 'Ver detalle',
                        onTap: () => showImporterSalesMetricSheet(
                          context: context,
                          snapshot: snapshot,
                          kind: ImporterSalesMetricKind.active,
                        ),
                      ),
                      _MetricTile(
                        icon: Icons.verified_outlined,
                        label: 'Entregados',
                        value: '${snapshot.ordersEntregados}',
                        hint: 'Ver detalle',
                        success: snapshot.ordersEntregados > 0,
                        onTap: () => showImporterSalesMetricSheet(
                          context: context,
                          snapshot: snapshot,
                          kind: ImporterSalesMetricKind.delivered,
                        ),
                      ),
                      _MetricTile(
                        icon: Icons.inventory_2_outlined,
                        label: 'Unidades',
                        value: '${snapshot.unitsSold}',
                        hint: 'Ver ranking',
                        onTap: () => showImporterSalesMetricSheet(
                          context: context,
                          snapshot: snapshot,
                          kind: ImporterSalesMetricKind.units,
                        ),
                      ),
                      _MetricTile(
                        icon: Icons.payments_outlined,
                        label: 'Facturado',
                        value: formatRefAmount(snapshot.revenueRef),
                        hint: 'Ver desglose',
                        emphasize: true,
                        onTap: () => showImporterSalesMetricSheet(
                          context: context,
                          snapshot: snapshot,
                          kind: ImporterSalesMetricKind.revenue,
                        ),
                      ),
                    ];
                    if (twoCol) {
                      return Column(
                        children: [
                          Row(children: [
                            Expanded(child: tiles[0]),
                            const SizedBox(width: 8),
                            Expanded(child: tiles[1])
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: tiles[2]),
                            const SizedBox(width: 8),
                            Expanded(child: tiles[3])
                          ]),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (var i = 0; i < tiles.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(child: tiles[i]),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _StatusPill(
                      icon: Icons.storefront_outlined,
                      label: '${snapshot.productsActive} SKUs activos',
                    ),
                    _StatusPill(
                      icon: Icons.pause_circle_outline,
                      label: snapshot.productsPaused == 0
                          ? 'Sin pausados'
                          : '${snapshot.productsPaused} pausados',
                      warn: snapshot.productsPaused > 0,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ProductPanel(
                          title: 'Más vendidos',
                          icon: Icons.trending_up_rounded,
                          empty:
                              'Cuando entren pedidos, aquí verá sus SKUs estrella.',
                          products: snapshot.topProducts,
                          total: snapshot.topTotal,
                          maxUnits: maxUnits,
                          showRevenue: true,
                          onOpenList: () => showImporterSalesProductSheet(
                            context: context,
                            kind: 'top',
                            days: _days,
                          ),
                          onProductTap: (p) => showImporterSalesSkuSheet(
                            context: context,
                            snapshot: snapshot,
                            product: p,
                            lowRotation: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ProductPanel(
                          title: 'Poca rotación',
                          icon: Icons.trending_down_rounded,
                          empty: 'No hay SKUs activos para medir rotación.',
                          products: snapshot.lowRotation,
                          total: snapshot.lowTotal,
                          maxUnits: maxUnits,
                          lowRotation: true,
                          onOpenList: () => showImporterSalesProductSheet(
                            context: context,
                            kind: 'low',
                            days: _days,
                          ),
                          onProductTap: (p) => showImporterSalesSkuSheet(
                            context: context,
                            snapshot: snapshot,
                            product: p,
                            lowRotation: true,
                          ),
                        ),
                      ),
                    ],
                  )
                else ...[
                  _ProductPanel(
                    title: 'Más vendidos',
                    icon: Icons.trending_up_rounded,
                    empty:
                        'Cuando entren pedidos, aquí verá sus SKUs estrella.',
                    products: snapshot.topProducts,
                    total: snapshot.topTotal,
                    maxUnits: maxUnits,
                    showRevenue: true,
                    onOpenList: () => showImporterSalesProductSheet(
                      context: context,
                      kind: 'top',
                      days: _days,
                    ),
                    onProductTap: (p) => showImporterSalesSkuSheet(
                      context: context,
                      snapshot: snapshot,
                      product: p,
                      lowRotation: false,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ProductPanel(
                    title: 'Poca rotación',
                    icon: Icons.trending_down_rounded,
                    empty: 'No hay SKUs activos para medir rotación.',
                    products: snapshot.lowRotation,
                    total: snapshot.lowTotal,
                    maxUnits: maxUnits,
                    lowRotation: true,
                    onOpenList: () => showImporterSalesProductSheet(
                      context: context,
                      kind: 'low',
                      days: _days,
                    ),
                    onProductTap: (p) => showImporterSalesSkuSheet(
                      context: context,
                      snapshot: snapshot,
                      product: p,
                      lowRotation: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.brandBlue : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    this.success = false,
    this.emphasize = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final bool success;
  final bool emphasize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = success
        ? AppColors.successGreen
        : emphasize
            ? AppColors.brandAccent
            : AppColors.brandBlue;
    return Material(
      color: Color.lerp(AppColors.card, accent, 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withOpacity(0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: accent),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: accent.withOpacity(0.8),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              Text(
                hint,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    this.warn = false,
  });

  final IconData icon;
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn ? AppColors.brandBlue : AppColors.successGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductPanel extends StatelessWidget {
  const _ProductPanel({
    required this.title,
    required this.icon,
    required this.empty,
    required this.products,
    required this.maxUnits,
    required this.onOpenList,
    required this.onProductTap,
    this.total,
    this.showRevenue = false,
    this.lowRotation = false,
  });

  final String title;
  final IconData icon;
  final String empty;
  final List<ImporterSalesProductStat> products;
  final int maxUnits;
  final int? total;
  final bool showRevenue;
  final bool lowRotation;
  final VoidCallback onOpenList;
  final ValueChanged<ImporterSalesProductStat> onProductTap;

  @override
  Widget build(BuildContext context) {
    final count = total ?? products.length;
    final preview = products.take(5).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.brandAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  count == 0 ? title : '$title ($count)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (preview.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                empty,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            for (var i = 0; i < preview.length; i++)
              _RankedProductLine(
                rank: i + 1,
                product: preview[i],
                maxUnits: maxUnits,
                showRevenue: showRevenue,
                lowRotation: lowRotation,
                onTap: () => onProductTap(preview[i]),
              ),
          if (count > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onOpenList,
                icon: const Icon(Icons.open_in_full, size: 16),
                label: Text(
                  count > preview.length
                      ? 'Ver listado ($count)'
                      : 'Abrir listado',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RankedProductLine extends StatelessWidget {
  const _RankedProductLine({
    required this.rank,
    required this.product,
    required this.maxUnits,
    required this.onTap,
    this.showRevenue = false,
    this.lowRotation = false,
  });

  final int rank;
  final ImporterSalesProductStat product;
  final int maxUnits;
  final bool showRevenue;
  final bool lowRotation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fraction =
        maxUnits <= 0 ? 0.0 : (product.units / maxUnits).clamp(0.0, 1.0);
    final badgeColor = rank == 1
        ? AppColors.brandAccent
        : rank == 2
            ? AppColors.brandBlue
            : AppColors.textSecondary;
    final trailing = lowRotation
        ? (product.units == 0 ? 'Sin ventas' : '${product.units} uds')
        : '${product.units} uds'
            '${showRevenue ? ' · ${formatRefAmount(product.revenue)} REF' : ''}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            trailing,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (!lowRotation && maxUnits > 0) ...[
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 4,
                            backgroundColor: AppColors.borderSubtle,
                            color: AppColors.brandAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
