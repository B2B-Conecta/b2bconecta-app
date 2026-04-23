import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/transaction_request_filter_utils.dart';
import 'aliado_cancelar_pedido_dialog.dart';
import 'aliado_expandable_order_card.dart';
import 'order_list_filter_bar.dart';

/// Solicitudes pendientes de validación MotoLink (pestaña Solicitudes — aliado).
class AliadoMyRequestsPanel extends StatefulWidget {
  const AliadoMyRequestsPanel({super.key});

  @override
  State<AliadoMyRequestsPanel> createState() => _AliadoMyRequestsPanelState();
}

class _AliadoMyRequestsPanelState extends State<AliadoMyRequestsPanel> {
  List<TransactionRequestModel> _rows = [];
  bool _loading = true;
  String? _error;
  String? _expandedRequestId;
  String? _cancelarBusyId;
  late final TextEditingController _searchCtrl;

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
      final rows = await SupabaseService.fetchMyPendingValidationForAliado();
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
    setState(() {});
  }

  List<TransactionRequestModel> get _filtered {
    return TransactionRequestFilterUtils.apply(
      _rows,
      searchQuery: _searchCtrl.text,
      statusFilter: null,
    );
  }

  void _toggleExpand(String id) {
    setState(() {
      _expandedRequestId = _expandedRequestId == id ? null : id;
    });
  }

  String _label(TransactionRequestModel r) =>
      r.statusLabelEs(aliadoViewer: true);

  Future<void> _cancelarPendiente(
    BuildContext context,
    TransactionRequestModel r,
  ) async {
    if (_cancelarBusyId != null) return;
    final m = await showAliadoCancelarPedidoPendienteDialog(context);
    if (m == null) return;
    if (!context.mounted) return;
    setState(() => _cancelarBusyId = r.id);
    try {
      await SupabaseService.aliadoCancelaPedidoPendiente(
        transactionRequestId: r.id,
        motivo: m,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud cancelada. MotoLink ha sido notificada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!context.mounted) return;
      var msg = e.toString();
      if (msg.contains('Solo puede cancelar mientras')) {
        msg =
            'Solo puede cancelar antes de que MotoLink apruebe la solicitud.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar: $msg')),
      );
    } finally {
      if (mounted) setState(() => _cancelarBusyId = null);
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
              child: Text('$_error'),
            ),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'No tienes solicitudes pendientes de validación por MotoLink.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
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
                hintText: 'Buscar por producto, SKU o importador',
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
                                  'Ninguna solicitud coincide con la búsqueda.',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                TextButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Limpiar búsqueda'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _load(),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final r = filtered[i];
                            return AliadoExpandableOrderCard(
                              request: r,
                              expanded: _expandedRequestId == r.id,
                              onToggle: () => _toggleExpand(r.id),
                              statusLabel: _label(r),
                              onCancelarSolicitudPendiente: r.status ==
                                      TransactionRequestStatus.pendiente
                                  ? () => _cancelarPendiente(context, r)
                                  : null,
                              cancelarSolicitudPendienteBusy:
                                  _cancelarBusyId == r.id,
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
