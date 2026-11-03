import 'package:flutter/material.dart';
import 'order_list_colors.dart';

class OrderDetailColumns extends StatelessWidget {
  const OrderDetailColumns(
      {super.key,
      required this.primary,
      required this.secondary,
      this.mobileOrder});
  final List<Widget> primary;
  final List<Widget> secondary;
  final List<Widget>? mobileOrder;

  Widget _stack(List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ]
        ],
      );

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 900 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return _stack(mobileOrder ?? [...primary, ...secondary]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: _stack(primary)),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: _stack(secondary)),
        ]);
      });
}

class OrderDetailSection extends StatelessWidget {
  const OrderDetailSection(
      {super.key,
      required this.title,
      required this.child,
      this.icon,
      this.tonal = false,
      this.flat = false});
  final String title;
  final Widget child;
  final IconData? icon;
  final bool tonal;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final colors = OrderListColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tonal ? colors.soft : colors.surface,
        border: flat || tonal ? null : Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 19, color: colors.accent),
            const SizedBox(width: 9)
          ],
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.ink))),
        ]),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }
}
