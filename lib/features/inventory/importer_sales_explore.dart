import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'importer_sales_product_sheet.dart';
import 'importer_sales_snapshot.dart';

enum ImporterSalesMetricKind { active, delivered, units, revenue }

Future<void> showImporterSalesMetricSheet({
  required BuildContext context,
  required ImporterSalesSnapshot snapshot,
  required ImporterSalesMetricKind kind,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _SalesMetricSheet(snapshot: snapshot, kind: kind),
  );
}

Future<void> showImporterSalesSkuSheet({
  required BuildContext context,
  required ImporterSalesSnapshot snapshot,
  required ImporterSalesProductStat product,
  required bool lowRotation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _SalesSkuSheet(
      snapshot: snapshot,
      product: product,
      lowRotation: lowRotation,
    ),
  );
}

class _SalesMetricSheet extends StatelessWidget {
  const _SalesMetricSheet({
    required this.snapshot,
    required this.kind,
  });

  final ImporterSalesSnapshot snapshot;
  final ImporterSalesMetricKind kind;

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            spec.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            spec.subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in spec.stats) _FactChip(label: s.$1, value: s.$2),
            ],
          ),
          if (spec.breakdown.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              spec.breakdownTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const SizedBox(height: 8),
            for (final row in spec.breakdown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ShareRow(
                  name: row.$1,
                  trailing: row.$2,
                  fraction: row.$3,
                ),
              ),
          ],
          const SizedBox(height: 8),
          for (final action in spec.actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pop();
                  action.onPressed(context);
                },
                icon: Icon(action.icon, size: 18),
                label: Text(action.label),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  _MetricSpec get _spec {
    final days = snapshot.days;
    switch (kind) {
      case ImporterSalesMetricKind.active:
        return _MetricSpec(
          title: 'Pedidos en curso',
          subtitle:
              'Solicitudes de los últimos $days días que aún no se entregaron ni se cancelaron.',
          stats: [
            ('En curso', '${snapshot.ordersActive}'),
            ('Entregados', '${snapshot.ordersEntregados}'),
            ('Total del período', '${snapshot.ordersCount}'),
          ],
          actions: [
            _SheetAction(
              label: 'Ver pedidos nuevos',
              icon: Icons.fiber_new_outlined,
              onPressed: (_) =>
                  MainShellTabController.navigateToImporterPedidosExplore(
                'nuevos',
              ),
            ),
            _SheetAction(
              label: 'Ver pedidos en proceso',
              icon: Icons.local_shipping_outlined,
              onPressed: (_) =>
                  MainShellTabController.navigateToImporterPedidosExplore(
                'en_proceso',
              ),
            ),
          ],
        );
      case ImporterSalesMetricKind.delivered:
        return _MetricSpec(
          title: 'Pedidos entregados',
          subtitle:
              'Cierres con éxito en los últimos $days días. El ticket medio usa todos los pedidos no cancelados.',
          stats: [
            ('Entregados', '${snapshot.ordersEntregados}'),
            (
              'Ticket medio',
              '${formatRefAmount(snapshot.averageTicketRef)} REF',
            ),
          ],
          actions: [
            _SheetAction(
              label: 'Ver pedidos cerrados',
              icon: Icons.verified_outlined,
              onPressed: (_) =>
                  MainShellTabController.navigateToImporterPedidosExplore(
                'cerrados',
              ),
            ),
          ],
        );
      case ImporterSalesMetricKind.units:
        final maxU = snapshot.topProducts.fold<int>(
          0,
          (m, p) => p.units > m ? p.units : m,
        );
        return _MetricSpec(
          title: 'Unidades vendidas',
          subtitle:
              'Suma de cantidades pedidas (sin cancelados) en los últimos $days días.',
          stats: [
            ('Unidades', '${snapshot.unitsSold}'),
            ('Por día', snapshot.unitsPerDay.toStringAsFixed(1)),
            (
              'SKUs con venta',
              '${snapshot.topTotal ?? snapshot.topProducts.length}'
            ),
          ],
          breakdownTitle: 'Quién mueve más unidades',
          breakdown: snapshot.topProducts.take(8).map((p) {
            final frac = maxU <= 0 ? 0.0 : p.units / maxU;
            return (p.name, '${p.units} uds', frac);
          }).toList(),
          actions: [
            _SheetAction(
              label: 'Abrir ranking de más vendidos',
              icon: Icons.trending_up_rounded,
              onPressed: (ctx) => showImporterSalesProductSheet(
                context: ctx,
                kind: 'top',
                days: days,
              ),
            ),
          ],
        );
      case ImporterSalesMetricKind.revenue:
        return _MetricSpec(
          title: 'Facturado',
          subtitle:
              'Total REF de pedidos no cancelados en los últimos $days días.',
          stats: [
            ('Facturado', '${formatRefAmount(snapshot.revenueRef)} REF'),
            (
              'Ticket medio',
              '${formatRefAmount(snapshot.averageTicketRef)} REF',
            ),
            ('Por día', '${formatRefAmount(snapshot.revenuePerDay)} REF'),
          ],
          breakdownTitle: 'Participación por SKU',
          breakdown: snapshot.topProducts.take(8).map((p) {
            final share = snapshot.productRevenueShare(p);
            return (
              p.name,
              '${(share * 100).toStringAsFixed(0)}% · ${formatRefAmount(p.revenue)} REF',
              share,
            );
          }).toList(),
          actions: [
            _SheetAction(
              label: 'Abrir ranking de más vendidos',
              icon: Icons.payments_outlined,
              onPressed: (ctx) => showImporterSalesProductSheet(
                context: ctx,
                kind: 'top',
                days: days,
              ),
            ),
          ],
        );
    }
  }
}

class _SalesSkuSheet extends StatelessWidget {
  const _SalesSkuSheet({
    required this.snapshot,
    required this.product,
    required this.lowRotation,
  });

  final ImporterSalesSnapshot snapshot;
  final ImporterSalesProductStat product;
  final bool lowRotation;

  @override
  Widget build(BuildContext context) {
    final share = snapshot.productRevenueShare(product);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            lowRotation
                ? 'Rotación en los últimos ${snapshot.days} días'
                : 'Desempeño en los últimos ${snapshot.days} días',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FactChip(label: 'Unidades', value: '${product.units}'),
              if (!lowRotation || product.revenue > 0)
                _FactChip(
                  label: 'Facturado',
                  value: '${formatRefAmount(product.revenue)} REF',
                ),
              if (!lowRotation && snapshot.revenueRef > 0)
                _FactChip(
                  label: 'Del período',
                  value: '${(share * 100).toStringAsFixed(0)}%',
                ),
            ],
          ),
          if (product.units == 0) ...[
            const SizedBox(height: 12),
            Text(
              'Este SKU está activo y no tuvo pedidos en el período. Conviene revisar precio, foto o visibilidad.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(context).pop();
              showImporterSalesProductSheet(
                context: context,
                kind: lowRotation ? 'low' : 'top',
                days: snapshot.days,
              );
            },
            icon: const Icon(Icons.list_alt_outlined, size: 18),
            label: Text(
              lowRotation ? 'Ver poca rotación' : 'Ver más vendidos',
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MetricSpec {
  const _MetricSpec({
    required this.title,
    required this.subtitle,
    required this.stats,
    this.breakdownTitle = '',
    this.breakdown = const [],
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final List<(String, String)> stats;
  final String breakdownTitle;
  final List<(String, String, double)> breakdown;
  final List<_SheetAction> actions;
}

class _SheetAction {
  const _SheetAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final void Function(BuildContext context) onPressed;
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.name,
    required this.trailing,
    required this.fraction,
  });

  final String name;
  final String trailing;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailing,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0, 1),
            minHeight: 4,
            backgroundColor: AppColors.borderSubtle,
            color: AppColors.brandAccent,
          ),
        ),
      ],
    );
  }
}
