import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/app_date_format.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/features/inventory/importer_sales_snapshot.dart';

/// Destaca hasta 3 mayoristas en el catálogo, con métricas de ventas y rotación.
class AdminCatalogFeaturedSection extends StatefulWidget {
  const AdminCatalogFeaturedSection({
    super.key,
    this.onChanged,
  });

  final VoidCallback? onChanged;

  @override
  State<AdminCatalogFeaturedSection> createState() =>
      _AdminCatalogFeaturedSectionState();
}

class _AdminCatalogFeaturedSectionState
    extends State<AdminCatalogFeaturedSection> {
  static const _dayOptions = <int>[7, 15, 30];
  final _searchCtrl = TextEditingController();
  List<ImporterSalesSnapshot> _rows = const [];
  bool _loading = true;
  String? _error;
  int _windowDays = 30;
  String? _busyId;
  _FeaturedSort _sort = _FeaturedSort.units;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.adminListImporterSalesSnapshots(
        days: _windowDays,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las métricas de mayoristas.';
        _loading = false;
      });
    }
  }

  List<ImporterSalesSnapshot> get _featured =>
      _rows.where((e) => e.isCatalogFeatured).toList();

  List<ImporterSalesSnapshot> get _candidates {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = _rows.where((e) {
      if (e.isCatalogFeatured) return false;
      if (q.isEmpty) return true;
      return (e.businessName ?? '').toLowerCase().contains(q);
    }).toList();
    list.sort((a, b) {
      switch (_sort) {
        case _FeaturedSort.units:
          return b.unitsSold.compareTo(a.unitsSold);
        case _FeaturedSort.revenue:
          return b.revenueRef.compareTo(a.revenueRef);
        case _FeaturedSort.name:
          return (a.businessName ?? '')
              .toLowerCase()
              .compareTo((b.businessName ?? '').toLowerCase());
      }
    });
    return list;
  }

  Future<void> _setDays(ImporterSalesSnapshot row, int days) async {
    final id = row.importadorId?.trim() ?? '';
    if (id.isEmpty || _busyId != null) return;
    setState(() => _busyId = id);
    try {
      await SupabaseService.adminSetImporterCatalogFeatured(
        importadorId: id,
        days: days,
      );
      if (!mounted) return;
      widget.onChanged?.call();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            days == 0
                ? 'Se quitó el destacado de ${row.businessName ?? 'el mayorista'}.'
                : '${row.businessName ?? 'Mayorista'} destacado por $days días.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.contains('featured_limit')
          ? 'Solo se pueden destacar 3 mayoristas a la vez.'
          : 'No se pudo actualizar el destacado.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _pickDuration(ImporterSalesSnapshot row) async {
    if (_featured.length >= 3 && !row.isCatalogFeatured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya hay 3 mayoristas destacados. Quite uno para sumar otro.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final days = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Destacar ${row.businessName ?? 'mayorista'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sube sus productos al inicio del catálogo aliado.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                for (final d in _dayOptions) ...[
                  FilledButton.tonal(
                    onPressed: () => Navigator.pop(ctx, d),
                    child: Text('$d días'),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (days != null) await _setDays(row, days);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.star_outline, size: 20, color: AppColors.brandAccent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Destacar mayoristas',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                Text(
                  '${_featured.length} / 3',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Elija por ventas, pedidos en curso y rotación. Máximo 3 a la vez.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: 7, label: Text('7 días')),
                ButtonSegment(value: 30, label: Text('30 días')),
              ],
              selected: {_windowDays},
              onSelectionChanged: (s) {
                setState(() => _windowDays = s.first);
                _load();
              },
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ] else if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: AppColors.brandBlue)),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'En vitrina',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              if (_featured.isEmpty)
                Text(
                  'Nadie está destacado. Use la lista de abajo para subir a un mayorista.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                )
              else
                for (final row in _featured)
                  _FeaturedImporterCard(
                    row: row,
                    busy: _busyId == row.importadorId,
                    featured: true,
                    onHighlight: () => _pickDuration(row),
                    onRemove: () => _setDays(row, 0),
                  ),
              const SizedBox(height: 14),
              Text(
                'Mayoristas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar mayorista…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final s in _FeaturedSort.values)
                    ChoiceChip(
                      label: Text(s.label, style: const TextStyle(fontSize: 11.5)),
                      selected: _sort == s,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _sort = s),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_candidates.isEmpty)
                Text(
                  _searchCtrl.text.trim().isEmpty
                      ? 'No hay más mayoristas para destacar.'
                      : 'Ningún mayorista coincide con la búsqueda.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                )
              else
                for (final row in _candidates)
                  _FeaturedImporterCard(
                    row: row,
                    busy: _busyId == row.importadorId,
                    featured: false,
                    onHighlight: () => _pickDuration(row),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _FeaturedSort { units, revenue, name }

extension on _FeaturedSort {
  String get label {
    switch (this) {
      case _FeaturedSort.units:
        return 'Más unidades';
      case _FeaturedSort.revenue:
        return 'Más REF';
      case _FeaturedSort.name:
        return 'Nombre';
    }
  }
}

class _FeaturedImporterCard extends StatelessWidget {
  const _FeaturedImporterCard({
    required this.row,
    required this.busy,
    required this.featured,
    required this.onHighlight,
    this.onRemove,
  });

  final ImporterSalesSnapshot row;
  final bool busy;
  final bool featured;
  final VoidCallback onHighlight;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final name = (row.businessName ?? '').trim().isEmpty
        ? 'Mayorista'
        : row.businessName!.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: featured ? AppColors.brandBlueContainer : AppColors.surfaceTinted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: featured
              ? AppColors.brandAccent.withOpacity(0.45)
              : AppColors.borderSubtle,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (featured) ...[
                  Icon(Icons.star, size: 16, color: AppColors.brandAccent),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (featured && row.catalogFeaturedUntil != null) ...[
              const SizedBox(height: 2),
              Text(
                'Hasta ${formatEsShortDateTime(row.catalogFeaturedUntil)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandBlue,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MetricChip(label: 'Activos', value: '${row.ordersActive}'),
                _MetricChip(label: 'Entregados', value: '${row.ordersEntregados}'),
                _MetricChip(label: 'Uds', value: '${row.unitsSold}'),
                _MetricChip(
                  label: 'REF',
                  value: formatRefAmount(row.revenueRef),
                ),
                _MetricChip(
                  label: 'Pausados',
                  value: '${row.productsPaused}',
                  warn: row.productsPaused > 0,
                ),
              ],
            ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 4),
                dense: true,
                title: const Text(
                  'Productos',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                children: [
                  if (row.topProducts.isEmpty && row.lowRotation.isEmpty)
                    Text(
                      'Sin movimiento en este período.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    )
                  else ...[
                    if (row.topProducts.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Más vendidos',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final p in row.topProducts.take(3))
                        _Line(
                          name: p.name,
                          trailing:
                              '${p.units} uds · ${formatRefAmount(p.revenue)} REF',
                        ),
                    ],
                    if (row.lowRotation.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Poca rotación',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final p in row.lowRotation.take(3))
                        _Line(
                          name: p.name,
                          trailing:
                              p.units == 0 ? 'Sin ventas' : '${p.units} uds',
                        ),
                    ],
                  ],
                ],
              ),
            ),
            Row(
              children: [
                if (!featured)
                  TextButton.icon(
                    onPressed: busy ? null : onHighlight,
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: const Text('Destacar'),
                  )
                else ...[
                  TextButton(
                    onPressed: busy ? null : onHighlight,
                    child: const Text('Renovar'),
                  ),
                  TextButton(
                    onPressed: busy ? null : onRemove,
                    child: const Text('Quitar'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.warn = false,
  });

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: warn ? AppColors.brandAccent.withOpacity(0.45) : AppColors.borderSubtle,
        ),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: warn ? AppColors.brandBlue : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.name, required this.trailing});

  final String name;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
