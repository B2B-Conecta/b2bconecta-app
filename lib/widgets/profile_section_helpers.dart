import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/b2b_orders_panel_layout.dart';

/// Icono (i) que muestra ayuda breve en un diálogo.
class ProfileInfoIcon extends StatelessWidget {
  const ProfileInfoIcon({
    super.key,
    required this.message,
    this.title = 'Información',
    this.iconSize = 18,
  });

  final String message;
  final String title;
  final double iconSize;

  Future<void> _show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: 'Más información',
      onPressed: () => _show(context),
      icon: Icon(
        Icons.info_outline,
        size: iconSize,
        color: AppColors.textSecondary,
      ),
    );
  }
}

/// Encabezado de sección del perfil B2B con ayuda opcional.
class ProfileSectionHeader extends StatelessWidget {
  const ProfileSectionHeader({
    super.key,
    required this.label,
    this.infoMessage,
    this.infoTitle,
    this.padding = const EdgeInsets.only(bottom: 8, top: 4),
  });

  final String label;
  final String? infoMessage;
  final String? infoTitle;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (infoMessage != null)
            ProfileInfoIcon(
              title: infoTitle ?? label,
              message: infoMessage!,
            ),
        ],
      ),
    );
  }
}

/// Bloque colapsable con borde suave para secciones largas del perfil.
class ProfileCollapsibleSection extends StatefulWidget {
  const ProfileCollapsibleSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
    this.infoMessage,
    this.infoTitle,
    this.trailingActions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool initiallyExpanded;
  final String? infoMessage;
  final String? infoTitle;
  final List<Widget> trailingActions;

  @override
  State<ProfileCollapsibleSection> createState() =>
      _ProfileCollapsibleSectionState();
}

class _ProfileCollapsibleSectionState extends State<ProfileCollapsibleSection> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant ProfileCollapsibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_open && widget.initiallyExpanded && !oldWidget.initiallyExpanded) {
      _open = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // En fichas de pedido usa densidad compacta; en perfil (sin scope) usa aire usable.
    final orderDensity = B2bOrderCardDensityScope.maybeOf(context);
    final compact = orderDensity != null;
    final radius = BorderRadius.circular(compact ? 8 : 14);
    final mobileForm = !compact && MediaQuery.sizeOf(context).width < 600;
    final headerPad = orderDensity?.sectionHeaderPadding ??
        (mobileForm
            ? const EdgeInsets.fromLTRB(14, 12, 10, 12)
            : const EdgeInsets.fromLTRB(16, 14, 12, 14));
    final bodyPad = orderDensity?.sectionBodyPadding ??
        (mobileForm
            ? const EdgeInsets.fromLTRB(14, 4, 14, 14)
            : const EdgeInsets.fromLTRB(16, 4, 16, 16));
    final titleSize =
        orderDensity?.sectionTitleSize ?? (mobileForm ? 14.5 : 15.0);
    final subtitleSize =
        orderDensity?.sectionSubtitleSize ?? (mobileForm ? 12.0 : 12.5);

    return Material(
      color: AppColors.card,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              borderRadius: radius,
              child: Padding(
                padding: headerPad,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: subtitleSize,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.infoMessage != null)
                      ProfileInfoIcon(
                        message: widget.infoMessage!,
                        title: widget.infoTitle ?? widget.title,
                        iconSize: compact ? 16 : 18,
                      ),
                    ...widget.trailingActions,
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: compact ? 20 : 24,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (_open) ...[
              Divider(height: 1, thickness: 1, color: AppColors.divider),
              Padding(
                padding: bodyPad,
                child: widget.child,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
