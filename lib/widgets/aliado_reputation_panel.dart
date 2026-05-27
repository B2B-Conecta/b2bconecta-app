import 'package:flutter/material.dart';

import '../models/aliado_received_rating_model.dart';
import '../models/profile_model.dart';
import '../models/rating_questionnaire_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import '../utils/rating_dimension_summary.dart';
import 'importer_dimension_reputation_rows.dart';
import 'order_rating_form.dart';
import 'received_ratings_carousel.dart';

/// Reputación del aliado (valorado por importadores) — pestaña dedicada E2.
class AliadoReputationPanel extends StatefulWidget {
  const AliadoReputationPanel({
    super.key,
    required this.profile,
    this.onProfileRefresh,
  });

  final ProfileModel profile;
  final VoidCallback? onProfileRefresh;

  @override
  State<AliadoReputationPanel> createState() => _AliadoReputationPanelState();
}

class _AliadoReputationPanelState extends State<AliadoReputationPanel> {
  bool _loading = true;
  String? _error;
  List<AliadoReceivedRatingModel> _ratings = const [];
  RatingQuestionnaireModel? _questionnaire;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        SupabaseService.listAliadoReceivedRatings(limit: 100),
        SupabaseService.fetchRatingQuestionnaire(
            audience: 'importer_rates_aliado'),
      ]);
      if (!mounted) return;
      setState(() {
        _ratings = results[0] as List<AliadoReceivedRatingModel>;
        _questionnaire = results[1] as RatingQuestionnaireModel;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final cnt = p.ratingAsPayerCountRolling100 ?? p.ratingAsPayerCount ?? 0;
    final avg = p.ratingAsPayerAvgRolling100 ?? p.ratingAsPayerAvg;
    final questionnaire = _questionnaire;
    final dimensionStats = resolveAliadoDimensionStats(
      profile: p,
      questionnaire: questionnaire,
      ratings: _ratings,
    );
    final hasDimensions = dimensionStats.isNotEmpty &&
        questionnaire != null &&
        questionnaire.questions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reputación como aliado',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Colors.teal.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Valoraciones de importadores sobre su taller (Comunicación y Pagos).',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Colors.grey.shade800,
                ),
              ),
              if (cnt > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$cnt valoraciones · ventana últimas 100',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (avg != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Promedio global: ${avg.toStringAsFixed(1)} / 5',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              if (_loading && !hasDimensions)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (hasDimensions)
                ImporterDimensionReputationRows(
                  questionnaire: questionnaire,
                  dimensionStats: dimensionStats,
                )
              else if (cnt > 0)
                Text(
                  'Aún no hay desglose por categoría en las valoraciones registradas.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Colors.grey.shade800,
                  ),
                )
              else
                Text(
                  'Cuando los importadores valoren pedidos entregados, verá aquí su reputación.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Colors.grey.shade800,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Comentarios de importadores',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Actualizar',
            ),
          ],
        ),
        Text(
          'Los importadores se muestran de forma anónima (solo ciudad).',
          style: TextStyle(fontSize: 11, height: 1.35, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_error != null)
          Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 12))
        else if (_ratings.isEmpty)
          Text(
            'Sin comentarios todavía.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          )
        else
          ReceivedRatingsCarousel(
            itemCount: _ratings.length,
            itemBuilder: (context, i) {
              final r = _ratings[i];
              final at = r.submittedAt;
              final label = at != null ? formatEsShortDateTime(at) : '';
              return OrderRatingReceivedCard(
                overallStars: r.overallStars,
                comment: r.comment,
                authorLabel: r.importerLabel,
                submittedAtLabel: label,
                answers: r.answers,
                questionnaire: _questionnaire,
              );
            },
          ),
      ],
    );
  }
}
