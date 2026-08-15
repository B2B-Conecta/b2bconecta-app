import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

import 'rating_questionnaire_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'aliado_experience_utils.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'order_rating_form.dart';

/// Estrellas 1–5 (solo lectura).
class AliadoExperienceStarsRow extends StatelessWidget {
  const AliadoExperienceStarsRow({
    super.key,
    required this.stars,
    this.size = 20,
  });

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = stars > i;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          size: size,
          color: filled ? Colors.amber.shade800 : Colors.grey.shade400,
        );
      }),
    );
  }
}

/// Chip compacto en la tarjeta del pedido (colapsada o expandida).
class AliadoOrderExperienceStatusChip extends StatelessWidget {
  const AliadoOrderExperienceStatusChip({
    super.key,
    required this.request,
    this.linesForGroup,
  });

  final TransactionRequestModel request;
  final List<TransactionRequestModel>? linesForGroup;

  @override
  Widget build(BuildContext context) {
    final lines = linesForGroup ?? [request];
    final entregadas = lineasEntregadasParaValorar(lines).toList();
    if (entregadas.isEmpty) return const SizedBox.shrink();

    final pendiente = aliadoGrupoPendienteValoracion(lines);
    final ref = primeraLineaConValoracion(lines) ?? request;

    if (pendiente) {
      return Chip(
        avatar:
            Icon(Icons.star_outline, size: 16, color: AppColors.brandAccent),
        label: const Text(
          'Valoración pendiente',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.brandBlueContainer,
        side: BorderSide(color: AppColors.brandAccent.withOpacity(0.35)),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    final stars = ref.aliadoExperienceStars ?? 0;
    return Chip(
      avatar: Icon(Icons.star, size: 16, color: Colors.amber.shade800),
      label: Text(
        'Valorado · $stars/5',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
      backgroundColor: Colors.purple.shade50,
      side: BorderSide(color: Colors.purple.shade200),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Bloque fijo cuando la valoración ya quedó registrada (no editable).
class AliadoOrderExperienceRegisteredCard extends StatefulWidget {
  const AliadoOrderExperienceRegisteredCard({
    super.key,
    required this.request,
    this.scopeLabel,
    this.bundleCheckoutGroupId,
    this.bundleImportadorId,
    this.questionnaire,
  });

  final TransactionRequestModel request;
  final String? scopeLabel;
  final String? bundleCheckoutGroupId;
  final String? bundleImportadorId;
  final RatingQuestionnaireModel? questionnaire;

  @override
  State<AliadoOrderExperienceRegisteredCard> createState() =>
      _AliadoOrderExperienceRegisteredCardState();
}

class _AliadoOrderExperienceRegisteredCardState
    extends State<AliadoOrderExperienceRegisteredCard> {
  bool _loadingExtra = true;
  RatingQuestionnaireModel _questionnaire = const RatingQuestionnaireModel(
    version: 'bucket_v1',
    questions: [],
  );
  Map<String, dynamic> _answers = const {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(
      covariant AliadoOrderExperienceRegisteredCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.bundleCheckoutGroupId != widget.bundleCheckoutGroupId ||
        oldWidget.bundleImportadorId != widget.bundleImportadorId) {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    setState(() => _loadingExtra = true);
    try {
      final qFuture = widget.questionnaire != null
          ? Future<RatingQuestionnaireModel>.value(widget.questionnaire!)
          : SupabaseService.fetchRatingQuestionnaire(
              audience: 'aliado_rates_importer',
            );
      final aFuture = SupabaseService.fetchAliadoOrderRatingAnswers(
        transactionRequestId: widget.request.id,
        checkoutGroupId: widget.bundleCheckoutGroupId,
        importadorId: widget.bundleImportadorId,
      );
      final results = await Future.wait([qFuture, aFuture]);
      if (!mounted) return;
      final q = results[0] as RatingQuestionnaireModel;
      final ans = results[1] as Map<String, dynamic>?;
      setState(() {
        _questionnaire = q;
        _answers = ans ?? const {};
        _loadingExtra = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _questionnaire = widget.questionnaire ??
            const RatingQuestionnaireModel(version: 'bucket_v1', questions: []);
        _answers = const {};
        _loadingExtra = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    if (!aliadoTieneValoracionRegistrada(request)) {
      return const SizedBox.shrink();
    }

    final stars = request.aliadoExperienceStars ?? 0;
    final comment = request.aliadoExperienceComment?.trim() ?? '';
    final at = request.aliadoExperienceSubmittedAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.shade300, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined,
                  size: 18, color: Colors.purple.shade800),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.scopeLabel ?? 'Valoración registrada',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Colors.purple.shade900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Definitiva',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.purple.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AliadoExperienceStarsRow(stars: stars, size: 22),
              const SizedBox(width: 8),
              Text(
                '$stars de 5 estrellas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.purple.shade900,
                ),
              ),
            ],
          ),
          if (at != null) ...[
            const SizedBox(height: 6),
            Text(
              'Registrada el ${formatEsShortDateTime(at)}',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Tu comentario',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '«$comment»',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Colors.purple.shade900,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (_loadingExtra) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.purple.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Cargando detalle opcional…',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
          if (!_loadingExtra && _answers.isNotEmpty) ...[
            const SizedBox(height: 8),
            OrderRatingAnswersReadOnly(
              answers: _answers,
              questionnaire: _questionnaire,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Esta calificación queda asociada a este pedido y no puede modificarse desde la app.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.3,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
