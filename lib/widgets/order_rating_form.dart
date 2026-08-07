import 'package:flutter/material.dart';

import '../models/rating_questionnaire_model.dart';
import '../theme/app_theme.dart';
import '../utils/rating_scale_labels.dart';
import 'aliado_order_experience_display.dart';
import 'rating_dimension_slider.dart';

/// Valoración post-entrega (bucket v2): sliders por dimensión + comentario.
class OrderRatingForm extends StatefulWidget {
  const OrderRatingForm({
    super.key,
    required this.title,
    required this.subtitle,
    required this.questionnaire,
    required this.onSubmit,
    this.busy = false,
    this.emphasized = false,
    this.initialComment = '',
    this.cancellationReasonBanner,
  });

  final String title;
  final String subtitle;
  final RatingQuestionnaireModel questionnaire;
  final Future<void> Function({
    required int stars,
    required String comment,
    required Map<String, int> dimensionAnswers,
  }) onSubmit;
  final bool busy;

  /// Estilo más visible en modal / sheet de valoración.
  final bool emphasized;

  /// Comentario inicial (p. ej. motivo de cancelación).
  final String initialComment;

  /// Texto destacado con el motivo de cancelación (si aplica).
  final String? cancellationReasonBanner;

  @override
  State<OrderRatingForm> createState() => _OrderRatingFormState();
}

class _OrderRatingFormState extends State<OrderRatingForm> {
  late final TextEditingController _commentCtrl;
  late Map<String, int> _answers;

  RatingQuestionnaireModel get _q => widget.questionnaire;

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController(text: widget.initialComment);
    _answers = _defaultAnswersFor(_q);
  }

  @override
  void didUpdateWidget(covariant OrderRatingForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.questionnaire.version != widget.questionnaire.version ||
        oldWidget.questionnaire.questions.length !=
            widget.questionnaire.questions.length) {
      _answers = _defaultAnswersFor(_q);
    }
  }

  static Map<String, int> _defaultAnswersFor(RatingQuestionnaireModel q) {
    final defaults = <String, int>{};
    final initial = q.scaleMin <= kRatingScaleDefault && kRatingScaleDefault <= q.scaleMax
        ? kRatingScaleDefault
        : ((q.scaleMin + q.scaleMax) / 2).round().clamp(q.scaleMin, q.scaleMax);
    for (final question in q.questions) {
      defaults[question.id] = initial;
    }
    return defaults;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  int get _computedOverall => overallStarsFromDimensionAnswers(_answers.values);

  Future<void> _enviar() async {
    for (final question in _q.questions) {
      final v = _answers[question.id];
      if (v == null || v < _q.scaleMin || v > _q.scaleMax) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Indique su calificación en «${question.displayTitle}».',
            ),
          ),
        );
        return;
      }
    }

    final comment = _commentCtrl.text.trim();

    await widget.onSubmit(
      stars: _computedOverall,
      comment: comment,
      dimensionAnswers: Map<String, int>.from(_answers),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_q.questions.isEmpty) {
      return Text(
        'El cuestionario de valoración no está disponible. Intente más tarde.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }

    final overall = _computedOverall;

    final titleSize = widget.emphasized ? 15.0 : 13.0;
    final subtitleSize = widget.emphasized ? 12.5 : 11.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.emphasized)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brandBlueContainer.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.brandBlue.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.brandBlue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ajustá cada categoría con el control deslizante. '
                    'La valoración general se calcula automáticamente.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Text(
          widget.title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: titleSize,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.subtitle,
          style: TextStyle(
            fontSize: subtitleSize,
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        if (widget.cancellationReasonBanner != null &&
            widget.cancellationReasonBanner!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brandBlueContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.brandAccent.withOpacity(0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.brandBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.cancellationReasonBanner!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.brandBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: widget.emphasized ? 16 : 12),
        for (var i = 0; i < _q.questions.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          RatingDimensionCard(
            title: _q.questions[i].displayTitle,
            subtitle: _q.questions[i].displaySubtitle,
            value: _answers[_q.questions[i].id],
            enabled: !widget.busy,
            onChanged: (v) => setState(() => _answers[_q.questions[i].id] = v),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.brandBlueContainer.withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              AliadoExperienceStarsRow(stars: overall, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Valoración general: ${ratingValueLabelEs(overall)} ($overall/5)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _commentCtrl,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          enabled: !widget.busy,
          decoration: const InputDecoration(
            labelText: 'Comentario (opcional)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        SizedBox(height: widget.emphasized ? 16 : 6),
        FilledButton(
          onPressed: widget.busy ? null : _enviar,
          style: widget.emphasized
              ? FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: AppColors.brandBlue,
                )
              : null,
          child: widget.busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.emphasized ? 'Enviar valoración' : 'Enviar valoración',
                  style: TextStyle(
                    fontWeight: widget.emphasized ? FontWeight.w700 : null,
                    fontSize: widget.emphasized ? 15 : null,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Muestra dimensiones registradas (v2 o lectura legacy).
class OrderRatingAnswersReadOnly extends StatelessWidget {
  const OrderRatingAnswersReadOnly({
    super.key,
    required this.answers,
    required this.questionnaire,
  });

  final Map<String, dynamic> answers;
  final RatingQuestionnaireModel questionnaire;

  @override
  Widget build(BuildContext context) {
    if (questionnaire.isBucketV2) {
      return _buildV2(context);
    }
    return _buildLegacy(context);
  }

  Widget _buildV2(BuildContext context) {
    final entries = <Widget>[];
    for (final q in questionnaire.questions) {
      final v = answers[q.id];
      final n = v is int ? v : int.tryParse(v?.toString() ?? '');
      if (n == null || n < 1) continue;
      final label = questionnaire.labelForValue(n).isNotEmpty
          ? questionnaire.labelForValue(n)
          : ratingValueLabelEs(n);
      entries.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                q.displayTitle,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
              if (q.displaySubtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  q.displaySubtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.3,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                '$label · $n/${questionnaire.scaleMax}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ratingValueColor(n),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalle por categoría',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        ...entries,
      ],
    );
  }

  Widget _buildLegacy(BuildContext context) {
    final entries = <Widget>[];
    for (final q in questionnaire.questions) {
      final v = answers[q.id];
      final n = v is int ? v : int.tryParse(v?.toString() ?? '');
      if (n == null || n < 1) continue;
      entries.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '${q.textEs ?? q.displayTitle} · $n/${questionnaire.scaleMax}',
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),
      );
    }
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalle opcional',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        ...entries,
      ],
    );
  }
}

/// Estrellas + comentario en tarjeta de valoración recibida (importador).
class OrderRatingReceivedCard extends StatelessWidget {
  const OrderRatingReceivedCard({
    super.key,
    required this.overallStars,
    required this.comment,
    required this.submittedAtLabel,
    required this.authorLabel,
    this.answers = const {},
    this.questionnaire,
  });

  final int overallStars;
  final String comment;
  final String submittedAtLabel;
  final String authorLabel;
  final Map<String, dynamic> answers;
  final RatingQuestionnaireModel? questionnaire;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  authorLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                submittedAtLabel,
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AliadoExperienceStarsRow(stars: overallStars, size: 18),
          if (comment.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              comment.trim(),
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (questionnaire != null && answers.isNotEmpty) ...[
            const SizedBox(height: 6),
            OrderRatingAnswersReadOnly(
              answers: answers,
              questionnaire: questionnaire!,
            ),
          ],
        ],
      ),
    );
  }
}
