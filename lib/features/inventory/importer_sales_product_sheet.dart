import 'dart:async';

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'importer_sales_snapshot.dart';

Future<void> showImporterSalesProductSheet({
  required BuildContext context,
  required String kind,
  required int days,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _ImporterSalesProductSheet(kind: kind, days: days),
  );
}

class _ImporterSalesProductSheet extends StatefulWidget {
  const _ImporterSalesProductSheet({
    required this.kind,
    required this.days,
  });

  final String kind;
  final int days;

  @override
  State<_ImporterSalesProductSheet> createState() =>
      _ImporterSalesProductSheetState();
}

class _ImporterSalesProductSheetState extends State<_ImporterSalesProductSheet> {
  static const _pageSize = 25;
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  List<ImporterSalesProductStat> _items = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  bool get _isTop => widget.kind == 'top';

  String get _title => _isTop ? 'Más vendidos' : 'Poca rotación';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _load(reset: true);
    });
  }

  void _onScroll() {
    if (_loadingMore || _loading) return;
    if (_items.length >= _total) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _items = [];
      });
    } else {
      if (_loadingMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final page = await SupabaseService.fetchMySalesProductPage(
        kind: widget.kind,
        days: widget.days,
        search: _searchCtrl.text.trim(),
        limit: _pageSize,
        offset: reset ? 0 : _items.length,
      );
      if (!mounted) return;
      setState(() {
        _total = page.total;
        _items = reset ? page.items : [..._items, ...page.items];
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el listado.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return SizedBox(
      height: h * 0.88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _total == 0
                      ? 'Últimos ${widget.days} días'
                      : '$_total resultados · últimos ${widget.days} días',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Buscar por nombre…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar',
                            onPressed: () => _searchCtrl.clear(),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            TextButton(
                              onPressed: () => _load(reset: true),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _items.isEmpty
                        ? Center(
                            child: Text(
                              _searchCtrl.text.trim().isEmpty
                                  ? 'No hay productos en este listado.'
                                  : 'Ningún SKU coincide con la búsqueda.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _items.length + (_loadingMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: AppColors.divider),
                            itemBuilder: (context, i) {
                              if (i >= _items.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final p = _items[i];
                              final trailing = _isTop
                                  ? '${p.units} uds · ${formatRefAmount(p.revenue)} REF'
                                  : (p.units == 0 ? 'Sin ventas' : '${p.units} uds');
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor:
                                      AppColors.brandAccent.withOpacity(0.12),
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.brandBlue,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  p.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                trailing: Text(
                                  trailing,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
