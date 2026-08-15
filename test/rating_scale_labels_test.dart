import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/reputation/importador_received_rating_model.dart';
import 'package:motolink_pro_app/features/reputation/rating_questionnaire_model.dart';
import 'package:motolink_pro_app/features/reputation/rating_dimension_summary.dart';
import 'package:motolink_pro_app/features/reputation/rating_scale_labels.dart';

void main() {
  test('overallStarsFromDimensionAnswers uses rounded mean', () {
    expect(overallStarsFromDimensionAnswers([5, 5, 4, 4]), 5);
    expect(overallStarsFromDimensionAnswers([1, 5]), 3);
    expect(overallStarsFromDimensionAnswers([3, 3, 3]), 3);
  });

  test('computeDimensionAverages aggregates by question id', () {
    const q = RatingQuestionnaireModel(
      version: 'bucket_v2',
      questions: [
        RatingQuestionModel(
          id: 'product_quality',
          titleEs: 'Calidad',
          subtitleEs: 'Sub',
          required: true,
        ),
        RatingQuestionModel(
          id: 'dispatch_time',
          titleEs: 'Despacho',
          subtitleEs: 'Sub',
          required: true,
        ),
      ],
    );
    final ratings = [
      const ImportadorReceivedRatingModel(
        id: '1',
        overallStars: 4,
        comment: 'ok',
        answers: {'product_quality': 5, 'dispatch_time': 3},
        submittedAt: null,
        aliadoLabel: 'Aliado',
      ),
      const ImportadorReceivedRatingModel(
        id: '2',
        overallStars: 4,
        comment: 'ok',
        answers: {'product_quality': 3, 'dispatch_time': 5},
        submittedAt: null,
        aliadoLabel: 'Aliado',
      ),
    ];
    final avgs = computeDimensionAverages(
      questionnaire: q,
      ratings: ratings,
    );
    expect(avgs.length, 2);
    expect(avgs.firstWhere((e) => e.questionId == 'product_quality').average, 4.0);
    expect(avgs.firstWhere((e) => e.questionId == 'dispatch_time').average, 4.0);
  });
}
