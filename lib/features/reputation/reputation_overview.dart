import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

import 'order_rating_form.dart';
import 'rating_dimension_summary.dart';
import 'rating_dimension_stat_model.dart';
import 'rating_questionnaire_model.dart';
import 'reputation_weekly_snapshot_model.dart';

typedef _Review = ({
  String author,
  String comment,
  int stars,
  DateTime? date,
  Map<String, dynamic> answers,
});

typedef _ReviewData = ({
  RatingQuestionnaireModel questionnaire,
  Map<String, RatingDimensionStatModel> dimensions,
  List<_Review> reviews,
});

String _score(double value) => value.toStringAsFixed(1).replaceAll('.', ',');

class ReputationOverview extends StatefulWidget {
  const ReputationOverview({
    super.key,
    required this.profile,
    required this.isImporter,
    required this.showHeading,
    required this.onProfileRefresh,
  });

  final ProfileModel profile;
  final bool isImporter;
  final bool showHeading;
  final Future<void> Function() onProfileRefresh;

  @override
  State<ReputationOverview> createState() => _ReputationOverviewState();
}

class _ReputationOverviewState extends State<ReputationOverview> {
  late Future<_ReviewData> _reviews;
  late Future<List<ReputationWeeklySnapshotModel>> _weeks;
  int _visibleReviews = 3;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReputationOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!_refreshing && oldWidget.profile != widget.profile) ||
        oldWidget.isImporter != widget.isImporter) {
      _load();
    }
  }

  void _load() {
    _reviews = _loadReviews();
    _weeks = SupabaseService.listMyReputationWeeklySnapshots(limit: 8);
  }

  Future<_ReviewData> _loadReviews() async {
    final importer = widget.isImporter;
    final profile = widget.profile;
    final questionnaire = await SupabaseService.fetchRatingQuestionnaire(
      audience: importer ? 'aliado_rates_importer' : 'importer_rates_aliado',
    );
    if (importer) {
      final ratings =
          await SupabaseService.listImportadorReceivedRatings(limit: 100);
      return (
        questionnaire: questionnaire,
        dimensions: resolveImporterDimensionStats(
          profile: profile,
          questionnaire: questionnaire,
          ratings: ratings,
        ),
        reviews: [
          for (final rating in ratings)
            (
              author: rating.aliadoLabel,
              comment: rating.comment,
              stars: rating.overallStars,
              date: rating.submittedAt,
              answers: rating.answers
            ),
        ],
      );
    }
    final ratings = await SupabaseService.listAliadoReceivedRatings(limit: 100);
    return (
      questionnaire: questionnaire,
      dimensions: resolveAliadoDimensionStats(
        profile: profile,
        questionnaire: questionnaire,
        ratings: ratings,
      ),
      reviews: [
        for (final rating in ratings)
          (
            author: rating.importerLabel,
            comment: rating.comment,
            stars: rating.overallStars,
            date: rating.submittedAt,
            answers: rating.answers
          ),
      ],
    );
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await widget.onProfileRefresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se pudo actualizar la nota general.')),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _visibleReviews = 3;
      _load();
    });
    await Future.wait<void>([
      _reviews.then<void>((_) {}, onError: (Object _) {}),
      _weeks.then<void>((_) {}, onError: (Object _) {}),
    ]);
    if (mounted) setState(() => _refreshing = false);
  }

  void _showDetails(String title, Widget content) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: SizedBox(width: 480, child: content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _summary() {
    final profile = widget.profile;
    final rolling = widget.isImporter
        ? profile.ratingAvgReceivedRolling100
        : profile.ratingAsPayerAvgRolling100;
    final average = rolling ??
        (widget.isImporter
            ? profile.ratingAvgReceived
            : profile.ratingAsPayerAvg);
    final count = rolling != null
        ? (widget.isImporter
            ? profile.ratingCountReceivedRolling100
            : profile.ratingAsPayerCountRolling100)
        : (widget.isImporter
            ? profile.ratingCountReceived
            : profile.ratingAsPayerCount);
    final period =
        rolling != null ? 'Últimas 100 valoraciones' : 'Historial acumulado';
    return _ReputationCard(
      child: Wrap(
        spacing: 22,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded, size: 32, color: Color(0xFFF5A400)),
            const SizedBox(width: 8),
            Flexible(
                child: Text(
                    average == null ? 'Sin nota aún' : '${_score(average)} / 5',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800))),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                count == null
                    ? 'Valoraciones recibidas'
                    : count == 1
                        ? '1 valoración recibida'
                        : '$count valoraciones recibidas',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (average != null)
              Text(period, style: TextStyle(color: AppColors.textSecondary)),
          ]),
          TextButton(
            onPressed: () => _showDetails(
                'Cómo se calcula',
                Text(
                  'La nota general usa las valoraciones recibidas, en una escala de 1 a 5. '
                  'Se muestran hasta las últimas 100 cuando ese promedio está disponible. '
                  'Cada criterio tiene su propio promedio y el cierre semanal corresponde '
                  'solo a las valoraciones de esa semana.',
                  style: TextStyle(color: AppColors.textSecondary),
                )),
            child: const Text('Cómo se calcula'),
          ),
        ],
      ),
    );
  }

  Widget _criteria(AsyncSnapshot<_ReviewData> snapshot) {
    final data = snapshot.data;
    return _ReputationCard(
      title: 'Por criterio',
      child: data == null
          ? _loadState(snapshot.hasError)
          : data.dimensions.isEmpty
              ? const Text('Aún no hay puntuaciones por criterio.')
              : Column(children: [
                  for (final question in data.questionnaire.questions)
                    if (data.dimensions[question.id] case final stat?)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Expanded(flex: 5, child: Text(question.displayTitle)),
                          const SizedBox(width: 8),
                          Expanded(
                              flex: 4,
                              child: LinearProgressIndicator(
                                value: (stat.average / 5).clamp(0.0, 1.0),
                                semanticsLabel: question.displayTitle,
                                semanticsValue: '${_score(stat.average)} de 5',
                                minHeight: 5,
                                borderRadius: BorderRadius.circular(6),
                                color: Theme.of(context).colorScheme.primary,
                                backgroundColor: AppColors.fieldFill,
                              )),
                          const SizedBox(width: 10),
                          Text('${_score(stat.average)}/5',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                      ),
                ]),
    );
  }

  Widget _loadState(bool hasError) => hasError
      ? TextButton.icon(
          onPressed: _refreshing ? null : _refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('No se pudo cargar. Reintentar'))
      : const LinearProgressIndicator();

  Widget _weekly() => FutureBuilder(
        future: _weeks,
        builder: (context, snapshot) {
          final weeks = snapshot.data;
          final latest = weeks == null || weeks.isEmpty ? null : weeks.first;
          return _ReputationCard(
            title: 'Último cierre disponible',
            child: weeks == null
                ? _loadState(snapshot.hasError)
                : latest == null
                    ? const Text('Aún no hay cierres semanales.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(formatEsWeekRange(latest.weekStart),
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Text(
                                latest.avgOverall == null
                                    ? 'Sin promedio'
                                    : '${_score(latest.avgOverall!)} / 5',
                                style: const TextStyle(
                                    fontSize: 25, fontWeight: FontWeight.w800)),
                            Text(latest.ratingCount == 1
                                ? '1 valoración'
                                : '${latest.ratingCount} valoraciones'),
                            if (weeks.length > 1)
                              TextButton(
                                  onPressed: () => _showDetails(
                                        'Historial semanal',
                                        Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              for (final week in weeks)
                                                ListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(formatEsWeekRange(
                                                      week.weekStart)),
                                                  subtitle: Text(week
                                                              .ratingCount ==
                                                          1
                                                      ? '1 valoración'
                                                      : '${week.ratingCount} valoraciones'),
                                                  trailing: Text(week
                                                              .avgOverall ==
                                                          null
                                                      ? '—'
                                                      : '${_score(week.avgOverall!)} / 5'),
                                                ),
                                            ]),
                                      ),
                                  child: const Text('Ver historial')),
                          ]),
          );
        },
      );

  Widget _recent(AsyncSnapshot<_ReviewData> snapshot) {
    final data = snapshot.data;
    final reviews = [...?data?.reviews]..sort((a, b) {
        if (a.date == null) return b.date == null ? 0 : 1;
        return b.date == null ? -1 : b.date!.compareTo(a.date!);
      });
    return _ReputationCard(
      title: 'Valoraciones recientes',
      child: data == null
          ? _loadState(snapshot.hasError)
          : reviews.isEmpty
              ? Text(widget.isImporter
                  ? 'Aquí aparecerán las valoraciones de las tiendas minoristas.'
                  : 'Aquí aparecerán las valoraciones de tus proveedores.')
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final (index, review)
                      in reviews.take(_visibleReviews).indexed) ...[
                    if (index > 0)
                      Divider(height: 1, color: AppColors.borderSubtle),
                    _reviewRow(review, data.questionnaire),
                  ],
                  if (reviews.length > _visibleReviews)
                    TextButton(
                        onPressed: () => setState(() => _visibleReviews += 5),
                        child: const Text('Ver más valoraciones')),
                ]),
    );
  }

  Widget _reviewRow(_Review review, RatingQuestionnaireModel questionnaire) {
    final comment = review.comment.trim();
    final timestamp =
        review.date == null ? '' : formatEsShortDateTime(review.date);
    final metadata = [
      review.author,
      if (timestamp.isNotEmpty) timestamp.split(' ').first,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: Text('${review.stars}/5',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.isEmpty ? 'Sin comentario escrito' : comment,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.35,
                    color: comment.isEmpty
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(metadata,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (comment.isNotEmpty || review.answers.isNotEmpty)
            IconButton(
              tooltip: 'Ver detalle de la valoración',
              icon: const Icon(Icons.chevron_right, size: 20),
              color: AppColors.textSecondary,
              onPressed: () => _showDetails(
                'Detalle de la valoración',
                OrderRatingReceivedCard(
                  authorLabel: review.author,
                  overallStars: review.stars,
                  comment: comment,
                  submittedAtLabel: timestamp,
                  answers: review.answers,
                  questionnaire: questionnaire,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(wide ? 20 : 16, 8, wide ? 20 : 16, 24),
            children: [
              Row(children: [
                Expanded(
                    child: widget.showHeading
                        ? const Text('Reputación',
                            style: TextStyle(
                                fontSize: 21, fontWeight: FontWeight.w800))
                        : const SizedBox.shrink()),
                IconButton(
                    tooltip: 'Actualizar reputación',
                    onPressed: _refreshing ? null : _refresh,
                    icon: const Icon(Icons.refresh)),
              ]),
              _summary(),
              const SizedBox(height: 14),
              FutureBuilder(
                  future: _reviews,
                  builder: (context, snapshot) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (wide)
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: _criteria(snapshot)),
                                  const SizedBox(width: 14),
                                  Expanded(flex: 2, child: _weekly()),
                                ])
                          else
                            _criteria(snapshot),
                          const SizedBox(height: 14),
                          _recent(snapshot),
                          if (!wide) ...[const SizedBox(height: 14), _weekly()],
                        ],
                      )),
            ],
          ),
        );
      });
}

class _ReputationCard extends StatelessWidget {
  const _ReputationCard({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(14),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title case final label?) ...[
            Text(label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
          ],
          child,
        ]),
      );
}
