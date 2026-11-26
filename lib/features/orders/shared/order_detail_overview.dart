import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'order_list_colors.dart';
import 'order_list_entry.dart';
import 'order_list_row.dart';
import 'transaction_request_model.dart';

/// Cabecera del detalle: ID, fecha, monto REF/USD + Bs BCV y siguiente paso.
class OrderDetailOverview extends StatelessWidget {
  const OrderDetailOverview(
      {super.key,
      required this.lines,
      required this.nextStep,
      required this.chatAction,
      this.viewerRole = AppHomeRole.aliado,
      this.actionsInHeader = false,
      this.compactRetailer = false,
      this.cancelAction});
  final List<TransactionRequestModel> lines;
  final String nextStep;
  final Widget? chatAction;
  final Widget? cancelAction;
  final AppHomeRole viewerRole;
  final bool actionsInHeader;
  final bool compactRetailer;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final entry = OrderListEntry(lines, viewerRole: viewerRole);
    if (compactRetailer) {
      return _retailerSummary(context, entry, OrderListColors.of(context));
    }
    final count = entry.products.length;
    final identity =
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: theme.brandContainer,
              borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.center,
          child: LucideIcon(
            LucideGlyph.shoppingBag,
            color: theme.brand,
            size: 20,
          )),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(entry.reference,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary)),
        const SizedBox(height: 3),
        Text(
            '$count ${count == 1 ? 'repuesto' : 'repuestos'} · ${entry.quantity} ${entry.quantity == 1 ? 'unidad' : 'unidades'}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.textSecondary)),
        const SizedBox(height: 3),
        Text(entry.date,
            style: TextStyle(fontSize: 12, color: theme.textMuted)),
      ])),
    ]);
    final amount =
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(entry.amount,
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -.3,
              color: theme.textPrimary)),
      const SizedBox(height: 4),
      _OrderBolivarLabel(lines: lines, theme: theme),
    ]);
    final note = nextStep.isEmpty
        ? const SizedBox.shrink()
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LucideIcon(
                entry.needsAttention
                    ? LucideGlyph.circleAlert
                    : LucideGlyph.clipboardCheck,
                size: 16,
                color: entry.needsAttention
                    ? Theme.of(context).colorScheme.error
                    : theme.brand),
            const SizedBox(width: 8),
            Expanded(
                child: Text(nextStep,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: entry.needsAttention
                            ? Theme.of(context).colorScheme.error
                            : theme.textSecondary))),
          ]);
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      if (chatAction != null) Flexible(child: chatAction!),
      if (cancelAction != null) ...[const SizedBox(width: 4), cancelAction!],
    ]);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
          color: theme.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.borderSubtle)),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 650 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                if (actionsInHeader)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: identity),
                    const SizedBox(width: 8),
                    actions,
                  ])
                else
                  identity,
                const SizedBox(height: 14),
                if (constraints.maxWidth >= 300 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 20)
                  Row(children: [
                    Expanded(
                        child: Align(
                            alignment: Alignment.centerLeft, child: amount)),
                    const SizedBox(width: 12),
                    Flexible(child: OrderStatusTag(entry: entry))
                  ])
                else ...[
                  Align(
                      alignment: Alignment.centerLeft,
                      child: OrderStatusTag(entry: entry)),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: amount),
                ],
              ] else
                Row(children: [
                  Expanded(flex: 3, child: identity),
                  const SizedBox(width: 20),
                  Expanded(
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: OrderStatusTag(entry: entry))),
                  const SizedBox(width: 28),
                  Expanded(flex: 2, child: amount),
                  if (actionsInHeader) ...[
                    const SizedBox(width: 12),
                    actions,
                  ],
                ]),
              if (!actionsInHeader || nextStep.isNotEmpty) ...[
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: theme.borderSubtle)),
                if (actionsInHeader)
                  note
                else if (nextStep.isEmpty)
                  Align(alignment: Alignment.centerRight, child: actions)
                else if (compact) ...[
                  note,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: actions),
                ] else
                  Row(children: [
                    Expanded(child: note),
                    const SizedBox(width: 20),
                    actions
                  ]),
              ],
            ]);
      }),
    );
  }

  Widget _retailerSummary(
    BuildContext context,
    OrderListEntry entry,
    OrderListColors colors,
  ) {
    final meta = TextStyle(fontSize: 12, color: colors.secondary, height: 1.25);
    final count = entry.products.length;
    final title = count > 1 ? '${entry.title} y ${count - 1} más' : entry.title;
    final quantity =
        '${entry.quantity} ${entry.quantity == 1 ? 'unidad' : 'unidades'}';
    final mixedCurrencies = orderHasMixedCurrencies(lines);
    final dollars =
        lines.where((line) => line.amountCurrencyLabel == 'USD').toList();
    final reference =
        lines.where((line) => line.amountCurrencyLabel == 'REF').toList();
    final amountLines = mixedCurrencies
        ? [
            orderAmountSummary(dollars),
            reference.every((line) => line.precioTotalBsUi != null)
                ? formatBsLabel(reference.fold<double>(
                    0, (sum, line) => sum + line.precioTotalBsUi!))
                : orderAmountSummary(reference)
          ]
        : [entry.amount];
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      if (chatAction != null) chatAction!,
      if (cancelAction != null) cancelAction!,
    ]);
    final heading =
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
          child: Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: colors.ink))),
      const SizedBox(width: 4),
      actions,
    ]);
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('$quantity · ${entry.date}', style: meta),
      const SizedBox(height: 5),
      LayoutBuilder(builder: (context, constraints) {
        final status = OrderStatusTag(entry: entry, compact: true);
        final amounts = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < amountLines.length; i++) ...[
                if (i > 0) const SizedBox(height: 3),
                Text(amountLines[i],
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.ink)),
              ],
              if (entry.bolivares case final amount?) Text(amount, style: meta),
            ]);
        if (mixedCurrencies) {
          if (constraints.maxWidth >= 275 &&
              MediaQuery.textScalerOf(context).scale(16) <= 18) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: status)),
              const SizedBox(width: 8),
              amounts,
            ]);
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: status),
                const SizedBox(height: 5),
                Align(alignment: Alignment.centerRight, child: amounts),
              ]);
        }
        return Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              status,
              amounts,
            ]);
      }),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
              color: colors.detailSurface,
              borderRadius: BorderRadius.circular(15)),
          padding: const EdgeInsets.all(9),
          child: LayoutBuilder(builder: (context, constraints) {
            final narrow = mixedCurrencies ||
                constraints.maxWidth < 310 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            if (narrow) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    const SizedBox(height: 4),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OrderThumbnail(entry: entry, size: 60),
                          const SizedBox(width: 9),
                          Expanded(child: details),
                        ]),
                  ]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              OrderThumbnail(entry: entry, size: 60),
              const SizedBox(width: 9),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [heading, details])),
            ]);
          }),
        ),
        if (nextStep.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
            child: Text(nextStep,
                style: meta.copyWith(
                    color: entry.needsAttention
                        ? Theme.of(context).colorScheme.error
                        : colors.secondary)),
          ),
      ],
    );
  }
}

/// Equivalente en Bs del total REF. En escritorio usa la tasa del pedido
/// o, si no está congelada, la tasa de referencia activa.
class _OrderBolivarLabel extends StatefulWidget {
  const _OrderBolivarLabel({required this.lines, required this.theme});

  final List<TransactionRequestModel> lines;
  final B2BThemeExtension theme;

  @override
  State<_OrderBolivarLabel> createState() => _OrderBolivarLabelState();
}

class _OrderBolivarLabelState extends State<_OrderBolivarLabel> {
  double? _liveRate;
  bool _loading = false;

  bool get _web =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;

  bool get _ref => orderAmountCurrency(widget.lines) == 'REF';

  double? get _frozen {
    if (!_ref || !widget.lines.every((line) => line.precioTotalBsUi != null)) {
      return null;
    }
    return widget.lines
        .fold<double>(0, (sum, line) => sum + line.precioTotalBsUi!);
  }

  @override
  void initState() {
    super.initState();
    _prime();
  }

  @override
  void didUpdateWidget(covariant _OrderBolivarLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lines != widget.lines) _prime();
  }

  void _prime() {
    if (_frozen != null || !_ref) return;
    final cached = BcvBasePrice.cachedRate;
    if (cached != null && cached > 0) {
      _liveRate = cached;
      _loading = false;
      return;
    }
    _loading = true;
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final rate = await BcvBasePrice.currentRate();
      if (!mounted) return;
      setState(() {
        _liveRate = rate;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frozen = _frozen;
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: widget.theme.textSecondary,
    );
    if (frozen != null) return Text(formatBsLabel(frozen), style: style);
    if (!_ref) return const SizedBox.shrink();
    if (!_web) {
      return Text('Bs —',
          style: style.copyWith(
              fontWeight: FontWeight.w500, color: widget.theme.textMuted));
    }
    final rate = _liveRate;
    if (rate == null || rate <= 0) {
      return Text(_loading ? 'Bs …' : 'Sin tasa vigente',
          style: style.copyWith(
              fontWeight: FontWeight.w500, color: widget.theme.textMuted));
    }
    final total = widget.lines.fold<double>(0, (sum, line) {
      return sum + (line.precioTotalBsUi ?? line.precioTotal * rate);
    });
    return Text(formatBsLabel(total), style: style);
  }
}
