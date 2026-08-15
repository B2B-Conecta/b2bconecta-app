import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'b2b_orders_panel_layout.dart';

/// Tarjeta uniforme para bloques de acción en fichas de pedido (web / móvil).
class B2bPanelSectionCard extends StatelessWidget {
  const B2bPanelSectionCard({
    super.key,
    this.child,
    this.tint,
    this.icon,
    this.title,
    this.subtitle,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget? child;
  final Color? tint;
  final IconData? icon;
  final String? title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  bool get _hasBody => child != null;

  @override
  Widget build(BuildContext context) {
    final density = B2bOrderCardDensityScope.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final maxW = B2bOrdersPanelLayout.expandedSectionMaxWidth(width);
    final radius = BorderRadius.circular(density.sectionBorderRadius);

    Widget card = Material(
      color: tint ?? AppColors.surfaceTinted,
      borderRadius: radius,
      child: Padding(
        padding: density.panelCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: density.panelCardIconSize, color: AppColors.brandBlue),
                    SizedBox(width: density.isDesktop ? 8 : 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: density.panelCardTitleSize,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (subtitle != null) ...[
                          SizedBox(height: density.isDesktop ? 2 : 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: density.panelCardSubtitleSize,
                              height: 1.35,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (_hasBody) SizedBox(height: density.isDesktop ? 8 : 10),
            ],
            if (_hasBody) child!,
          ],
        ),
      ),
    );

    if (maxW < width) {
      card = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: card,
        ),
      );
    }

    return card;
  }
}

/// Altura mínima uniforme para botones de acción en paneles B2B (móvil).
const Size kB2bActionButtonMinSize = Size(0, 44);

Size b2bActionButtonMinSize(BuildContext context) =>
    B2bOrderCardDensityScope.of(context).actionButtonMinSize;

/// Fila de botones primario / secundario con layout responsive.
class B2bActionButtonRow extends StatelessWidget {
  const B2bActionButtonRow({
    super.key,
    this.secondary,
    required this.primary,
    this.stackOnNarrow = true,
  });

  final Widget? secondary;
  final Widget primary;
  final bool stackOnNarrow;

  @override
  Widget build(BuildContext context) {
    final density = B2bOrderCardDensityScope.of(context);
    final horizontal = B2bOrdersPanelLayout.useHorizontalActionButtons(
      MediaQuery.sizeOf(context).width,
    );
    final gap = density.isDesktop ? 8.0 : 12.0;

    if (secondary == null) {
      return _stretchAction(primary);
    }

    if (horizontal && stackOnNarrow) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _stretchAction(secondary!)),
            SizedBox(width: gap),
            Expanded(child: _stretchAction(primary)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stretchAction(secondary!),
        const SizedBox(height: 8),
        _stretchAction(primary),
      ],
    );
  }

  static Widget _stretchAction(Widget button) {
    return SizedBox(
      width: double.infinity,
      child: button,
    );
  }
}
