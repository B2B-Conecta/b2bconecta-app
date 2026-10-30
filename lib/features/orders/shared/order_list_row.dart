import 'package:flutter/material.dart';
import 'order_list_colors.dart';
import 'order_list_entry.dart';

class OrderListColumnsHeader extends StatelessWidget {
  const OrderListColumnsHeader({
    super.key,
    this.partyLabel = 'Proveedor',
  });

  final String partyLabel;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: DefaultTextStyle(
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: colors.secondary),
        child: Row(children: [
          const Expanded(flex: 5, child: Text('Pedido')),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: Text(partyLabel)),
          const SizedBox(width: 16),
          const SizedBox(width: 176, child: Text('Estado del envío')),
          const SizedBox(width: 16),
          const SizedBox(
              width: 150, child: Text('Total', textAlign: TextAlign.right)),
          const SizedBox(width: 48),
        ]),
      ),
    );
  }
}

class OrderStatusTag extends StatelessWidget {
  const OrderStatusTag({super.key, required this.entry});
  final OrderListEntry entry;
  @override
  Widget build(BuildContext context) {
    final color = entry.statusColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(entry.statusIcon, size: 15, color: color),
        const SizedBox(width: 5),
        Flexible(
            child: Text(entry.status,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color))),
      ]),
    );
  }
}

class OrderListRow extends StatefulWidget {
  const OrderListRow(
      {super.key,
      required this.entry,
      required this.table,
      required this.selected,
      required this.onOpen});
  final OrderListEntry entry;
  final bool table;
  final bool selected;
  final VoidCallback onOpen;

  @override
  State<OrderListRow> createState() => _OrderListRowState();
}

class _OrderListRowState extends State<OrderListRow> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    final entry = widget.entry;
    final active = _hover || _focus || widget.selected;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final amount =
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(entry.amount,
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.ink,
              height: 1.25)),
      if (entry.bolivares != null) ...[
        const SizedBox(height: 4),
        Text(entry.bolivares!,
            style: TextStyle(fontSize: 12, color: colors.secondary)),
      ],
    ]);
    final identity =
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      _OrderThumbnail(entry: entry),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: colors.ink)),
        const SizedBox(height: 6),
        Text(
            '${entry.reference} · ${entry.products.length > 1 ? '${entry.products.length} productos · ' : ''}${entry.quantity} ${entry.quantity == 1 ? 'unidad' : 'unidades'}',
            style: TextStyle(fontSize: 12, color: colors.secondary)),
        if (widget.table) ...[
          const SizedBox(height: 4),
          Text(entry.date,
              style: TextStyle(fontSize: 11, color: colors.secondary)),
        ],
      ])),
    ]);
    final provider = Tooltip(
      message: entry.partyTooltip,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(entry.partyIcon, size: 16, color: colors.secondary),
        const SizedBox(width: 6),
        Expanded(
            child: Text(entry.provider,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: colors.secondary, height: 1.3))),
      ]),
    );
    final arrow = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
          color: active ? colors.accent.withOpacity(.12) : colors.soft,
          borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.arrow_forward_rounded, size: 17, color: colors.accent),
    );
    return Semantics(
      button: true,
      selected: widget.selected,
      label: 'Abrir pedido ${entry.reference}',
      child: AnimatedContainer(
        duration:
            reducedMotion ? Duration.zero : const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: active
              ? Color.alphaBlend(
                  colors.accent.withOpacity(.045), colors.surface)
              : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _focus
                  ? colors.accent
                  : active
                      ? colors.accent.withOpacity(.35)
                      : colors.border),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.onOpen,
            onHover: (value) => setState(() => _hover = value),
            onFocusChange: (value) => setState(() => _focus = value),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: widget.table
                  ? Row(children: [
                      Expanded(flex: 5, child: identity),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: provider),
                      const SizedBox(width: 16),
                      SizedBox(
                          width: 176,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OrderStatusTag(entry: entry),
                                if (entry.shippingPhase != null) ...[
                                  const SizedBox(height: 10),
                                  _ShippingMarks(entry: entry),
                                ],
                              ])),
                      const SizedBox(width: 16),
                      SizedBox(width: 150, child: amount),
                      const SizedBox(width: 16),
                      arrow,
                    ])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          Row(children: [
                            Flexible(child: OrderStatusTag(entry: entry)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(entry.date,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colors.secondary))),
                          ]),
                          const SizedBox(height: 14),
                          identity,
                          const SizedBox(height: 14),
                          LayoutBuilder(builder: (context, constraints) {
                            final stack = constraints.maxWidth < 340 ||
                                MediaQuery.textScalerOf(context).scale(14) > 19;
                            final end = Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Flexible(child: amount),
                                  const SizedBox(width: 12),
                                  arrow,
                                ]);
                            return stack
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                        provider,
                                        const SizedBox(height: 12),
                                        end
                                      ])
                                : Row(children: [
                                    Expanded(child: provider),
                                    const SizedBox(width: 12),
                                    Flexible(child: end)
                                  ]);
                          }),
                        ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderThumbnail extends StatelessWidget {
  const _OrderThumbnail({required this.entry});
  final OrderListEntry entry;
  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    final products = entry.products;
    final image = products.isEmpty ? null : products.first.imageUrl;
    final extra = products.length - 1;
    Widget fallback() => ColoredBox(
        color: colors.soft,
        child: Center(
            child: Icon(Icons.inventory_2_outlined,
                color: colors.accent.withOpacity(.65), size: 25)));
    return ExcludeSemantics(
        child: SizedBox(
      width: 60,
      height: 64,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
            bottom: 4,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border)),
              child: image == null
                  ? fallback()
                  : Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.network(image,
                          fit: BoxFit.contain,
                          cacheWidth: 144,
                          errorBuilder: (_, __, ___) => fallback())),
            )),
        if (extra > 0)
          Positioned(
              right: -4,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(5)),
                child: Text('+$extra',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.dark ? Colors.black : Colors.white)),
              )),
      ]),
    ));
  }
}

class _ShippingMarks extends StatelessWidget {
  const _ShippingMarks({required this.entry});
  final OrderListEntry entry;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
          child: SizedBox(
        width: 104,
        child: Row(children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
                child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: i <= entry.shippingPhase!
                            ? entry.statusColor(context)
                            : OrderListColors.of(context).border))),
          ]
        ]),
      ));
}
