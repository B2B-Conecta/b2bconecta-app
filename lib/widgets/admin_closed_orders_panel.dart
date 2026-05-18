import 'package:flutter/material.dart';

import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/transaction_request_filter_utils.dart';
import 'admin_expandable_order_card.dart';
import 'admin_pago_revision_section.dart';
import 'efectivo_respaldo_registrar.dart';
import 'order_list_filter_bar.dart';
import 'order_motolink_thread_section.dart';

/// Pedidos entregados o rechazados (pestaña Pedidos cerrados — admin).
class AdminClosedOrdersPanel extends StatefulWidget {
  const AdminClosedOrdersPanel({super.key});

  @override
  State<AdminClosedOrdersPanel> createState() => _AdminClosedOrdersPanelState();
}

class _AdminClosedOrdersPanelState extends State<AdminClosedOrdersPanel> {
  List<TransactionRequestModel> _rows = [];
  bool _loading = true;
  String? _error;
  String? _expandedRequestId;
  late final TextEditingController _searchCtrl;
  String? _statusFilter;

  static List<OrderStatusFilterOption> get _statusOptions => [
        OrderStatusFilterOption(
          status: TransactionRequestStatus.entregado,
          label: TransactionRequestStatus.labelEs(
            TransactionRequestStatus.entregado,
          ),
        ),
        OrderStatusFilterOption(
          status: TransactionRequestStatus.rechazado,
          label: TransactionRequestStatus.labelEs(
            TransactionRequestStatus.rechazado,
          ),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
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
      final rows = await SupabaseService.fetchClosedTransactionRequestsForAdmin();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        _expandedRequestId = null;
      });
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

  String _statusLabel(TransactionRequestModel r) => r.statusLabelEs();

  void _toggleExpand(String id) {
    setState(() {
      _expandedRequestId = _expandedRequestId == id ? null : id;
    });
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
            SizedBox(height: 120),
            Center(
              child: Text(
                'No hay pedidos cerrados.',
                textAlign: TextAlign.center,
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
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final r = filtered[i];
                            return AdminExpandableOrderCard(
                              request: r,
                              expanded: _expandedRequestId == r.id,
                              onToggle: () => _toggleExpand(r.id),
                              statusLabel: _statusLabel(r),
                              expandedFooter: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (r.hasFacturaAliado)
                                    AdminPagoRevisionSection(
                                      request: r,
                                      onRefresh: _load,
                                      highlightEntregadoPagado:
                                          r.status ==
                                              TransactionRequestStatus.entregado &&
                                          r.pagoEstadoRevisionEfectivo ==
                                              PagoRevisionEstado.aprobado,
                                    ),
                                  EfectivoRespaldoRegistrar(
                                    request: r,
                                    onRegistered: _load,
                                  ),
                                  const Divider(height: 20),
                                  OrderMotolinkThreadSection(
                                    key: ValueKey<String>(
                                      'trm-admin-closed-${r.id}',
                                    ),
                                    transactionRequestId: r.id,
                                    allowReplyAsAliado: false,
                                    allowReplyAsAdmin: true,
                                    onThreadChanged: _load,
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
