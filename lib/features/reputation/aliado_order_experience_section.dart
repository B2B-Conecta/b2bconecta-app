import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'rating_questionnaire_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'aliado_experience_utils.dart';
import 'aliado_order_experience_display.dart';
import 'order_rating_form.dart';

/// C4: calificación 1–5 por dimensiones; comentario opcional tras entrega.
class AliadoOrderExperienceSection extends StatefulWidget {
  const AliadoOrderExperienceSection({
    super.key,
    required this.request,
    required this.onChanged,
    this.bundleCheckoutGroupId,
    this.bundleImportadorId,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;

  final String? bundleCheckoutGroupId;
  final String? bundleImportadorId;

  @override
  State<AliadoOrderExperienceSection> createState() =>
      _AliadoOrderExperienceSectionState();
}

class _AliadoOrderExperienceSectionState
    extends State<AliadoOrderExperienceSection> {
  bool _busy = false;
  RatingQuestionnaireModel? _questionnaire;
  bool _loadingQ = true;

  @override
  void initState() {
    super.initState();
    _loadQuestionnaire();
  }

  Future<void> _loadQuestionnaire() async {
    try {
      final q = await SupabaseService.fetchRatingQuestionnaire(
        audience: 'aliado_rates_importer',
      );
      if (!mounted) return;
      setState(() {
        _questionnaire = q;
        _loadingQ = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _questionnaire = const RatingQuestionnaireModel(
          version: 'bucket_v1',
          questions: [],
        );
        _loadingQ = false;
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
      final bcg = widget.bundleCheckoutGroupId?.trim();
      final bid = widget.bundleImportadorId?.trim();
      if (bcg != null && bcg.isNotEmpty && bid != null && bid.isNotEmpty) {
        await SupabaseService.aliadoSubmitOrderExperienceImportadorGrupo(
          checkoutGroupId: bcg,
          importadorId: bid,
          stars: stars,
          comment: comment,
          answers: answersJson,
        );
      } else {
        await SupabaseService.aliadoSubmitOrderExperience(
          transactionRequestId: widget.request.id,
          stars: stars,
          comment: comment,
          answers: answersJson,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gracias. Su valoración quedó registrada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      final msg = _experienceErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      if (msg.contains('ya fue registrada')) {
        widget.onChanged();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _experienceErrorMessage(Object e) {
    final raw = e is PostgrestException ? e.message : e.toString();
    if (raw.contains('No se puede registrar la valoración') ||
        raw.contains('ya valorados')) {
      return 'La valoración de este pedido ya fue registrada. '
          'Actualizamos la ficha para mostrarla.';
    }
    if (raw.contains('Calificación inválida') ||
        raw.contains('Complete todas las categorías') ||
        raw.contains('cuestionario de valoración')) {
      return 'Complete todas las categorías de la valoración.';
    }
    if (raw.contains('comentario es obligatorio')) {
      return 'El comentario es obligatorio.';
    }
    return 'No se pudo enviar la valoración. Inténtelo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    if (r.status != TransactionRequestStatus.entregado ||
        r.anuladoPorMotolink ||
        r.canceladoPorAliado) {
      return const SizedBox.shrink();
    }
    if (aliadoTieneValoracionRegistrada(r)) {
      final scope = widget.bundleImportadorId != null &&
              widget.bundleImportadorId!.trim().isNotEmpty
          ? 'Valoración de este proveedor en el pedido'
          : 'Valoración de este pedido';
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AliadoOrderExperienceRegisteredCard(
          request: r,
          scopeLabel: scope,
          bundleCheckoutGroupId: widget.bundleCheckoutGroupId,
          bundleImportadorId: widget.bundleImportadorId,
          questionnaire: _questionnaire,
        ),
      );
    }

    if (_loadingQ || _questionnaire == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final isBundle = widget.bundleCheckoutGroupId != null &&
        widget.bundleCheckoutGroupId!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OrderRatingForm(
        title: isBundle
            ? '¿Cómo fue tu experiencia con este proveedor en este pedido?'
            : '¿Cómo fue tu experiencia con este pedido?',
        subtitle:
            'Calificá cada categoría (por defecto Regular). La valoración general '
            'es el promedio. El comentario es opcional.',
        questionnaire: _questionnaire!,
        busy: _busy,
        onSubmit: _enviar,
      ),
    );
  }
}
