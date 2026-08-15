import 'package:flutter/material.dart';

import 'rating_questionnaire_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'order_rating_form.dart';

/// Admin valora en nombre del aliado o del importador (solo si aún no calificaron).
Future<void> showAdminOrderRatingSheet(
  BuildContext context, {
  required TransactionRequestModel request,
  required String raterRole,
  required VoidCallback onSubmitted,
}) {
  final role = raterRole.trim().toLowerCase();
  final asAliado = role == 'aliado';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AdminOrderRatingSheet(
      request: request,
      raterRole: asAliado ? 'aliado' : 'importador',
      onSubmitted: onSubmitted,
    ),
  );
}

class _AdminOrderRatingSheet extends StatefulWidget {
  const _AdminOrderRatingSheet({
    required this.request,
    required this.raterRole,
    required this.onSubmitted,
  });

  final TransactionRequestModel request;
  final String raterRole;
  final VoidCallback onSubmitted;

  @override
  State<_AdminOrderRatingSheet> createState() => _AdminOrderRatingSheetState();
}

class _AdminOrderRatingSheetState extends State<_AdminOrderRatingSheet> {
  RatingQuestionnaireModel? _questionnaire;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  bool get _asAliado => widget.raterRole == 'aliado';

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
      final q = await SupabaseService.fetchRatingQuestionnaire(
        audience: _asAliado
            ? 'aliado_rates_importer'
            : 'importer_rates_aliado',
      );
      if (!mounted) return;
      setState(() {
        _questionnaire = q;
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

  Future<void> _submit({
    required int stars,
    required String comment,
    required Map<String, int> dimensionAnswers,
  }) async {
    setState(() => _busy = true);
    try {
      await SupabaseService.adminSubmitOrderRating(
        raterRole: widget.raterRole,
        transactionRequestId: widget.request.id,
        stars: stars,
        comment: comment,
        answers: dimensionAnswers,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSubmitted();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _asAliado
                ? 'Valoración registrada en nombre del aliado. Se le notificó.'
                : 'Valoración registrada en nombre del mayorista. Se le notificó.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo registrar: $e'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final subtitle = _asAliado
        ? (widget.request.aliadoBusinessName?.trim().isNotEmpty == true
            ? 'En nombre de: ${widget.request.aliadoBusinessName!.trim()}'
            : 'En nombre del aliado')
        : (widget.request.ownerBusinessName?.trim().isNotEmpty == true
            ? 'En nombre de: ${widget.request.ownerBusinessName!.trim()}'
            : 'En nombre del mayorista');

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Material(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _asAliado
                      ? 'Valorar como aliado'
                      : 'Valorar como mayorista',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$subtitle\nSolo disponible si el usuario aún no calificó. '
                  'Recibirá una notificación.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                else if (_questionnaire != null)
                  Flexible(
                    child: SingleChildScrollView(
                      child: OrderRatingForm(
                        title: _asAliado
                            ? 'Calificación al mayorista'
                            : 'Calificación al aliado',
                        subtitle: subtitle,
                        questionnaire: _questionnaire!,
                        busy: _busy,
                        emphasized: true,
                        onSubmit: _submit,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
