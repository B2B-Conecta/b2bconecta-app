import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';

/// Layout split-screen del detalle de pedido (~60 / 40).
class OrderDetailColumns extends StatelessWidget {
  const OrderDetailColumns({
    super.key,
    required this.primary,
    required this.secondary,
    this.mobileOrder,
    this.breakpoint = 720,
    this.gap = 10,
  });

  final List<Widget> primary;
  final List<Widget> secondary;
  final List<Widget>? mobileOrder;

  /// Ancho mínimo para 2 columnas (detalle admin suele vivir en panel estrecho).
  final double breakpoint;
  final double gap;

  Widget _stack(List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useStack = constraints.maxWidth < breakpoint ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        if (useStack) {
          return _stack(mobileOrder ?? [...primary, ...secondary]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _stack(primary)),
            SizedBox(width: gap + 4),
            Expanded(flex: 2, child: _stack(secondary)),
          ],
        );
      },
    );
  }
}

/// Sección / tarjeta del detalle (tokens [B2BThemeExtension]).
class OrderDetailSection extends StatelessWidget {
  const OrderDetailSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.tonal = false,
    this.flat = false,
    this.compact = true,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final bool tonal;
  final bool flat;

  /// Padding y tipografía más densos (detalle admin compacto).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final pad = compact ? 14.0 : 20.0;
    final titleSize = compact ? 13.5 : 15.0;
    final gapAfterTitle = compact ? 10.0 : 16.0;

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: tonal ? theme.surfaceSubtle : theme.surfaceCard,
        border: flat || tonal
            ? null
            : Border.all(color: theme.borderSubtle),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 17 : 19, color: theme.brand),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: gapAfterTitle),
          child,
        ],
      ),
    );
  }
}
