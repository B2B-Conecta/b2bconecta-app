import 'package:flutter/material.dart';

import '../models/importador_received_rating_model.dart';
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

/// Reputación del importador por categoría y comentarios anónimos de aliados.
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
        SupabaseService.listImportadorReceivedRatings(limit: 100),
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

  String _reputationSubtitle(int cnt, bool hasDimensions) {
    if (_loading) return 'Cargando…';
    if (cnt == 0) return 'Sin valoraciones todavía';
    if (hasDimensions) return '$cnt valoraciones · últimas 100';
    return '$cnt valoraciones';
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
    final cnt =
        p.ratingCountReceivedRolling100 ?? p.ratingCountReceived ?? 0;
    final questionnaire = _questionnaire;
    final dimensionStats = resolveImporterDimensionStats(
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
          title: 'Reputación en MotoLink',
          subtitle: _reputationSubtitle(cnt, hasDimensions),
          initiallyExpanded: hasDimensions,
          infoMessage:
              'Desglose por categoría (escala 1–5) según valoraciones de aliados. '
              'Mejorar estas métricas aumenta su visibilidad en el catálogo.',
          child: _reputationBody(
            cnt: cnt,
            hasDimensions: hasDimensions,
            questionnaire: questionnaire,
            dimensionStats: dimensionStats,
          ),
        ),
        const SizedBox(height: 12),
        ProfileCollapsibleSection(
          title: 'Comentarios de clientes',
          subtitle: _commentsSubtitle(),
          initiallyExpanded: false,
          infoMessage:
              'Comentarios anónimos (solo ciudad del aliado). '
              'Úselos para mejorar catálogo y despacho.',
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
        'Las valoraciones aún no incluyen desglose por categoría. '
        'Las nuevas mostrarán Calidad, Despacho, Empaque, Comunicación y Socio B2B.',
        style: TextStyle(
          fontSize: 11,
          height: 1.4,
          color: Colors.grey.shade800,
        ),
      );
    }
    return Text(
      'Aún no tiene valoraciones. Los talleres calificarán su servicio al cerrar pedidos entregados.',
      style: TextStyle(
        fontSize: 11.5,
        height: 1.35,
        color: Colors.grey.shade800,
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
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
          authorLabel: r.aliadoLabel,
          submittedAtLabel: label,
          answers: r.answers,
          questionnaire: _questionnaire,
        );
      },
    );
  }
}
