import 'package:flutter/material.dart';

import '../models/admin_order_rating_row_model.dart';
import '../models/rating_questionnaire_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import '../utils/rating_scale_labels.dart';
import 'aliado_order_experience_display.dart';
import 'order_rating_form.dart';

enum _AdminRatingFilter {
  all,
  aliadoRatesImporter,
  importerRatesAliado,
  commentHidden,
}

/// C4: expediente admin — listado de valoraciones con nombres reales.
class AdminOrderRatingsPanel extends StatefulWidget {
  const AdminOrderRatingsPanel({super.key});

  @override
  State<AdminOrderRatingsPanel> createState() => _AdminOrderRatingsPanelState();
}

class _AdminOrderRatingsPanelState extends State<AdminOrderRatingsPanel> {
  bool _loading = true;
  String? _error;
  List<AdminOrderRatingRowModel> _rows = const [];
  RatingQuestionnaireModel _aliadoQ = const RatingQuestionnaireModel(
    version: 'bucket_v1',
    questions: [],
  );
  RatingQuestionnaireModel _importadorQ = const RatingQuestionnaireModel(
    version: 'bucket_v1',
    questions: [],
  );
  int _offset = 0;
  static const _pageSize = 50;
  bool _end = false;
  _AdminRatingFilter _filter = _AdminRatingFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<AdminOrderRatingRowModel> get _filteredRows {
    switch (_filter) {
      case _AdminRatingFilter.all:
        return _rows;
      case _AdminRatingFilter.aliadoRatesImporter:
        return _rows.where((r) => r.raterRole == 'aliado').toList();
      case _AdminRatingFilter.importerRatesAliado:
        return _rows.where((r) => r.raterRole == 'importador').toList();
      case _AdminRatingFilter.commentHidden:
        return _rows.where((r) => r.commentHidden).toList();
    }
  }

  Future<void> _setCommentHidden(
    AdminOrderRatingRowModel row, {
    required bool hidden,
  }) async {
    String? reason;
    if (hidden) {
      reason = await _promptHideReason();
      if (reason == null) return;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restaurar comentario'),
          content: const Text(
            'El texto volverá a mostrarse en reputación pública. '
            'Las estrellas no se modifican.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    try {
      await SupabaseService.adminSetOrderRatingCommentHidden(
        ratingId: row.id,
        hidden: hidden,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hidden
                ? 'Comentario ocultado. Las estrellas se mantienen.'
                : 'Comentario restaurado.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo moderar: $e'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String?> _promptHideReason() async {
    final controller = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ocultar comentario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'El texto dejará de verse en reputación. '
              'Las estrellas y el promedio no cambian.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Ocultar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return res;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _end = false;
    });
    try {
      final results = await Future.wait([
        SupabaseService.listAdminOrderRatings(
          limit: _pageSize,
          offset: 0,
        ),
        SupabaseService.fetchRatingQuestionnaire(
            audience: 'aliado_rates_importer'),
        SupabaseService.fetchRatingQuestionnaire(
            audience: 'importer_rates_aliado'),
      ]);
      if (!mounted) return;
      final batch = results[0] as List<AdminOrderRatingRowModel>;
      final aq = results[1] as RatingQuestionnaireModel;
      final iq = results[2] as RatingQuestionnaireModel;
      setState(() {
        _rows = batch;
        _aliadoQ = aq;
        _importadorQ = iq;
        _offset = _rows.length;
        _end = batch.length < _pageSize;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _end) return;
    setState(() => _loading = true);
    try {
      final batch = await SupabaseService.listAdminOrderRatings(
        limit: _pageSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...batch];
        _offset = _rows.length;
        _end = batch.length < _pageSize;
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

  RatingQuestionnaireModel _questionnaireFor(AdminOrderRatingRowModel r) {
    if (r.raterRole == 'aliado') return _aliadoQ;
    if (r.raterRole == 'importador') return _importadorQ;
    return const RatingQuestionnaireModel(version: 'bucket_v1', questions: []);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Text(
          'No hay valoraciones registradas.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final filtered = _filteredRows;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _AdminRatingsToolbar(
            totalCount: _rows.length,
            filteredCount: filtered.length,
            filter: _filter,
            loading: _loading,
            onFilterChanged: (f) => setState(() => _filter = f),
            onRefresh: _load,
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Ninguna valoración coincide con el filtro.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            ...filtered.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AdminOrderRatingCard(
                  row: r,
                  questionnaire: _questionnaireFor(r),
                  onHideComment: (!r.commentHidden &&
                          r.comment.trim().isNotEmpty)
                      ? () => _setCommentHidden(r, hidden: true)
                      : null,
                  onRestoreComment: r.commentHidden
                      ? () => _setCommentHidden(r, hidden: false)
                      : null,
                ),
              ),
            ),
          if (!_end) ...[
            const SizedBox(height: 8),
            Center(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: _loadMore,
                      child: const Text('Cargar más'),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminRatingsToolbar extends StatelessWidget {
  const _AdminRatingsToolbar({
    required this.totalCount,
    required this.filteredCount,
    required this.filter,
    required this.loading,
    required this.onFilterChanged,
    required this.onRefresh,
  });

  final int totalCount;
  final int filteredCount;
  final _AdminRatingFilter filter;
  final bool loading;
  final ValueChanged<_AdminRatingFilter> onFilterChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                filter == _AdminRatingFilter.all
                    ? '$totalCount valoraciones'
                    : '$filteredCount de $totalCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Actualizar',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(
                label: 'Todas',
                selected: filter == _AdminRatingFilter.all,
                onTap: () => onFilterChanged(_AdminRatingFilter.all),
              ),
              const SizedBox(width: 6),
              _filterChip(
                label: MediaQuery.sizeOf(context).width < 600
                    ? 'Aliado → Imp.'
                    : 'Aliado → importador',
                selected: filter == _AdminRatingFilter.aliadoRatesImporter,
                onTap: () =>
                    onFilterChanged(_AdminRatingFilter.aliadoRatesImporter),
              ),
              const SizedBox(width: 6),
              _filterChip(
                label: MediaQuery.sizeOf(context).width < 600
                    ? 'Imp. → Aliado'
                    : 'Importador → aliado',
                selected: filter == _AdminRatingFilter.importerRatesAliado,
                onTap: () =>
                    onFilterChanged(_AdminRatingFilter.importerRatesAliado),
              ),
              const SizedBox(width: 6),
              _filterChip(
                label: 'Ocultos',
                selected: filter == _AdminRatingFilter.commentHidden,
                onTap: () =>
                    onFilterChanged(_AdminRatingFilter.commentHidden),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      showCheckmark: false,
      selectedColor: AppColors.brandBlueContainer,
      side: BorderSide(
        color: selected ? AppColors.brandAccent : AppColors.borderSubtle,
      ),
    );
  }
}

class _AdminOrderRatingCard extends StatefulWidget {
  const _AdminOrderRatingCard({
    required this.row,
    required this.questionnaire,
    this.onHideComment,
    this.onRestoreComment,
  });

  final AdminOrderRatingRowModel row;
  final RatingQuestionnaireModel questionnaire;
  final VoidCallback? onHideComment;
  final VoidCallback? onRestoreComment;

  @override
  State<_AdminOrderRatingCard> createState() => _AdminOrderRatingCardState();
}

class _AdminOrderRatingCardState extends State<_AdminOrderRatingCard> {
  bool _detailExpanded = false;

  bool get _isAliadoRater => widget.row.raterRole == 'aliado';

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final q = widget.questionnaire;
    final at = r.submittedAt;
    final hasDimensions = r.answers.isNotEmpty && q.questions.isNotEmpty;
    final accent = _isAliadoRater
        ? AppColors.brandAccent
        : AppColors.successGreen;
    final accentBg = accent.withOpacity(0.14);
    final canModerate =
        widget.onHideComment != null || widget.onRestoreComment != null;

    return Material(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: r.commentHidden
              ? Colors.orange.shade300
              : AppColors.borderSubtle,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            color: accentBg,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accent.withOpacity(0.45)),
                  ),
                  child: Text(
                    r.raterLabelEs,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
                if (r.commentHidden) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Text(
                      'Comentario oculto',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (at != null)
                  Text(
                    formatEsShortDateTime(at),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.store_outlined, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _shortName(r.importadorName),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 7, top: 2, bottom: 2),
                  child: Icon(
                    Icons.arrow_downward,
                    size: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.build_outlined, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _shortName(r.aliadoName),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (r.checkoutGroupId != null &&
                    r.checkoutGroupId!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Carrito ${_shortUuid(r.checkoutGroupId!)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    AliadoExperienceStarsRow(
                      stars: r.overallStars.clamp(1, 5),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${r.overallStars} / 5',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: ratingValueColor(r.overallStars.clamp(1, 5)),
                      ),
                    ),
                  ],
                ),
                if (r.comment.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    r.comment.trim(),
                    maxLines: _detailExpanded ? null : 3,
                    overflow: _detailExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: r.commentHidden
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontStyle: r.commentHidden
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  if (r.commentHidden &&
                      (r.commentHiddenReason?.trim().isNotEmpty ?? false)) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Motivo: ${r.commentHiddenReason!.trim()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ],
                ],
                if (canModerate) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: r.commentHidden
                        ? TextButton.icon(
                            onPressed: widget.onRestoreComment,
                            icon: const Icon(Icons.visibility_outlined,
                                size: 18),
                            label: const Text('Restaurar comentario'),
                          )
                        : TextButton.icon(
                            onPressed: widget.onHideComment,
                            icon: const Icon(Icons.visibility_off_outlined,
                                size: 18),
                            label: const Text('Ocultar comentario'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.orange.shade900,
                            ),
                          ),
                  ),
                ],
                if (hasDimensions) ...[
                  const SizedBox(height: 10),
                  _AdminRatingDimensionChips(
                    answers: r.answers,
                    questionnaire: q,
                  ),
                  InkWell(
                    onTap: () =>
                        setState(() => _detailExpanded = !_detailExpanded),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            _detailExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                            color: AppColors.brandAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _detailExpanded
                                ? 'Ocultar detalle por categoría'
                                : 'Ver detalle por categoría',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_detailExpanded) ...[
                    const SizedBox(height: 4),
                    OrderRatingAnswersReadOnly(
                      answers: r.answers,
                      questionnaire: q,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _shortName(String raw, {int max = 36}) {
    final s = raw.trim();
    if (s.length <= max) return s;
    return '${s.substring(0, max - 1)}…';
  }

  static String _shortUuid(String id) {
    final s = id.replaceAll('-', '');
    if (s.length <= 8) return s;
    return '${s.substring(0, 8)}…';
  }
}

/// Resumen compacto de dimensiones (chips con color por nota).
class _AdminRatingDimensionChips extends StatelessWidget {
  const _AdminRatingDimensionChips({
    required this.answers,
    required this.questionnaire,
  });

  final Map<String, dynamic> answers;
  final RatingQuestionnaireModel questionnaire;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final q in questionnaire.questions) {
      final v = answers[q.id];
      final n = v is int ? v : int.tryParse(v?.toString() ?? '');
      if (n == null || n < questionnaire.scaleMin) continue;
      final color = ratingValueColor(n);
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.45)),
          ),
          child: Text(
            '${q.displayTitle} · $n',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }
}
