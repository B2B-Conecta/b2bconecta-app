import 'package:flutter/material.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/transaction_request_filter_utils.dart';
import 'admin_expandable_order_card.dart';
import 'admin_order_pre_transit_section.dart';
import 'order_list_filter_bar.dart';
import 'order_motolink_thread_section.dart';

/// Pedidos activos del broker (pestaña Pedidos): no entregados ni rechazados.
class AdminActiveOrdersPanel extends StatefulWidget {
  const AdminActiveOrdersPanel({super.key});

  @override
  State<AdminActiveOrdersPanel> createState() => _AdminActiveOrdersPanelState();
}

class _AdminActiveOrdersPanelState extends State<AdminActiveOrdersPanel> {
  List<TransactionRequestModel> _rows = [];
  bool _loading = true;
  String? _error;
  String? _expandedRequestId;
  late final TextEditingController _searchCtrl;
  String? _statusFilter;

  static List<OrderStatusFilterOption> get _statusOptions => [
        OrderStatusFilterOption(
          status: TransactionRequestStatus.aprobadoAdmin,
          label: TransactionRequestStatus.labelEs(
            TransactionRequestStatus.aprobadoAdmin,
          ),
        ),
        OrderStatusFilterOption(
          status: TransactionRequestStatus.enPreparacion,
          label: TransactionRequestStatus.labelEs(
            TransactionRequestStatus.enPreparacion,
          ),
        ),
        OrderStatusFilterOption(
          status: TransactionRequestStatus.enTransito,
          label: TransactionRequestStatus.labelEs(
            TransactionRequestStatus.enTransito,
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
      final rows = await SupabaseService.fetchActiveTransactionRequestsForAdmin();
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

  String _statusLabel(String s) => TransactionRequestStatus.labelEs(s);

  void _toggleExpand(String id) {
    setState(() {
      _expandedRequestId = _expandedRequestId == id ? null : id;
    });
  }

  Widget _buildAdminExpandedFooter(
    BuildContext context,
    TransactionRequestModel r,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.status == TransactionRequestStatus.enPreparacion)
          AdminOrderPreTransitSection(
            request: r,
            onRefresh: _load,
            onMarcarEnTransito: () => _promptMarkEnTransito(context, r),
          ),
        const Divider(height: 20),
        OrderMotolinkThreadSection(
          key: ValueKey<String>('trm-admin-${r.id}'),
          transactionRequestId: r.id,
          allowReplyAsAliado: false,
          allowReplyAsAdmin: true,
        ),
      ],
    );
  }

  Future<void> _promptMarkEnTransito(
    BuildContext context,
    TransactionRequestModel r,
  ) async {
    final ctrlDays = TextEditingController(text: '0');
    final ctrlHours = TextEditingController(text: '0');
    ({int days, int hours})? eta;
    try {
      eta = await showDialog<({int days, int hours})>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Tiempo estimado de tránsito'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Indique días y horas aproximadas hasta que el envío llegue al taller del aliado. '
                  'Si el aliado está cerca, puede dejar 0 días y solo horas.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrlDays,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Días (0–365)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrlHours,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Horas (0–23)',
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
                onPressed: () {
                  final d = int.tryParse(ctrlDays.text.trim()) ?? 0;
                  final h = int.tryParse(ctrlHours.text.trim()) ?? 0;
                  if (d < 0 || d > 365 || h < 0 || h > 23) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Use días entre 0 y 365, y horas entre 0 y 23.'),
                      ),
                    );
                    return;
                  }
                  if (d == 0 && h == 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Indique al menos un día o una hora de tránsito estimado.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx, (days: d, hours: h));
                },
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      );
    } finally {
      ctrlDays.dispose();
      ctrlHours.dispose();
    }
    if (eta == null || !context.mounted) return;
    try {
      await SupabaseService.adminMarcaPedidoEnTransito(
        requestId: r.id,
        transitEtaDays: eta.days,
        transitEtaHours: eta.hours,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido marcado en tránsito.')),
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
            SizedBox(height: 120),
            Center(
              child: Text(
                'No hay pedidos activos en curso.',
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
                            statusLabel: _statusLabel(r.status),
                            expandedFooter:
                                _buildAdminExpandedFooter(context, r),
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
