import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'importer_onboarding_checklist.dart';

class ImporterOnboardingChecklistCard extends StatefulWidget {
  const ImporterOnboardingChecklistCard({
    super.key,
    required this.checklist,
    required this.onOpenProfile,
    required this.onAddProduct,
  });

  final ImporterOnboardingChecklist checklist;
  final VoidCallback onOpenProfile;
  final VoidCallback onAddProduct;

  @override
  State<ImporterOnboardingChecklistCard> createState() =>
      _ImporterOnboardingChecklistCardState();
}

class _ImporterOnboardingChecklistCardState
    extends State<ImporterOnboardingChecklistCard> {
  bool _open = false;

  void _openStep(ImporterOnboardingStep step) {
    if (step.title == 'Cargar el primer producto' ||
        step.title == 'Publicar el catálogo') {
      widget.onAddProduct();
      return;
    }
    widget.onOpenProfile();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final checklist = widget.checklist;
    if (checklist.isComplete) return const SizedBox.shrink();
    final pending = checklist.steps.where((step) => !step.done);
    final next = pending.isEmpty ? null : pending.first;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Configuración de tienda',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${checklist.doneCount} de ${checklist.total}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.brand,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.rotate(
                        angle: _open ? 3.1416 : 0,
                        child: LucideIcon(
                          LucideGlyph.chevronDown,
                          size: 18,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Siguiente: ${next.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: checklist.progress,
                      minHeight: 6,
                      backgroundColor: theme.brandContainer,
                      color: theme.brand,
                    ),
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: theme.brand,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => _openStep(next),
                        child: const Text('Completar paso'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Column(
                children: [
                  for (final step in checklist.steps)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: LucideIcon(
                        step.done
                            ? LucideGlyph.circleCheck
                            : LucideGlyph.circle,
                        size: 18,
                        color: step.done ? theme.successFg : theme.brand,
                      ),
                      title: Text(
                        step.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        step.detail,
                        style: TextStyle(color: theme.textSecondary),
                      ),
                      onTap: () => _openStep(step),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
