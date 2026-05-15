import 'package:flutter/material.dart';



import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
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
    final match = _rows.where((r) => r.id == pending).toList();
    if (match.isNotEmpty) {
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _expandedRequestId = _rowKey(match.first));
    } else if (!_loading) {
      _load();
    }
  }

  void _tryExpandFromPendingNotification() {
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    final match = _rows.where((r) => r.id == pending).toList();
    if (match.isNotEmpty) {
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _expandedRequestId = _rowKey(match.first));
    }
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

  String _rowKey(TransactionRequestModel r) =>
      r.importerSubOrderId != null ? '${r.id}::${r.importerSubOrderId}' : r.id;

  void _toggleExpand(TransactionRequestModel r) {
    final k = _rowKey(r);
    setState(() {
      _expandedRequestId = _expandedRequestId == k ? null : k;
    });
  }

  Future<void> _advance(
    BuildContext context,
    TransactionRequestModel r,
    String next,
  ) async {
    if (next == TransactionRequestStatus.enTransito && !r.hasProveedorFactura) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Adjunte la factura del proveedor antes de marcar «En tránsito» (despacho).',
          ),
        ),
      );
      return;
    }
    try {
      await SupabaseService.importerAdvanceTransactionRequest(
        id: r.id,
        newStatus: next,
        importerSubOrderId: r.importerSubOrderId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estado actualizado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
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
                'Cuando un aliado confirme un pedido sobre su inventario, aparecerá aquí '
                'para que confirme stock y avance la preparación. Use «Nuevos» para ver '
                'lo que acaba de ingresar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.35),
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _filtered;
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
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final r = filtered[i];
                            final next =
                                TransactionRequestStatus.nextForImporter(
                              r.status,
                            );
                            final headline = TransactionRequestStatus
                                .importerOperationalHeadline(r.status);
                            final rk = _rowKey(r);
                            return ImporterExpandableOrderCard(
                              request: r,
                              expanded: _expandedRequestId == rk,
                              onToggle: () => _toggleExpand(r),
                              statusLabel: TransactionRequestStatus
                                  .importerFilterStatusLabelEs(r.status),
                              operationalHeadline: headline,
                              nextStatus: next,
                              nextActionLabel: next != null
                                  ? TransactionRequestStatus.actionLabelForNext(
                                      next,
                                    )
                                  : null,
                              onAdvance: next != null
                                  ? () => _advance(context, r, next)
                                  : null,
                              expandedFooter: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ImporterOrderPagoVerificationSection(
                                    request: r,
                                    onChanged: _load,
                                  ),
                                  ImporterOrderInvoiceSection(
                                    request: r,
                                    onChanged: _load,
                                  ),
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
