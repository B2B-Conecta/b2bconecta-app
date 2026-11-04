import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

class ImporterPriorityAction {
  const ImporterPriorityAction({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? iconColor;
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
    final card = Semantics(
        label: '${action.value} ${action.label}',
        button: action.onTap != null,
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: action.onTap,
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Padding(
                padding: EdgeInsets.all(compact ? 16 : 10),
                child: compact
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Row(children: [
                              ExcludeSemantics(
                                  child: Icon(action.icon,
                                      color: action.iconColor ??
                                          AppColors.brandLink,
                                      size: 24)),
                              const SizedBox(width: 12),
                              Flexible(
                                  child: ExcludeSemantics(
                                      child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(action.value,
                                              style: TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors
                                                      .textPrimary))))),
                            ]),
                            const SizedBox(height: 6),
                            ExcludeSemantics(
                                child: Text(action.label,
                                    style: TextStyle(
                                        fontSize: 13,
                                        height: 1.3,
                                        color: AppColors.textSecondary))),
                          ])
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExcludeSemantics(
                              child: Icon(action.icon,
                                  color:
                                      action.iconColor ?? AppColors.brandLink,
                                  size: 20)),
                          const SizedBox(height: 6),
                          ExcludeSemantics(
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    action.value,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ))),
                          const SizedBox(height: 4),
                          ExcludeSemantics(
                              child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Text(
                                    action.label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                      height: 1.2,
                                    ),
                                  ))),
                        ],
                      ),
              ),
            ),
          ),
        ));
    return action.tooltip == null
        ? card
        : Tooltip(message: action.tooltip!, child: card);
  }
}
