import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

class ImporterPriorityAction {
  const ImporterPriorityAction({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.iconColor,
    this.glyph,
    this.cta,
    this.footnote,
    this.attention = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? iconColor;
  final LucideGlyph? glyph;
  final String? cta;
  final String? footnote;

  /// Resalta el valor cuando hay trabajo pendiente.
  final bool attention;
}

/// Accesos del panel del importador. El valor "—" se usa si el conteo falló.
class ImporterPriorityActions extends StatelessWidget {
  const ImporterPriorityActions({super.key, required this.actions});

  final List<ImporterPriorityAction> actions;

  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (actions.isEmpty) return const SizedBox.shrink();
                const gap = 10.0;
                final tileWidth =
                    (constraints.maxWidth - gap * (actions.length - 1)) /
                        actions.length;
                // Las tres comparten altura y crecen si el texto ampliado lo requiere.
                return IntrinsicHeight(
                    child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      Expanded(
                          child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: tileWidth),
                              child: ImporterPriorityCard(action: actions[i]))),
                    ],
                  ],
                ));
              },
            )));
  }
}

class ImporterPriorityCard extends StatelessWidget {
  const ImporterPriorityCard(
      {super.key, required this.action, this.compact = false});

  final ImporterPriorityAction action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final accent = action.iconColor ?? theme.brand;
    final valueColor = action.attention ? theme.brand : theme.textPrimary;
    final footnoteColor = action.footnote == 'Al día'
        ? theme.successFg
        : theme.textSecondary;
    Widget glyph() {
      final icon = action.glyph == null
          ? Icon(action.icon, color: accent, size: compact ? 22 : 20)
          : LucideIcon(action.glyph!, size: compact ? 20 : 18, color: accent);
      return ExcludeSemantics(child: icon);
    }

    Widget valueText(double size) => ExcludeSemantics(
          child: Text(
            action.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w800,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          glyph(),
          const SizedBox(width: 8),
          Flexible(child: valueText(compact ? 26 : 24)),
          if (action.attention) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.brandContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Urgente',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: theme.brand,
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Text(
          action.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 13 : 12,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: theme.textSecondary,
          ),
        ),
        if (action.footnote != null) ...[
          const SizedBox(height: 4),
          Text(
            action.footnote!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: footnoteColor,
            ),
          ),
        ],
        if (action.cta != null) ...[
          const SizedBox(height: 6),
          Text(
            action.cta!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.brand,
            ),
          ),
        ],
      ],
    );

    final card = Semantics(
      label: '${action.value} ${action.label}',
      button: action.onTap != null,
      child: Material(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: action.onTap,
          hoverColor: theme.brand.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.borderSubtle),
            ),
            child: Padding(
              padding: EdgeInsets.all(compact ? 14 : 10),
              child: body,
            ),
          ),
        ),
      ),
    );
    return action.tooltip == null
        ? card
        : Tooltip(message: action.tooltip!, child: card);
  }
}
