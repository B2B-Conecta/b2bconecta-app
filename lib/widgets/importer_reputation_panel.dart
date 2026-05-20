import 'package:flutter/material.dart';

import '../models/importador_received_rating_model.dart';
import '../models/profile_model.dart';
import '../models/rating_questionnaire_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import 'aliado_order_experience_display.dart';
import 'order_rating_form.dart';

/// Comentarios de clientes (aliados anónimos) y resumen de reputación del importador.
class ImporterReputationPanel extends StatefulWidget {
  const ImporterReputationPanel({
    super.key,
    required this.profile,
    this.onProfileRefresh,
  });

  final ProfileModel profile;
  final VoidCallback? onProfileRefresh;

  @override
  State<ImporterReputationPanel> createState() => _ImporterReputationPanelState();
}

class _ImporterReputationPanelState extends State<ImporterReputationPanel> {
  bool _loading = true;
  String? _error;
  List<ImportadorReceivedRatingModel> _ratings = const [];
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
        SupabaseService.listImportadorReceivedRatings(limit: 40),
        SupabaseService.fetchRatingQuestionnaire(audience: 'aliado_rates_importer'),
      ]);
      if (!mounted) return;
      setState(() {
        _ratings = results[0] as List<ImportadorReceivedRatingModel>;
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
    final avg = p.ratingAvgReceived;
    final cnt = p.ratingCountReceived ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: AppColors.brandBlueContainer.withOpacity(0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.brandBlue.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reputación en MotoLink',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              if (cnt > 0 && avg != null) ...[
                Row(
                  children: [
                    AliadoExperienceStarsRow(
                      stars: avg.round().clamp(1, 5),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${avg.toStringAsFixed(1)} / 5 · $cnt valoraciones',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  avg >= 4.5
                      ? 'Excelente desempeño: prioridad en búsquedas del catálogo.'
                      : 'Las valoraciones de aliados mejoran su visibilidad en el catálogo.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Colors.grey.shade800,
                  ),
                ),
              ] else
                Text(
                  'Aún no tiene valoraciones de aliados. Al cerrar pedidos como entregados, '
                  'los talleres podrán calificar su servicio.',
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
                'Comentarios de clientes',
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
          'Los comentarios se muestran de forma anónima (ciudad del aliado, sin nombre comercial). '
          'Use el feedback para mejorar catálogo y despacho.',
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
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _ratings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = _ratings[i];
              final at = r.submittedAt;
              final label =
                  at != null ? formatEsShortDateTime(at) : '';
              return OrderRatingReceivedCard(
                overallStars: r.overallStars,
                comment: r.comment,
                authorLabel: r.aliadoLabel,
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
