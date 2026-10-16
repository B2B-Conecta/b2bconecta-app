import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final checklist = widget.checklist;
    if (checklist.isComplete) return const SizedBox.shrink();
    final pending = checklist.steps.where((step) => !step.done);
    final next = pending.isEmpty ? null : pending.first.title;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
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
                          'Inicio rápido',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${checklist.doneCount} de ${checklist.total}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                      Icon(
                        _open ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  if (!_open && next != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Siguiente: $next',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: checklist.progress,
                      minHeight: 6,
                      backgroundColor: AppColors.brandBlueContainer,
                      color: AppColors.brand,
                    ),
                  ),
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
                      leading: Icon(
                        step.done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: step.done
                            ? AppColors.successGreen
                            : AppColors.brand,
                      ),
                      title: Text(
                        step.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(step.detail),
                      onTap: step.title == 'Cargar el primer producto' ||
                              step.title == 'Publicar el catálogo'
                          ? widget.onAddProduct
                          : widget.onOpenProfile,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
