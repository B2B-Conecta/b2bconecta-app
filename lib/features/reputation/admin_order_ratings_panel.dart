import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/b2b_data_table_shell.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/reputation/admin_order_rating_row_model.dart';
import 'package:motolink_pro_app/features/reputation/aliado_order_experience_display.dart';
import 'package:motolink_pro_app/features/reputation/order_rating_form.dart';
import 'package:motolink_pro_app/features/reputation/rating_questionnaire_model.dart';
import 'package:motolink_pro_app/features/reputation/rating_scale_labels.dart';

enum _AdminRatingFilter {
  all,
  aliadoRatesImporter,
  importerRatesAliado,
  commentHidden,
}

/// Ámbar corporativo de estrellas (módulo valoraciones).
const Color _kRatingAmber = Color(0xFFF59E0B);

/// Alias de producto del módulo Valoraciones (`/admin/ratings`).
typedef RatingsModule = AdminOrderRatingsPanel;

/// C4: expediente admin — resumen + listado estándar de valoraciones.
class AdminOrderRatingsPanel extends StatefulWidget {
  const AdminOrderRatingsPanel({super.key});

  @override
  State<AdminOrderRatingsPanel> createState() => _AdminOrderRatingsPanelState();
}

class _AdminOrderRatingsPanelState extends State<AdminOrderRatingsPanel> {
  final _searchCtrl = TextEditingController();

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
  static const _fetchSize = 100;
  bool _end = false;
  _AdminRatingFilter _filter = _AdminRatingFilter.all;
  int _pageIndex = 0;
  int _pageSize = listPageSizeOptions.first;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (!mounted) return;
      setState(() => _pageIndex = 0);
    });
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminOrderRatingRowModel> get _filteredRows {
    Iterable<AdminOrderRatingRowModel> list = _rows;
    switch (_filter) {
      case _AdminRatingFilter.all:
        break;
      case _AdminRatingFilter.aliadoRatesImporter:
        list = list.where((r) => r.raterRole == 'aliado');
      case _AdminRatingFilter.importerRatesAliado:
        list = list.where((r) => r.raterRole == 'importador');
      case _AdminRatingFilter.commentHidden:
        list = list.where((r) => r.commentHidden);
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) {
        final hay = [
          r.aliadoName,
          r.importadorName,
          r.comment,
          r.raterLabelEs,
          r.checkoutGroupId ?? '',
        ].join(' ').toLowerCase();
        return hay.contains(q);
      });
    }
    return list.toList();
  }

  _RatingsSummary get _summary {
    final source = _rows;
    if (source.isEmpty) {
      return const _RatingsSummary(
        average: 0,
        total: 0,
        buckets: [0, 0, 0, 0, 0],
      );
    }
    final buckets = List<int>.filled(5, 0);
    var sum = 0;
    for (final r in source) {
      final s = r.overallStars.clamp(1, 5);
      buckets[s - 1]++;
      sum += s;
    }
    return _RatingsSummary(
      average: sum / source.length,
      total: source.length,
      buckets: buckets,
    );
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
      final theme = B2BThemeExtension.of(context);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: theme.dialogSurface,
          title: Text(
            'Restaurar comentario',
            style: TextStyle(color: theme.textPrimary),
          ),
          content: Text(
            'El texto volverá a mostrarse en reputación pública. '
            'Las estrellas no se modifican.',
            style: TextStyle(color: theme.textSecondary),
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
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<String?> _promptHideReason() async {
    final theme = B2BThemeExtension.of(context);
    final controller = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.dialogSurface,
        title: Text(
          'Ocultar comentario',
          style: TextStyle(color: theme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'El texto dejará de verse en reputación. '
              'Las estrellas y el promedio no cambian.',
              style: TextStyle(color: theme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Motivo (opcional)',
                filled: true,
                fillColor: theme.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.borderSubtle),
                ),
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
      _pageIndex = 0;
    });
    try {
      final results = await Future.wait([
        SupabaseService.listAdminOrderRatings(
          limit: _fetchSize,
          offset: 0,
        ),
        SupabaseService.fetchRatingQuestionnaire(
          audience: 'aliado_rates_importer',
        ),
        SupabaseService.fetchRatingQuestionnaire(
          audience: 'importer_rates_aliado',
        ),
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
        _end = batch.length < _fetchSize;
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
        limit: _fetchSize,
        offset: _offset,
      );
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...batch];
        _offset = _rows.length;
        _end = batch.length < _fetchSize;
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

  void _writeRating() {
    MainShellTabController.navigateToAdminActivosForNotification();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Abre un pedido entregado y usa «Valorar como administración».',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showDetail(AdminOrderRatingRowModel row) async {
    final theme = B2BThemeExtension.of(context);
    final q = _questionnaireFor(row);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.dialogSurface,
        title: Text(
          'Detalle de valoración',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: _RatingDetailBody(row: row, questionnaire: q),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _onRowAction(AdminOrderRatingRowModel row, String id) {
    switch (id) {
      case 'detail':
        _showDetail(row);
      case 'hide':
        _setCommentHidden(row, hidden: true);
      case 'restore':
        _setCommentHidden(row, hidden: false);
      case 'moderate':
        if (row.commentHidden) {
          _setCommentHidden(row, hidden: false);
        } else if (row.comment.trim().isNotEmpty) {
          _setCommentHidden(row, hidden: true);
        }
    }
  }

  String _filterLabel(_AdminRatingFilter f) => switch (f) {
        _AdminRatingFilter.all => 'Todas',
        _AdminRatingFilter.aliadoRatesImporter => 'Tienda → mayorista',
        _AdminRatingFilter.importerRatesAliado => 'Mayorista → tienda',
        _AdminRatingFilter.commentHidden => 'Ocultos',
      };

  Future<void> _openMobileFilters(B2BThemeExtension theme) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.dialogSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  16 + MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.borderSubtle,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Filtrar valoraciones',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final f in _AdminRatingFilter.values)
                          B2bDataTableFilterPill(
                            label: _filterLabel(f),
                            selected: _filter == f,
                            onTap: () {
                              setState(() {
                                _filter = f;
                                _pageIndex = 0;
                              });
                              setModal(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        'Listo',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final filtered = _filteredRows;
    final page = sliceListPage(
      items: filtered,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );
    final summary = _summary;
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;

    if (_loading && _rows.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: theme.brand),
      );
    }

    if (_error != null && _rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textSecondary),
              ),
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

    final filterPills = [
      for (final f in _AdminRatingFilter.values)
        B2bDataTableFilterPill(
          label: _filterLabel(f),
          selected: _filter == f,
          onTap: () => setState(() {
            _filter = f;
            _pageIndex = 0;
          }),
        ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      color: theme.brand,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _RatingsSummaryHeader(summary: summary),
          const SizedBox(height: 14),
          B2bDataTableShell(
            padding: const EdgeInsets.all(14),
            toolbar: B2bDataTableToolbar(
              searchController: _searchCtrl,
              searchHint: 'Buscar taller, mayorista o comentario…',
              onSearchChanged: (_) {},
              filters: mobile ? const [] : filterPills,
              primaryAction: mobile
                  ? null
                  : FilledButton.icon(
                      onPressed: _writeRating,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.brand,
                        foregroundColor: theme.surfaceCard,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: LucideIcon(
                        LucideGlyph.messageSquarePlus,
                        size: 16,
                        color: theme.surfaceCard,
                      ),
                      label: const Text(
                        'Escribir una valoración',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
              trailing: [
                if (mobile)
                  OutlinedButton.icon(
                    onPressed: () => _openMobileFilters(theme),
                    icon: LucideIcon(
                      LucideGlyph.slidersHorizontal,
                      size: 16,
                      color: theme.brand,
                    ),
                    label: Text(
                      _filter == _AdminRatingFilter.all
                          ? 'Filtrar'
                          : 'Filtrar (1)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.brand,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.brand,
                      side: BorderSide(color: theme.borderSubtle),
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                if (mobile)
                  IconButton(
                    onPressed: _writeRating,
                    tooltip: 'Escribir una valoración',
                    icon: LucideIcon(
                      LucideGlyph.messageSquarePlus,
                      size: 18,
                      color: theme.brand,
                    ),
                  ),
                IconButton(
                  onPressed: _loading ? null : _load,
                  tooltip: 'Actualizar',
                  icon: LucideIcon(
                    LucideGlyph.refreshCw,
                    size: 18,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
            header: mobile
                ? null
                : const B2bDataTableHeader(
                    cells: [
                      B2bDataTableHeaderCell(
                        label: 'Comprador / Taller',
                        flex: 3,
                      ),
                      B2bDataTableHeaderCell(label: 'Calificación', flex: 3),
                      B2bDataTableHeaderCell(label: 'Comentario', flex: 4),
                    ],
                  ),
            empty: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text(
                        _rows.isEmpty
                            ? 'No hay valoraciones registradas.'
                            : 'Ninguna valoración coincide con el filtro.',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : null,
            rows: [
              for (var i = 0; i < page.length; i++)
                B2bDataTableZebraRow(
                  zebra: i.isOdd,
                  isLast: i == page.length - 1,
                  onTap: () => _showDetail(page[i]),
                  child: _RatingTableRow(
                    row: page[i],
                    forceCompact: mobile,
                    onAction: (id) => _onRowAction(page[i], id),
                  ),
                ),
            ],
            footer: ListPageBar(
              total: filtered.length,
              pageIndex: _pageIndex,
              pageSize: _pageSize,
              alwaysShow: filtered.isNotEmpty,
              entityLabel: 'valoraciones',
              hasMore: !_end,
              onPageIndex: (index) {
                setState(() => _pageIndex = index);
                final last =
                    ((filtered.length - 1) / _pageSize).floor().clamp(0, 9999);
                if (index >= last && !_end) {
                  _loadMore();
                }
              },
              onPageSize: (size) => setState(() {
                _pageSize = size;
                _pageIndex = 0;
              }),
            ),
          ),
          if (_loading && _rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.brand,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingsSummary {
  const _RatingsSummary({
    required this.average,
    required this.total,
    required this.buckets,
  });

  final double average;
  final int total;

  /// Conteos indexados 0→1★ … 4→5★.
  final List<int> buckets;
}

class _RatingsSummaryHeader extends StatelessWidget {
  const _RatingsSummaryHeader({required this.summary});

  final _RatingsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final avgLabel = summary.total == 0
        ? '—'
        : summary.average.toStringAsFixed(1);
    final stars = summary.total == 0 ? 0 : summary.average.round().clamp(1, 5);
    final maxBucket = summary.buckets.isEmpty
        ? 1
        : summary.buckets.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: theme.textPrimary.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.06,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final score = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Puntuación global',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    avgLabel,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'de 5',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _AmberStarsRow(stars: stars, size: 20),
              const SizedBox(height: 6),
              Text(
                summary.total == 1
                    ? '1 reseña evaluada'
                    : '${summary.total} reseñas evaluadas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                ),
              ),
            ],
          );

          final chart = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Distribución',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              for (var star = 5; star >= 1; star--) ...[
                if (star < 5) const SizedBox(height: 6),
                _StarDistributionBar(
                  star: star,
                  count: summary.buckets[star - 1],
                  total: summary.total,
                  maxCount: maxBucket,
                ),
              ],
            ],
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: score),
                const SizedBox(width: 28),
                Expanded(flex: 5, child: chart),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              score,
              const SizedBox(height: 16),
              chart,
            ],
          );
        },
      ),
    );
  }
}

class _AmberStarsRow extends StatelessWidget {
  const _AmberStarsRow({required this.stars, this.size = 18});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = stars > i;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: filled ? _kRatingAmber : theme.textMuted,
        );
      }),
    );
  }
}

class _StarDistributionBar extends StatelessWidget {
  const _StarDistributionBar({
    required this.star,
    required this.count,
    required this.total,
    required this.maxCount,
  });

  final int star;
  final int count;
  final int total;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final pct = total == 0 ? 0.0 : count / total;
    final barFrac = maxCount == 0 ? 0.0 : count / maxCount;

    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            '$star',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
            ),
          ),
        ),
        const Icon(Icons.star_rounded, size: 14, color: _kRatingAmber),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(color: theme.inputFill),
                  FractionallySizedBox(
                    widthFactor: barFrac.clamp(0.0, 1.0),
                    child: Container(color: _kRatingAmber.withOpacity(0.85)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            total == 0 ? '0%' : '${(pct * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingTableRow extends StatelessWidget {
  const _RatingTableRow({
    required this.row,
    required this.onAction,
    this.forceCompact = false,
  });

  final AdminOrderRatingRowModel row;
  final ValueChanged<String> onAction;
  final bool forceCompact;

  String get _storeName {
    // Comprador / taller: tienda minorista (aliado).
    return row.aliadoName.trim().isEmpty ? 'Sin nombre' : row.aliadoName.trim();
  }

  String get _subtitle {
    final direction = row.raterRole == 'aliado'
        ? 'Valora a ${row.importadorName}'
        : 'Valorado por ${row.importadorName}';
    final at = row.submittedAt;
    if (at == null) return direction;
    return '$direction · ${formatEsShortDateTime(at)}';
  }

  String get _productLabel {
    final group = row.checkoutGroupId?.trim();
    if (group != null && group.isNotEmpty) {
      final short = group.replaceAll('-', '');
      final id = short.length <= 8 ? short : '${short.substring(0, 8)}…';
      return 'Pedido $id';
    }
    return row.importadorName.trim().isEmpty
        ? 'Pedido B2B'
        : row.importadorName.trim();
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final canHide = !row.commentHidden && row.comment.trim().isNotEmpty;
    final canRestore = row.commentHidden;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = forceCompact ||
            constraints.maxWidth < AppBreakpoints.mobileMenu;
        final buyer = Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.brandContainer,
              child: Text(
                _initials(_storeName),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: theme.brand,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final rating = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AmberStarsRow(stars: row.overallStars.clamp(0, 5), size: 16),
            const SizedBox(height: 4),
            Text(
              _productLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            if (row.commentHidden)
              B2bDataStatusBadge(
                label: 'Oculto',
                foreground: theme.textPrimary,
                background: theme.surfaceSubtle,
              )
            else
              B2bDataStatusBadge(
                label: 'Verificado',
                foreground: theme.successFg,
                background: theme.successBg,
              ),
          ],
        );

        final comment = Text(
          row.comment.trim().isEmpty
              ? 'Sin comentario'
              : row.comment.trim(),
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w500,
            fontStyle: row.comment.trim().isEmpty || row.commentHidden
                ? FontStyle.italic
                : FontStyle.normal,
            color: theme.textSecondary,
          ),
        );

        final actions = B2bDataRowActionsMenu(
          actions: [
            const B2bDataRowAction(
              id: 'detail',
              label: 'Ver detalles',
              glyph: LucideGlyph.eye,
            ),
            B2bDataRowAction(
              id: 'moderate',
              label: canRestore
                  ? 'Restaurar comentario'
                  : 'Moderar comentario',
              glyph: canRestore ? LucideGlyph.eye : LucideGlyph.eyeOff,
              enabled: canHide || canRestore,
            ),
            B2bDataRowAction(
              id: 'hide',
              label: 'Eliminar reseña',
              glyph: LucideGlyph.trash2,
              destructive: true,
              enabled: canHide,
            ),
          ],
          onSelected: onAction,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: buyer),
                  actions,
                ],
              ),
              const SizedBox(height: 10),
              rating,
              const SizedBox(height: 8),
              comment,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: buyer),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: rating),
            const SizedBox(width: 8),
            Expanded(flex: 4, child: comment),
            actions,
          ],
        );
      },
    );
  }
}

class _RatingDetailBody extends StatelessWidget {
  const _RatingDetailBody({
    required this.row,
    required this.questionnaire,
  });

  final AdminOrderRatingRowModel row;
  final RatingQuestionnaireModel questionnaire;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final hasDimensions =
        row.answers.isNotEmpty && questionnaire.questions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.raterLabelEs,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.brand,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${row.aliadoName} ↔ ${row.importadorName}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
        ),
        if (row.submittedAt != null) ...[
          const SizedBox(height: 4),
          Text(
            formatEsShortDateTime(row.submittedAt!),
            style: TextStyle(fontSize: 11, color: theme.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            AliadoExperienceStarsRow(
              stars: row.overallStars.clamp(1, 5),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              '${row.overallStars} / 5',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: ratingValueColor(row.overallStars.clamp(1, 5)),
              ),
            ),
          ],
        ),
        if (row.comment.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            row.comment.trim(),
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: theme.textPrimary,
              fontStyle:
                  row.commentHidden ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (row.commentHidden &&
              (row.commentHiddenReason?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            Text(
              'Motivo: ${row.commentHiddenReason!.trim()}',
              style: TextStyle(fontSize: 11, color: theme.textSecondary),
            ),
          ],
        ],
        if (hasDimensions) ...[
          const SizedBox(height: 14),
          Text(
            'Detalle por categoría',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          OrderRatingAnswersReadOnly(
            answers: row.answers,
            questionnaire: questionnaire,
          ),
        ],
      ],
    );
  }
}
