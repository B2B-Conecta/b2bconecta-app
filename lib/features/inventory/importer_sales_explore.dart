import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'importer_sales_product_sheet.dart';
import 'importer_sales_snapshot.dart';

enum ImporterSalesMetricKind { active, delivered, units, revenue }

Future<void> _showImporterPanel(BuildContext context, Widget child) {
  final theme = B2BThemeExtension.of(context);
  final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
  if (!wide) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: theme.dialogSurface,
      builder: (_) => child,
    );
  }
  return showDialog<void>(
    context: context,
    barrierColor: theme.textPrimary.withOpacity(0.35),
    builder: (ctx) => Dialog(
      backgroundColor: theme.dialogSurface,
      surfaceTintColor: theme.dialogSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
        ),
        child: SingleChildScrollView(child: child),
      ),
    ),
  );
}

Future<void> showImporterSalesMetricSheet({
  required BuildContext context,
  required ImporterSalesSnapshot snapshot,
  required ImporterSalesMetricKind kind,
}) {
  return _showImporterPanel(
    context,
    _SalesMetricSheet(snapshot: snapshot, kind: kind),
  );
}

Future<void> showImporterSalesSkuSheet({
  required BuildContext context,
  required ImporterSalesSnapshot snapshot,
  required ImporterSalesProductStat product,
  required bool lowRotation,
}) {
  return _showImporterPanel(
    context,
    _SalesSkuSheet(
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
    final theme = B2BThemeExtension.of(context);
    final preview = spec.breakdown.take(3).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        8,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetHeader(context, spec.title, spec.subtitle),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                for (var i = 0; i < spec.stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _FactChip(
                      label: spec.stats[i].$1,
                      value: spec.stats[i].$2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                spec.breakdownTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: theme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final row in preview)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: _ShareRow(
                  name: row.$1,
                  trailing: row.$2,
                  fraction: row.$3,
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 4),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < spec.actions.length; i++)
                  _actionButton(context, spec.actions[i], primary: i == 0),
              ],
            ),
          ),
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
              'Aún sin entregar ni cancelar, últimos $days días.',
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
          subtitle: 'Cierres de los últimos $days días.',
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
              'Cantidades pedidas, sin cancelados, últimos $days días.',
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
              'REF de pedidos no cancelados, últimos $days días.',
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
    final theme = B2BThemeExtension.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        8,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sheetHeader(
            context,
            product.name,
            lowRotation
                ? 'Rotación, últimos ${snapshot.days} días'
                : 'Desempeño, últimos ${snapshot.days} días',
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: _FactChip(
                    label: 'Unidades',
                    value: '${product.units}',
                  ),
                ),
                if (!lowRotation || product.revenue > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FactChip(
                      label: 'Facturado',
                      value: '${formatRefAmount(product.revenue)} REF',
                    ),
                  ),
                ],
                if (!lowRotation && snapshot.revenueRef > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FactChip(
                      label: 'Del período',
                      value: '${(share * 100).toStringAsFixed(0)}%',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (product.units == 0) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Sin pedidos en el período. Revisa precio, foto o visibilidad.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: theme.textSecondary,
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: _actionButton(
                context,
                _SheetAction(
                  label: lowRotation ? 'Ver poca rotación' : 'Ver más vendidos',
                  icon: Icons.list_alt_outlined,
                  onPressed: (ctx) => showImporterSalesProductSheet(
                    context: ctx,
                    kind: lowRotation ? 'low' : 'top',
                    days: snapshot.days,
                  ),
                ),
                primary: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _sheetHeader(BuildContext context, String title, String subtitle) {
  final theme = B2BThemeExtension.of(context);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Cerrar',
        visualDensity: VisualDensity.compact,
        onPressed: () => Navigator.of(context).maybePop(),
        icon: Icon(Icons.close, size: 18, color: theme.textSecondary),
      ),
    ],
  );
}

Widget _actionButton(
  BuildContext context,
  _SheetAction action, {
  required bool primary,
}) {
  final theme = B2BThemeExtension.of(context);
  void run() {
    Navigator.of(context).pop();
    action.onPressed(context);
  }

  final style = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 14),
    ),
    foregroundColor: primary
        ? null
        : WidgetStatePropertyAll(theme.textSecondary),
    side: primary
        ? null
        : WidgetStatePropertyAll(BorderSide(color: theme.borderSubtle)),
    shape: const WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
  );
  final icon = Icon(action.icon, size: 18);
  final label = Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis);
  if (primary) {
    return FilledButton.icon(
      onPressed: run,
      style: style,
      icon: icon,
      label: label,
    );
  }
  return OutlinedButton.icon(
    onPressed: run,
    style: style,
    icon: icon,
    label: label,
  );
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
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
              ),
            ),
          ],
        ),
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
    final theme = B2BThemeExtension.of(context);
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
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary,
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
            backgroundColor: theme.borderSubtle,
            color: theme.brand,
          ),
        ),
      ],
    );
  }
}
