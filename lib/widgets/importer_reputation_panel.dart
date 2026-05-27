import 'package:flutter/material.dart';

import '../models/importador_received_rating_model.dart';
import '../models/profile_model.dart';
import '../models/rating_questionnaire_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import '../utils/rating_dimension_summary.dart';
import 'importer_dimension_reputation_rows.dart';
import 'order_rating_form.dart';

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
              const SizedBox(height: 4),
              Text(
                'Desglose por categoría (escala 1–5).',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Colors.grey.shade800,
                ),
              ),
              if (cnt > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$cnt valoraciones de aliados · ventana últimas 100',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
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
                  'Las valoraciones registradas aún no incluyen desglose por categoría. '
                  'Las nuevas valoraciones con el formulario actual mostrarán Calidad, Despacho, Empaque, Comunicación y Socio B2B.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Colors.grey.shade800,
                  ),
                )
              else
                Text(
                  'Aún no tiene valoraciones de aliados. Al cerrar pedidos como entregados, '
                  'los talleres calificarán cada aspecto de su servicio.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Colors.grey.shade800,
                  ),
                ),
              if (hasDimensions) ...[
                const SizedBox(height: 10),
                Text(
                  'Mejorar estas categorías aumenta su visibilidad en el catálogo de aliados.',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.35,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
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
          _ImporterCommentsCarousel(
            ratings: _ratings,
            questionnaire: _questionnaire,
          ),
      ],
    );
  }
}

/// Carrusel horizontal de valoraciones recibidas (evita scroll largo en perfil).
class _ImporterCommentsCarousel extends StatefulWidget {
  const _ImporterCommentsCarousel({
    required this.ratings,
    required this.questionnaire,
  });

  final List<ImportadorReceivedRatingModel> ratings;
  final RatingQuestionnaireModel? questionnaire;

  @override
  State<_ImporterCommentsCarousel> createState() =>
      _ImporterCommentsCarouselState();
}

class _ImporterCommentsCarouselState extends State<_ImporterCommentsCarousel> {
  static const _carouselHeight = 360.0;

  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void didUpdateWidget(covariant _ImporterCommentsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ratings.length != widget.ratings.length) {
      _pageIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.ratings.length;
    final showPager = count > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPager) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _pageIndex > 0
                    ? () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        )
                    : null,
                icon: const Icon(Icons.chevron_left),
                visualDensity: VisualDensity.compact,
                tooltip: 'Anterior',
              ),
              Text(
                '${_pageIndex + 1} / $count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              IconButton(
                onPressed: _pageIndex < count - 1
                    ? () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        )
                    : null,
                icon: const Icon(Icons.chevron_right),
                visualDensity: VisualDensity.compact,
                tooltip: 'Siguiente',
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        SizedBox(
          height: _carouselHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: count,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemBuilder: (context, i) {
              final r = widget.ratings[i];
              final at = r.submittedAt;
              final label = at != null ? formatEsShortDateTime(at) : '';
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: OrderRatingReceivedCard(
                    overallStars: r.overallStars,
                    comment: r.comment,
                    authorLabel: r.aliadoLabel,
                    submittedAtLabel: label,
                    answers: r.answers,
                    questionnaire: widget.questionnaire,
                  ),
                ),
              );
            },
          ),
        ),
        if (showPager) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (i) {
              final active = i == _pageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 8 : 6,
                height: active ? 8 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.brandBlue
                      : Colors.grey.shade400,
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
