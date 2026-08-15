import 'aliado_received_rating_model.dart';
import 'importador_received_rating_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'rating_dimension_stat_model.dart';
import 'rating_questionnaire_model.dart';
import 'rating_scale_labels.dart';

/// Promedio por dimensión a partir de valoraciones recientes (UI, sin persistir en BD).
class RatingDimensionAverage {
  const RatingDimensionAverage({
    required this.questionId,
    required this.title,
    required this.average,
    required this.count,
  });

  final String questionId;
  final String title;
  final double average;
  final int count;
}

/// Calcula promedios por pregunta del cuestionario (solo respuestas 1–5 válidas).
List<RatingDimensionAverage> computeDimensionAverages({
  required RatingQuestionnaireModel questionnaire,
  required List<ImportadorReceivedRatingModel> ratings,
  int maxRatings = 100,
}) {
  if (!questionnaire.isBucketV2 || questionnaire.questions.isEmpty) {
    return const [];
  }

  final sums = <String, double>{};
  final counts = <String, int>{};
  var used = 0;

  for (final r in ratings) {
    if (used >= maxRatings) break;
    if (r.answers.isEmpty) continue;
    var any = false;
    for (final q in questionnaire.questions) {
      final v = r.answerFor(q.id);
      if (v == null || v < questionnaire.scaleMin || v > questionnaire.scaleMax) {
        continue;
      }
      sums[q.id] = (sums[q.id] ?? 0) + v;
      counts[q.id] = (counts[q.id] ?? 0) + 1;
      any = true;
    }
    if (any) used++;
  }

  final out = <RatingDimensionAverage>[];
  for (final q in questionnaire.questions) {
    final c = counts[q.id] ?? 0;
    if (c == 0) continue;
    out.add(
      RatingDimensionAverage(
        questionId: q.id,
        title: q.displayTitle,
        average: (sums[q.id]! / c),
        count: c,
      ),
    );
  }
  return out;
}

String formatDimensionAverageLine(RatingDimensionAverage d) {
  final rounded = d.average.toStringAsFixed(1);
  final label = ratingValueLabelEs(d.average.round().clamp(1, 5));
  return '${d.title}: $rounded ($label) · ${d.count} val.';
}

/// Prioriza agregados en perfil (BD); si no hay, calcula desde valoraciones recientes.
Map<String, RatingDimensionStatModel> resolveImporterDimensionStats({
  required ProfileModel profile,
  required RatingQuestionnaireModel? questionnaire,
  required List<ImportadorReceivedRatingModel> ratings,
}) {
  if (profile.ratingDimensionsReceivedRolling100.isNotEmpty) {
    return profile.ratingDimensionsReceivedRolling100;
  }
  if (questionnaire == null || !questionnaire.isBucketV2) {
    return const {};
  }
  final avgs = computeDimensionAverages(
    questionnaire: questionnaire,
    ratings: ratings,
  );
  return {
    for (final d in avgs)
      d.questionId: RatingDimensionStatModel(
        average: d.average,
        count: d.count,
      ),
  };
}

List<RatingDimensionAverage> computeAliadoDimensionAverages({
  required RatingQuestionnaireModel questionnaire,
  required List<AliadoReceivedRatingModel> ratings,
  int maxRatings = 100,
}) {
  if (!questionnaire.isBucketV2 || questionnaire.questions.isEmpty) {
    return const [];
  }
  final adapted = ratings
      .map(
        (r) => ImportadorReceivedRatingModel(
          id: r.id,
          overallStars: r.overallStars,
          comment: r.comment,
          answers: r.answers,
          submittedAt: r.submittedAt,
          aliadoLabel: r.importerLabel,
        ),
      )
      .toList();
  return computeDimensionAverages(
    questionnaire: questionnaire,
    ratings: adapted,
  );
}

/// Agregados dimensionales del aliado (perfil BD o cálculo local).
Map<String, RatingDimensionStatModel> resolveAliadoDimensionStats({
  required ProfileModel profile,
  required RatingQuestionnaireModel? questionnaire,
  required List<AliadoReceivedRatingModel> ratings,
}) {
  if (profile.ratingDimensionsAsPayerRolling100.isNotEmpty) {
    return profile.ratingDimensionsAsPayerRolling100;
  }
  if (questionnaire == null || !questionnaire.isBucketV2) {
    return const {};
  }
  final avgs = computeAliadoDimensionAverages(
    questionnaire: questionnaire,
    ratings: ratings,
  );
  return {
    for (final d in avgs)
      d.questionId: RatingDimensionStatModel(
        average: d.average,
        count: d.count,
      ),
  };
}
