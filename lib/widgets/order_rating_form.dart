import 'package:flutter/material.dart';

import '../models/rating_questionnaire_model.dart';
import '../theme/app_theme.dart';
import 'aliado_order_experience_display.dart';

/// Valoración post-entrega: estrellas + comentario obligatorios; Bucket List opcional.
class OrderRatingForm extends StatefulWidget {
  const OrderRatingForm({
    super.key,
    required this.title,
    required this.subtitle,
    required this.questionnaire,
    required this.onSubmit,
    this.busy = false,
    this.optionalSectionTitle = '¿Quieres ayudarnos a mejorar? (Opcional)',
  });

  final String title;
  final String subtitle;
  final RatingQuestionnaireModel questionnaire;
  final Future<void> Function({
    required int stars,
    required String comment,
    required Map<String, int> optionalAnswers,
  }) onSubmit;
  final bool busy;
  final String optionalSectionTitle;

  @override
  State<OrderRatingForm> createState() => _OrderRatingFormState();
}

class _OrderRatingFormState extends State<OrderRatingForm> {
  int? _estrellas;
  final _commentCtrl = TextEditingController();
  final Map<String, int> _answers = {};
  bool _showOptional = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final s = _estrellas;
    if (s == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indique de 1 a 5 estrellas.')),
      );
      return;
    }
    final comment = _commentCtrl.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El comentario es obligatorio.')),
      );
      return;
    }
    await widget.onSubmit(
      stars: s,
      comment: comment,
      optionalAnswers: Map<String, int>.from(_answers),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questionnaire;
    final hasOptional = q.questions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.subtitle,
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.grey.shade700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final n = i + 1;
            final sel = (_estrellas ?? 0) >= n;
            return IconButton(
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: widget.busy
                  ? null
                  : () => setState(() {
                        _estrellas = n;
                        if (hasOptional) _showOptional = true;
                      }),
              icon: Icon(
                sel ? Icons.star : Icons.star_border,
                size: 28,
                color: sel ? Colors.amber.shade800 : Colors.grey.shade500,
              ),
            );
          }),
        ),
        TextField(
          controller: _commentCtrl,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          enabled: !widget.busy,
          decoration: const InputDecoration(
            labelText: 'Comentario (obligatorio)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (hasOptional && _estrellas != null) ...[
          const SizedBox(height: 8),
          Text(
            'Preguntas opcionales de feedback (${q.scaleMin}–${q.scaleMax}): '
            '${q.questions.map((e) => e.textEs).join(' · ')}',
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.grey.shade700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Material(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: widget.busy
                  ? null
                  : () => setState(() => _showOptional = !_showOptional),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    Icon(
                      _showOptional ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: AppColors.brandBlue,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.optionalSectionTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showOptional) ...[
            const SizedBox(height: 8),
            for (final question in q.questions) ...[
              _OptionalQuestionRow(
                question: question,
                scaleMin: q.scaleMin,
                scaleMax: q.scaleMax,
                value: _answers[question.id],
                enabled: !widget.busy,
                onChanged: (v) => setState(() {
                  if (v == null) {
                    _answers.remove(question.id);
                  } else {
                    _answers[question.id] = v;
                  }
                }),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
        const SizedBox(height: 6),
        FilledButton.tonal(
          onPressed: widget.busy ? null : _enviar,
          child: widget.busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar valoración'),
        ),
      ],
    );
  }
}

class _OptionalQuestionRow extends StatelessWidget {
  const _OptionalQuestionRow({
    required this.question,
    required this.scaleMin,
    required this.scaleMax,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final RatingQuestionModel question;
  final int scaleMin;
  final int scaleMax;
  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question.textEs,
          style: TextStyle(
            fontSize: 11,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(scaleMax - scaleMin + 1, (i) {
            final n = scaleMin + i;
            final sel = value == n;
            return Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: i < scaleMax - scaleMin ? 4 : 0),
                child: OutlinedButton(
                  onPressed: enabled ? () => onChanged(sel ? null : n) : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    backgroundColor:
                        sel ? AppColors.brandBlue.withOpacity(0.12) : null,
                    foregroundColor:
                        sel ? AppColors.brandBlue : Colors.grey.shade700,
                    side: BorderSide(
                      color: sel ? AppColors.brandBlue : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    '$n',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Muestra dimensiones opcionales ya registradas (solo lectura).
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
    final entries = <Widget>[];
    for (final q in questionnaire.questions) {
      final v = answers[q.id];
      final n = v is int ? v : int.tryParse(v?.toString() ?? '');
      if (n == null || n < 1) continue;
      entries.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '${q.textEs} · $n/${questionnaire.scaleMax}',
            style: TextStyle(
                fontSize: 10.5, color: Colors.grey.shade800, height: 1.3),
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
            color: Colors.grey.shade700,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  authorLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                submittedAtLabel,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
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
                  fontSize: 12, height: 1.35, color: Colors.grey.shade900),
            ),
          ],
          if (questionnaire != null) ...[
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
