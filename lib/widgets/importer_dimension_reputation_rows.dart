import 'package:flutter/material.dart';

import '../models/rating_dimension_stat_model.dart';
import '../models/rating_questionnaire_model.dart';
import '../theme/app_theme.dart';
import '../utils/rating_scale_labels.dart';
import 'aliado_order_experience_display.dart';

/// Filas de reputación por categoría (Calidad, Despacho, …).
class ImporterDimensionReputationRows extends StatelessWidget {
  const ImporterDimensionReputationRows({
    super.key,
    required this.questionnaire,
    required this.dimensionStats,
    this.compact = false,
  });

  final RatingQuestionnaireModel questionnaire;
  final Map<String, RatingDimensionStatModel> dimensionStats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final q in questionnaire.questions) {
      final stat = dimensionStats[q.id];
      if (stat == null) continue;
      if (rows.isNotEmpty) {
        rows.add(SizedBox(height: compact ? 8 : 10));
      }
      rows.add(_DimensionRow(question: q, stat: stat, compact: compact));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.question,
    required this.stat,
    required this.compact,
  });

  final RatingQuestionModel question;
  final RatingDimensionStatModel stat;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final avg = stat.average.clamp(1.0, 5.0);
    final label = ratingValueLabelEs(avg.round());
    final subtitle = question.displaySubtitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.displayTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 12 : 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: compact ? 9.5 : 10,
                        height: 1.3,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  avg.toStringAsFixed(1),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 14 : 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 9 : 9.5,
                    fontWeight: FontWeight.w600,
                    color: ratingValueColor(avg.round()),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (avg - 1) / 4,
            minHeight: compact ? 5 : 6,
            backgroundColor: Colors.grey.shade200,
            color: ratingValueColor(avg.round()),
          ),
        ),
        const SizedBox(height: 3),
        AliadoExperienceStarsRow(
          stars: avg.round().clamp(1, 5),
          size: compact ? 14 : 16,
        ),
      ],
    );
  }
}
