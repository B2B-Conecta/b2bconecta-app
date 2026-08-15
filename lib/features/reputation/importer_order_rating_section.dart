import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'rating_questionnaire_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'order_rating_form.dart';

/// Importador valora al aliado tras entrega (mutua C4).
class ImporterOrderRatingSection extends StatefulWidget {
  const ImporterOrderRatingSection({
    super.key,
    required this.request,
    required this.onChanged,
    this.bundleCheckoutGroupId,
    this.bundleAliadoId,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;
  final String? bundleCheckoutGroupId;
  final String? bundleAliadoId;

  @override
  State<ImporterOrderRatingSection> createState() =>
      _ImporterOrderRatingSectionState();
}

class _ImporterOrderRatingSectionState extends State<ImporterOrderRatingSection> {
  bool _busy = false;
  bool _loading = true;
  bool _alreadyRated = false;
  RatingQuestionnaireModel? _questionnaire;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cg = widget.bundleCheckoutGroupId?.trim();
      final aid = widget.bundleAliadoId?.trim() ?? widget.request.aliadoId;
      final results = await Future.wait([
        SupabaseService.fetchRatingQuestionnaire(audience: 'importer_rates_aliado'),
        SupabaseService.importerHasRatedAliado(
          checkoutGroupId: cg,
          transactionRequestId:
              (cg == null || cg.isEmpty) ? widget.request.id : null,
          aliadoId: aid,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _questionnaire = results[0] as RatingQuestionnaireModel;
        _alreadyRated = results[1] as bool;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _questionnaire = const RatingQuestionnaireModel(
          version: 'bucket_v1',
          questions: [],
        );
        _loading = false;
      });
    }
  }

  Future<void> _enviar({
    required int stars,
    required String comment,
    required Map<String, int> dimensionAnswers,
  }) async {
    setState(() => _busy = true);
    try {
      final answersJson = dimensionAnswers.map(
        (k, v) => MapEntry<String, dynamic>(k, v),
      );
      final cg = widget.bundleCheckoutGroupId?.trim();
      final aid = widget.bundleAliadoId?.trim();
      if (cg != null && cg.isNotEmpty && aid != null && aid.isNotEmpty) {
        await SupabaseService.importerSubmitOrderRatingGrupo(
          checkoutGroupId: cg,
          aliadoId: aid,
          stars: stars,
          comment: comment,
          answers: answersJson,
        );
      } else {
        await SupabaseService.importerSubmitOrderRating(
          transactionRequestId: widget.request.id,
          stars: stars,
          comment: comment,
          answers: answersJson,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valoración del aliado registrada.')),
      );
      setState(() => _alreadyRated = true);
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      final raw = e is PostgrestException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            raw.contains('ya fue registrada')
                ? 'Ya valoró a este aliado en este pedido.'
                : 'No se pudo enviar la valoración.',
          ),
        ),
      );
      if (raw.contains('ya fue registrada')) {
        setState(() => _alreadyRated = true);
        widget.onChanged();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    if (r.status != TransactionRequestStatus.entregado) {
      return const SizedBox.shrink();
    }

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_alreadyRated) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: const Text(
          'Valoración del aliado registrada en este pedido.',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 20),
        Text(
          'Valorar aliado (post-entrega)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        OrderRatingForm(
          title: '¿Cómo fue la experiencia con este aliado?',
          subtitle:
              'Calificá Comunicación y Pagos (por defecto Regular). Podés añadir un comentario opcional. '
              'El aliado no verá su identidad en su panel de reputación.',
          questionnaire: _questionnaire!,
          busy: _busy,
          onSubmit: _enviar,
        ),
      ],
    );
  }
}
