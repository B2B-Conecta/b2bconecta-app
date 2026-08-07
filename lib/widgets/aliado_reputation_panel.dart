import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../models/aliado_received_rating_model.dart';
import '../models/profile_model.dart';
import '../models/rating_dimension_stat_model.dart';
import '../models/rating_questionnaire_model.dart';
import '../services/supabase_service.dart';
import '../utils/app_date_format.dart';
import '../utils/rating_dimension_summary.dart';
import 'importer_dimension_reputation_rows.dart';
import 'order_rating_form.dart';
import 'profile_section_helpers.dart';
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

  String _reputationSubtitle(int cnt, double? avg, bool hasDimensions) {
    if (_loading) return 'Cargando…';
    if (cnt == 0) return 'Sin valoraciones todavía';
    if (avg != null) {
      return 'Promedio ${avg.toStringAsFixed(1)} · $cnt valoraciones';
    }
    return hasDimensions ? '$cnt valoraciones' : '$cnt valoraciones';
  }

  String _commentsSubtitle() {
    if (_loading) return 'Cargando…';
    if (_ratings.isEmpty) return 'Sin comentarios';
    if (_ratings.length == 1) return '1 comentario';
    return '${_ratings.length} comentarios';
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
        ProfileCollapsibleSection(
          title: 'Reputación',
          subtitle: _reputationSubtitle(cnt, avg, hasDimensions),
          initiallyExpanded: hasDimensions,
          infoMessage: 'Últimas 100 valoraciones de importadores.',
          child: _reputationBody(
            cnt: cnt,
            hasDimensions: hasDimensions,
            questionnaire: questionnaire,
            dimensionStats: dimensionStats,
          ),
        ),
        const SizedBox(height: 12),
        ProfileCollapsibleSection(
          title: 'Comentarios',
          subtitle: _commentsSubtitle(),
          initiallyExpanded: false,
          infoMessage: 'Anónimos · solo ciudad',
          trailingActions: [
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Actualizar',
              visualDensity: VisualDensity.compact,
            ),
          ],
          child: _commentsBody(),
        ),
      ],
    );
  }

  Widget _reputationBody({
    required int cnt,
    required bool hasDimensions,
    required RatingQuestionnaireModel? questionnaire,
    required Map<String, RatingDimensionStatModel> dimensionStats,
  }) {
    if (_loading && !hasDimensions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (hasDimensions && questionnaire != null) {
      return ImporterDimensionReputationRows(
        questionnaire: questionnaire,
        dimensionStats: dimensionStats,
        compact: true,
      );
    }
    if (cnt > 0) {
      return Text(
        'Sin desglose por categoría',
        style: TextStyle(
          fontSize: 12,
          height: 1.35,
          color: AppColors.textSecondary,
        ),
      );
    }
    return Text(
      'Sin valoraciones aún',
      style: TextStyle(
        fontSize: 12,
        height: 1.35,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _commentsBody() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_error != null) {
      return Text(
        _error!,
        style: TextStyle(color: Colors.red.shade800, fontSize: 12),
      );
    }
    if (_ratings.isEmpty) {
      return Text(
        'Sin comentarios todavía.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }
    return ReceivedRatingsCarousel(
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
    );
  }
}
