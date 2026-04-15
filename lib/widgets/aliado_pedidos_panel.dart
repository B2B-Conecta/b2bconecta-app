import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/transaction_request_filter_utils.dart';
import 'aliado_expandable_order_card.dart';
import 'aliado_order_pago_section.dart';
import 'main_shell_tab.dart';
import 'order_motolink_thread_section.dart';
import 'order_list_filter_bar.dart';

/// Pedidos en curso y cerrados del aliado (pestaña Pedidos).
class AliadoPedidosPanel extends StatefulWidget {
  const AliadoPedidosPanel({super.key});

  @override
  State<AliadoPedidosPanel> createState() => _AliadoPedidosPanelState();
}

class _AliadoPedidosPanelState extends State<AliadoPedidosPanel> {
  List<TransactionRequestModel> _rows = [];
  bool _loading = true;
  String? _error;
  String? _expandedRequestId;
  late final TextEditingController _searchCtrl;
  String? _statusFilter;

  static List<OrderStatusFilterOption> get _statusOptions =>
      TransactionRequestStatus.aliadoPedidosActivosYCerrados
          .map(
            (s) => OrderStatusFilterOption(
              status: s,
              label: TransactionRequestStatus.labelEs(s),
            ),
          )
          .toList();

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    MainShellTabController.registerPedidosNotificationDeepLink(
      _onNotificationPedidosDeepLink,
    );
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerPedidosNotificationDeepLink(null);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onNotificationPedidosDeepLink() {
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    if (_rows.any((r) => r.id == pending)) {
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _expandedRequestId = pending);
    } else if (!_loading) {
      _load();
    }
  }

  void _tryExpandFromPendingNotification() {
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    if (_rows.any((r) => r.id == pending)) {
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _expandedRequestId = pending);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows =
          await SupabaseService.fetchMyPedidosActivosYCerradosForAliado();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        _expandedRequestId = null;
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
    setState(() => _statusFilter = null);
  }

  List<TransactionRequestModel> get _filtered {
    return TransactionRequestFilterUtils.apply(
      _rows,
      searchQuery: _searchCtrl.text,
      statusFilter: _statusFilter,
    );
  }

  void _toggleExpand(String id) {
    setState(() {
      _expandedRequestId = _expandedRequestId == id ? null : id;
    });
  }

  String _label(String s) => TransactionRequestStatus.labelEs(s);

  bool _esEnCurso(String status) =>
      TransactionRequestStatus.aliadoPedidosEnCurso.contains(status);

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
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
                'Cuando MotoLink apruebe una solicitud, verás aquí el pedido en curso o cerrado.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _filtered;
    final enCurso = filtered.where((r) => _esEnCurso(r.status)).toList();
    final cerrados = filtered.where((r) => !_esEnCurso(r.status)).toList();

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrderListFilterBar(
                searchController: _searchCtrl,
                onSearchChanged: (_) => setState(() {}),
                hintText: 'Buscar por producto, SKU o importador',
                statusOptions: _statusOptions,
                selectedStatus: _statusFilter,
                onStatusChanged: (s) => setState(() => _statusFilter = s),
              ),
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
                                  child: const Text('Limpiar filtros'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: [
                            if (enCurso.isNotEmpty) ...[
                              _sectionTitle('En curso'),
                              ...enCurso.map(
                                (r) => AliadoExpandableOrderCard(
                                  request: r,
                                  expanded: _expandedRequestId == r.id,
                                  onToggle: () => _toggleExpand(r.id),
                                  statusLabel: _label(r.status),
                                  expandedFooter: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AliadoOrderPagoSection(
                                        request: r,
                                        onChanged: _load,
                                      ),
                                      OrderMotolinkThreadSection(
                                        key: ValueKey<String>(
                                          'trm-aliado-${r.id}',
                                        ),
                                        transactionRequestId: r.id,
                                        allowReplyAsAliado: _esEnCurso(r.status),
                                        allowReplyAsAdmin: false,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (cerrados.isNotEmpty) ...[
                              _sectionTitle('Cerrados'),
                              ...cerrados.map(
                                (r) => AliadoExpandableOrderCard(
                                  request: r,
                                  expanded: _expandedRequestId == r.id,
                                  onToggle: () => _toggleExpand(r.id),
                                  statusLabel: _label(r.status),
                                  expandedFooter: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AliadoOrderPagoSection(
                                        request: r,
                                        onChanged: _load,
                                      ),
                                      OrderMotolinkThreadSection(
                                        key: ValueKey<String>(
                                          'trm-aliado-${r.id}',
                                        ),
                                        transactionRequestId: r.id,
                                        allowReplyAsAliado: _esEnCurso(r.status),
                                        allowReplyAsAdmin: false,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
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
