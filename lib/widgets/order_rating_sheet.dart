import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rating_questionnaire_model.dart';
import '../models/transaction_request_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/aliado_experience_utils.dart';
import '../utils/order_rating_eligibility.dart';
import 'aliado_order_experience_display.dart';
import 'order_rating_form.dart';

/// Abre el cuestionario de valoración aliado → importador (modal, no embebido en ficha).
Future<void> showAliadoOrderRatingSheet(
  BuildContext context, {
  required TransactionRequestModel request,
  required VoidCallback onSubmitted,
  String? bundleCheckoutGroupId,
  String? bundleImportadorId,
  String? importadorLabel,
  bool readOnly = false,
  String? cancellationReason,
}) {
    return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _OrderRatingSheetScaffold(
      accentColor: Colors.amber.shade800,
      headerTitle: readOnly
          ? 'Valoración registrada'
          : (cancellationReason != null &&
                  cancellationReason.trim().isNotEmpty)
              ? 'Valorar tras cancelación'
              : 'Valorar pedido',
      headerSubtitle: importadorLabel != null && importadorLabel.trim().isNotEmpty
          ? importadorLabel.trim()
          : (bundleImportadorId != null
              ? 'Proveedor en este carrito'
              : request.etiquetaProductoAliado),
      child: _AliadoOrderRatingSheetBody(
        request: request,
        onSubmitted: onSubmitted,
        bundleCheckoutGroupId: bundleCheckoutGroupId,
        bundleImportadorId: bundleImportadorId,
        readOnly: readOnly,
        cancellationReason: cancellationReason,
      ),
    ),
  );
}

/// Abre el cuestionario importador → aliado.
Future<void> showImporterOrderRatingSheet(
  BuildContext context, {
  required TransactionRequestModel request,
  required VoidCallback onSubmitted,
  String? bundleCheckoutGroupId,
  String? bundleAliadoId,
  bool readOnly = false,
  String? cancellationReason,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _OrderRatingSheetScaffold(
      accentColor: AppColors.brandBlue,
      headerTitle: readOnly
          ? 'Valoración registrada'
          : (cancellationReason != null &&
                  cancellationReason.trim().isNotEmpty)
              ? 'Valorar tras cancelación'
              : 'Valorar aliado',
      headerSubtitle: request.aliadoBusinessName?.trim().isNotEmpty == true
          ? request.aliadoBusinessName!.trim()
          : 'Aliado en este pedido',
      child: _ImporterOrderRatingSheetBody(
        request: request,
        onSubmitted: onSubmitted,
        bundleCheckoutGroupId: bundleCheckoutGroupId,
        bundleAliadoId: bundleAliadoId,
        readOnly: readOnly,
        cancellationReason: cancellationReason,
      ),
    ),
  );
}

class _OrderRatingSheetScaffold extends StatelessWidget {
  const _OrderRatingSheetScaffold({
    required this.accentColor,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.child,
  });

  final Color accentColor;
  final String headerTitle;
  final String headerSubtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.star_rounded, color: accentColor, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headerTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            headerSubtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AliadoOrderRatingSheetBody extends StatefulWidget {
  const _AliadoOrderRatingSheetBody({
    required this.request,
    required this.onSubmitted,
    this.bundleCheckoutGroupId,
    this.bundleImportadorId,
    this.readOnly = false,
    this.cancellationReason,
  });

  final TransactionRequestModel request;
  final VoidCallback onSubmitted;
  final String? bundleCheckoutGroupId;
  final String? bundleImportadorId;
  final bool readOnly;
  final String? cancellationReason;

  @override
  State<_AliadoOrderRatingSheetBody> createState() =>
      _AliadoOrderRatingSheetBodyState();
}

class _AliadoOrderRatingSheetBodyState extends State<_AliadoOrderRatingSheetBody> {
  bool _busy = false;
  bool _loadingQ = true;
  RatingQuestionnaireModel? _questionnaire;

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
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gracias. Su valoración quedó registrada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      final msg = _aliadoErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (msg.contains('ya fue registrada')) {
        Navigator.of(context).pop();
        widget.onSubmitted();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _aliadoErrorMessage(Object e) {
    final raw = e is PostgrestException ? e.message : e.toString();
    if (raw.contains('No se puede registrar la valoración') ||
        raw.contains('ya valorados')) {
      return 'La valoración de este pedido ya fue registrada.';
    }
    if (raw.contains('Complete todas las categorías') ||
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
    if (widget.readOnly || aliadoTieneValoracionRegistrada(widget.request)) {
      return AliadoOrderExperienceRegisteredCard(
        request: widget.request,
        scopeLabel: widget.bundleImportadorId != null
            ? 'Valoración de este proveedor'
            : 'Valoración de este pedido',
        bundleCheckoutGroupId: widget.bundleCheckoutGroupId,
        bundleImportadorId: widget.bundleImportadorId,
        questionnaire: _questionnaire,
      );
    }

    if (_loadingQ || _questionnaire == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final motivo = widget.cancellationReason?.trim();
    final esCancelacion = motivo != null && motivo.isNotEmpty;

    return OrderRatingForm(
      title: esCancelacion
          ? 'Valorar tras la cancelación'
          : 'Calificá cada aspecto del servicio',
      subtitle: esCancelacion
          ? 'Su motivo quedó registrado. Califique al proveedor; puede ampliar el comentario.'
          : 'Deslizá cada categoría (1 = Muy mal … 5 = Excelente). '
              'El promedio define la valoración general. Podés añadir un comentario opcional.',
      questionnaire: _questionnaire!,
      busy: _busy,
      emphasized: true,
      initialComment: esCancelacion
          ? orderRatingCommentWithCancellationReason(motivo)
          : '',
      cancellationReasonBanner: esCancelacion
          ? 'Cancelación registrada: $motivo'
          : null,
      onSubmit: _enviar,
    );
  }
}

class _ImporterOrderRatingSheetBody extends StatefulWidget {
  const _ImporterOrderRatingSheetBody({
    required this.request,
    required this.onSubmitted,
    this.bundleCheckoutGroupId,
    this.bundleAliadoId,
    this.readOnly = false,
    this.cancellationReason,
  });

  final TransactionRequestModel request;
  final VoidCallback onSubmitted;
  final String? bundleCheckoutGroupId;
  final String? bundleAliadoId;
  final bool readOnly;
  final String? cancellationReason;

  @override
  State<_ImporterOrderRatingSheetBody> createState() =>
      _ImporterOrderRatingSheetBodyState();
}

class _ImporterOrderRatingSheetBodyState extends State<_ImporterOrderRatingSheetBody> {
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
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valoración del aliado registrada.')),
      );
      widget.onSubmitted();
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
        Navigator.of(context).pop();
        widget.onSubmitted();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly || _alreadyRated) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: const Text(
          'Ya registró su valoración de este aliado en este pedido.',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      );
    }

    if (_loading || _questionnaire == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final motivo = widget.cancellationReason?.trim();
    final esCancelacion = motivo != null && motivo.isNotEmpty;

    return OrderRatingForm(
      title: esCancelacion
          ? 'Valorar tras la cancelación'
          : 'Calificá la experiencia con el aliado',
      subtitle: esCancelacion
          ? 'Su motivo quedó registrado. Califique al aliado; puede ampliar el comentario.'
          : 'Comunicación y Pagos (escala 1–5). El aliado no verá su nombre en su panel de reputación.',
      questionnaire: _questionnaire!,
      busy: _busy,
      emphasized: true,
      initialComment: esCancelacion
          ? orderRatingCommentWithCancellationReason(motivo)
          : '',
      cancellationReasonBanner: esCancelacion
          ? 'Cancelación registrada: $motivo'
          : null,
      onSubmit: _enviar,
    );
  }
}

/// Barra de valoración importador → aliado (carga estado en servidor).
class ImporterOrderRatingBar extends StatefulWidget {
  const ImporterOrderRatingBar({
    super.key,
    required this.request,
    required this.lines,
    required this.onSubmitted,
    this.bundleCheckoutGroupId,
    this.bundleAliadoId,
  });

  final TransactionRequestModel request;
  final List<TransactionRequestModel> lines;
  final VoidCallback onSubmitted;
  final String? bundleCheckoutGroupId;
  final String? bundleAliadoId;

  @override
  State<ImporterOrderRatingBar> createState() => _ImporterOrderRatingBarState();
}

class _ImporterOrderRatingBarState extends State<ImporterOrderRatingBar> {
  bool _loading = true;
  bool _alreadyRated = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.lines.any(lineaElegibleValoracionImportador)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final cg = widget.bundleCheckoutGroupId?.trim();
      final aid = widget.bundleAliadoId?.trim() ?? widget.request.aliadoId;
      final rated = await SupabaseService.importerHasRatedAliado(
        checkoutGroupId: cg,
        transactionRequestId:
            (cg == null || cg.isEmpty) ? widget.request.id : null,
        aliadoId: aid,
      );
      if (!mounted) return;
      setState(() {
        _alreadyRated = rated;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _showBar {
    if (_loading) return false;
    return widget.lines.any(lineaElegibleValoracionImportador);
  }

  @override
  Widget build(BuildContext context) {
    if (!_showBar) return const SizedBox.shrink();

    return OrderRatingPendingBar(
      pending: !_alreadyRated,
      completedSummary:
          _alreadyRated ? 'Aliado valorado en este pedido' : null,
      pendingLabel: 'Valorar aliado',
      onTapPending: () => showImporterOrderRatingSheet(
        context,
        request: widget.request,
        onSubmitted: () {
          widget.onSubmitted();
          _load();
        },
        bundleCheckoutGroupId: widget.bundleCheckoutGroupId,
        bundleAliadoId: widget.bundleAliadoId,
      ),
      onTapView: _alreadyRated
          ? () => showImporterOrderRatingSheet(
                context,
                request: widget.request,
                onSubmitted: widget.onSubmitted,
                bundleCheckoutGroupId: widget.bundleCheckoutGroupId,
                bundleAliadoId: widget.bundleAliadoId,
                readOnly: true,
              )
          : null,
    );
  }
}

/// CTA visible al inicio de la ficha (colapsada o expandida).
class OrderRatingPendingBar extends StatelessWidget {
  const OrderRatingPendingBar({
    super.key,
    required this.pending,
    required this.completedSummary,
    required this.onTapPending,
    this.onTapView,
    this.pendingLabel = 'Valorar pedido',
    this.viewLabel = 'Ver valoración',
  });

  final bool pending;
  final String? completedSummary;
  final VoidCallback onTapPending;
  final VoidCallback? onTapView;
  final String pendingLabel;
  final String viewLabel;

  @override
  Widget build(BuildContext context) {
    if (!pending && completedSummary == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: pending
          ? Material(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onTapPending,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade400, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber.shade800, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pendingLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Toque para abrir el cuestionario. No está en el detalle del pedido.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                color: Colors.amber.shade900.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.amber.shade900),
                    ],
                  ),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTapView,
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: Text(completedSummary ?? viewLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green.shade800,
                side: BorderSide(color: Colors.green.shade300),
              ),
            ),
    );
  }
}
