import 'package:flutter/material.dart';



import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../utils/importer_order_advance.dart';
import '../theme/app_theme.dart';
import '../utils/aliado_order_grouping.dart';
import '../utils/transaction_request_filter_utils.dart';
import 'importer_expandable_order_card.dart';
import 'importer_order_invoice_section.dart';
import 'importer_order_pago_verification_section.dart';
import 'main_shell_tab.dart';
import 'order_list_filter_bar.dart';

enum _ImporterQuickFilter {
  nuevos,
  enProceso,
  cerrados,
}

/// Pedidos del importador: ingreso directo, filtros rápidos y ciclo completo en una sola vista.
class ImporterActiveOrdersPanel extends StatefulWidget {
  const ImporterActiveOrdersPanel({super.key});

  @override
  State<ImporterActiveOrdersPanel> createState() =>
      _ImporterActiveOrdersPanelState();
}

class _ImporterActiveOrdersPanelState extends State<ImporterActiveOrdersPanel> {
  List<TransactionRequestModel> _rows = [];
  bool _loading = true;
  String? _error;
  String? _expandedRequestId;
  late final TextEditingController _searchCtrl;
  _ImporterQuickFilter _quickFilter = _ImporterQuickFilter.nuevos;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    MainShellTabController.registerImporterPedidosReload(() => _load());
    MainShellTabController.registerPedidosNotificationDeepLink(
      _onNotificationPedidosDeepLink,
    );
    MainShellTabController.registerImportadorValidadosNotificationDeepLink(
      _onNotificationPedidosDeepLink,
    );
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerImporterPedidosReload(null);
    MainShellTabController.registerPedidosNotificationDeepLink(null);
    MainShellTabController.registerImportadorValidadosNotificationDeepLink(null);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onNotificationPedidosDeepLink() {
    if (MainShellTabController.consumeImporterPedidosPreferNuevosFilter()) {
      setState(() => _quickFilter = _ImporterQuickFilter.nuevos);
    }
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    final key = _expandKeyForPendingId(pending);
    if (key != null) {
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _expandedRequestId = key);
    } else if (!_loading) {
      _load();
    }
  }

  void _tryExpandFromPendingNotification() {
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    final key = _expandKeyForPendingId(pending);
    if (key != null) {
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _expandedRequestId = key);
    }
  }

  /// Resuelve la fila expandida ante una notificación por `transaction_request_id`.
  String? _expandKeyForPendingId(String id) {
    for (final g in groupAliadoOrdersByCheckout(_rows)) {
      if (!g.any((r) => r.id == id)) continue;
      if (g.length == 1) return _rowKey(g.single);
      final statuses = g.map((x) => x.status).toSet();
      if (statuses.length > 1) {
        return _rowKey(g.firstWhere((r) => r.id == id));
      }
      return checkoutGroupExpandKey(g);
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows =
          await SupabaseService.fetchUnifiedTransactionRequestsForImporter();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
      _tryExpandFromPendingNotification();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() => _quickFilter = _ImporterQuickFilter.nuevos);
  }

  bool _matchesQuickFilter(TransactionRequestModel r) {
    final s = r.status;
    switch (_quickFilter) {
      case _ImporterQuickFilter.nuevos:
        return s == TransactionRequestStatus.pendiente;
      case _ImporterQuickFilter.enProceso:
        return s == TransactionRequestStatus.enPreparacion ||
            s == TransactionRequestStatus.pedidoListo ||
            s == TransactionRequestStatus.enTransito ||
            s == TransactionRequestStatus.enviado;
      case _ImporterQuickFilter.cerrados:
        return s == TransactionRequestStatus.entregado ||
            s == TransactionRequestStatus.rechazado;
    }
  }

  List<TransactionRequestModel> get _filtered {
    final searched = TransactionRequestFilterUtils.apply(
      _rows,
      searchQuery: _searchCtrl.text,
      statusFilter: null,
    );
    return searched.where(_matchesQuickFilter).toList();
  }

  String _rowKey(TransactionRequestModel r) =>
      r.importerSubOrderId != null ? '${r.id}::${r.importerSubOrderId}' : r.id;

  Widget _quickFilterBar() {
    Widget chip(String label, _ImporterQuickFilter value) {
      final sel = _quickFilter == value;
      return FilterChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _quickFilter = value),
        selectedColor: AppColors.brand.withOpacity(0.18),
        checkmarkColor: AppColors.brand,
        labelStyle: TextStyle(
          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          color: sel ? AppColors.brand : AppColors.textPrimary,
          fontSize: 12.5,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          chip(
            'Pendientes · nuevos',
            _ImporterQuickFilter.nuevos,
          ),
          chip('En proceso', _ImporterQuickFilter.enProceso),
          chip('Despachados · cerrados', _ImporterQuickFilter.cerrados),
        ],
      ),
    );
  }

  /// Agrupa por `checkout_group_id`; si un grupo tiene estados distintos, muestra tarjetas sueltas.
  List<List<TransactionRequestModel>> _groupsForDisplay(
    List<TransactionRequestModel> filtered,
  ) {
    final buckets = groupAliadoOrdersByCheckout(filtered);
    final out = <List<TransactionRequestModel>>[];
    for (final g in buckets) {
      if (g.length <= 1) {
        out.add(g);
        continue;
      }
      final statuses = g.map((x) => x.status).toSet();
      if (statuses.length == 1) {
        out.add(g);
      } else {
        for (final r in g) {
          out.add(<TransactionRequestModel>[r]);
        }
      }
    }
    return out;
  }

  String _displayGroupKey(List<TransactionRequestModel> g) {
    if (g.length == 1) return _rowKey(g.single);
    return checkoutGroupExpandKey(g);
  }

  void _toggleExpand(String key) {
    setState(() {
      _expandedRequestId = _expandedRequestId == key ? null : key;
    });
  }

  Future<void> _advanceGroup(
    BuildContext context,
    List<TransactionRequestModel> g,
    String next,
  ) async {
    final ok = await advanceImporterOrderGroup(
      context,
      lines: g,
      nextStatus: next,
    );
    if (!ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          next == TransactionRequestStatus.enTransito
              ? 'Pedido marcado en tránsito con ETA registrado.'
              : 'Estado actualizado.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!),
            ),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Aparecen aquí los pedidos que MotoLink te asigne. En «Nuevos» ves lo último.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.35),
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _filtered;
    final groups = _groupsForDisplay(filtered);
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrderListFilterBar(
                searchController: _searchCtrl,
                onSearchChanged: (_) => setState(() {}),
                hintText: 'Buscar por producto, SKU o aliado',
              ),
              _quickFilterBar(),
              Expanded(
                child: filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 48),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  'Ningún pedido coincide con los filtros.',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                TextButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Limpiar búsqueda y volver a Nuevos'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: groups.length,
                          itemBuilder: (context, i) {
                            final g = groups[i];
                            final primary = g.first;
                            final isBundle = g.length > 1;
                            final next =
                                TransactionRequestStatus.nextForImporter(
                              primary.status,
                            );
                            final headline = TransactionRequestStatus
                                .importerOperationalHeadline(primary.status);
                            final rk = _displayGroupKey(g);
                            return ImporterExpandableOrderCard(
                              request: primary,
                              checkoutGroupLines: isBundle ? g : null,
                              expanded: _expandedRequestId == rk,
                              onToggle: () => _toggleExpand(rk),
                              statusLabel: TransactionRequestStatus
                                  .importerFilterStatusLabelEs(primary.status),
                              operationalHeadline: headline,
                              nextStatus: next,
                              nextActionLabel: next != null
                                  ? TransactionRequestStatus.actionLabelForNext(
                                      next,
                                    )
                                  : null,
                              onAdvance: next != null
                                  ? () => _advanceGroup(context, g, next)
                                  : null,
                              onThreadChanged: _load,
                              expandedFooter: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (g.length == 1) ...[
                                    ImporterOrderPagoVerificationSection(
                                      request: g.single,
                                      onChanged: _load,
                                    ),
                                    ImporterOrderInvoiceSection(
                                      request: g.single,
                                      onChanged: _load,
                                    ),
                                  ] else ...[
                                    ImporterOrderPagoVerificationSection(
                                      request: g.first,
                                      bundleLines: g,
                                      onChanged: _load,
                                    ),
                                    const SizedBox(height: 12),
                                    ImporterOrderInvoiceSection(
                                      request: g.first,
                                      invoiceBundleLines: g,
                                      onChanged: _load,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (_loading)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
