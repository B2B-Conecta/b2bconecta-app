import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/features/admin/owner_catalog_filter.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';

/// Owner: catálogo de un mayorista (solo lectura, incluye pausados).
class OwnerImporterCatalogScreen extends StatefulWidget {
  const OwnerImporterCatalogScreen({
    super.key,
    required this.importerId,
    required this.importerName,
  });

  final String importerId;
  final String importerName;

  static Future<void> open(
    BuildContext context, {
    required String importerId,
    required String importerName,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OwnerImporterCatalogScreen(
          importerId: importerId,
          importerName: importerName,
        ),
      ),
    );
  }

  @override
  State<OwnerImporterCatalogScreen> createState() =>
      _OwnerImporterCatalogScreenState();
}

class _OwnerImporterCatalogScreenState
    extends State<OwnerImporterCatalogScreen> {
  final _searchCtrl = TextEditingController();
  List<PartModel> _items = const [];
  bool _loading = true;
  String? _error;
  OwnerCatalogVisibility _visibility = OwnerCatalogVisibility.todos;

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
      final rows = await SupabaseService.ownerListImporterCatalog(
        importerId: widget.importerId,
      );
      if (!mounted) return;
      setState(() {
        _items = rows;
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

  List<PartModel> get _filtered => ownerCatalogFilter(
        items: _items,
        rawQuery: _searchCtrl.text,
        visibility: _visibility,
      );

  @override
  Widget build(BuildContext context) {
    final published = _items.where((p) => p.isActive).length;
    final paused = _items.length - published;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.importerName),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Catálogo del mayorista. Solo lectura: incluye SKUs en pausa '
                  'que las tiendas no ven.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatChip(
                      label: 'SKU',
                      value: '${_items.length}',
                    ),
                    _StatChip(
                      label: 'Publicados',
                      value: '$published',
                    ),
                    _StatChip(
                      label: 'En pausa',
                      value: '$paused',
                      highlight: paused > 0,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, SKU o categoría…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final v in OwnerCatalogVisibility.values)
                      ChoiceChip(
                        label: Text(switch (v) {
                          OwnerCatalogVisibility.todos => 'Todos',
                          OwnerCatalogVisibility.publicados => 'Publicados',
                          OwnerCatalogVisibility.pausados => 'En pausa',
                        }),
                        selected: _visibility == v,
                        onSelected: (_) => setState(() => _visibility = v),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  )
                : _error != null && _items.isEmpty
                    ? Center(
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
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.brand,
                        child: filtered.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 80),
                                  Center(
                                    child: Text(
                                      _items.isEmpty
                                          ? 'Este mayorista no tiene productos.'
                                          : 'Ningún SKU coincide con el filtro.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  24,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) =>
                                    _CatalogRow(part: filtered[i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? Colors.orange.shade800 : AppColors.brand;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '$label $value',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({required this.part});

  final PartModel part;

  @override
  Widget build(BuildContext context) {
    final cover = part.coverImageUrl;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: cover != null && cover.startsWith('http')
                    ? Image.network(
                        cover,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          part.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _VisibilityChip(active: part.isActive),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (part.sku != null) 'SKU ${part.sku}',
                      if (part.category != null) part.category,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${part.precio.toStringAsFixed(2)} USD · ${part.stock} u. · '
                    'mín. ${part.minOrderQty}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.fieldFill,
      child: Icon(
        Icons.precision_manufacturing_outlined,
        color: AppColors.textSecondary,
        size: 22,
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.successGreen : Colors.orange.shade800;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          active ? 'Publicado' : 'En pausa',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}
