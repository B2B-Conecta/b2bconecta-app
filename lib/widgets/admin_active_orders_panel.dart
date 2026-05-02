import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/app_home_role.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/transaction_request_filter_utils.dart';
import 'admin_expandable_order_card.dart';
import 'admin_motolink_anula_pedido_dialog.dart';
import 'admin_order_pre_transit_section.dart';
import 'admin_transportista_assignment_section.dart';
import 'transportista_factura_aliado_section.dart';
import 'admin_pago_revision_section.dart';
import 'efectivo_respaldo_registrar.dart';
import 'main_shell_tab.dart';
import 'order_list_filter_bar.dart';
import 'order_motolink_thread_section.dart';
import 'transaction_request_route_map_section.dart';

/// Pedidos activos del broker (pestaña Pedidos): no entregados ni rechazados.
class AdminActiveOrdersPanel extends StatefulWidget {
  const AdminActiveOrdersPanel({
    super.key,
    this.isTransportistaView = false,
  });

  /// Solo despacho: contacto + respaldo efectivo + hilo (sin acciones de broker).
  final bool isTransportistaView;

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
  String? _anularMotolinkBusyId;

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
          status: TransactionRequestStatus.pedidoListo,
          label: TransactionRequestStatus.labelEs(
            TransactionRequestStatus.pedidoListo,
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
    MainShellTabController.registerAdminActivosNotificationDeepLink(
      _onNotificationAdminActivosDeepLink,
    );
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerAdminActivosNotificationDeepLink(null);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onNotificationAdminActivosDeepLink() {
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
      var rows = await SupabaseService.fetchActiveTransactionRequestsForAdmin();
      if (widget.isTransportistaView) {
        rows = List<TransactionRequestModel>.from(rows)
          ..sort((a, b) {
            int priority(TransactionRequestModel x) {
              if (!x.hasAssignedTransportista) return 4;
              if (!x.transportistaReconocioAsignacion) return 0;
              if (x.status == TransactionRequestStatus.pedidoListo) return 1;
              if (x.status == TransactionRequestStatus.enTransito) return 2;
              return 3;
            }

            final c = priority(a).compareTo(priority(b));
            if (c != 0) return c;
            final ta = a.updatedAt ?? a.createdAt;
            final tb = b.updatedAt ?? b.createdAt;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
      }
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

  String _statusLabel(TransactionRequestModel r) => r.statusLabelEs();

  void _toggleExpand(String id) {
    setState(() {
      _expandedRequestId = _expandedRequestId == id ? null : id;
    });
  }

  Future<void> _anularPedidoPorMotolink(
    BuildContext context,
    TransactionRequestModel r,
  ) async {
    if (_anularMotolinkBusyId != null) return;
    final m = await showAdminMotolinkAnulaPedidoDialog(
      context,
      productName: r.productName ?? 'Producto',
    );
    if (m == null) return;
    if (!context.mounted) return;
    setState(() => _anularMotolinkBusyId = r.id);
    try {
      await SupabaseService.adminAnulaPedidoPorMotolink(
        transactionRequestId: r.id,
        motivo: m,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido anulado. Se notificó al aliado e importador.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!context.mounted) return;
      var msg = e.toString();
      if (msg.contains('no entregado') || msg.contains('en este estado')) {
        msg = 'No se puede anular este pedido en su estado actual.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo anular: $msg')),
      );
    } finally {
      if (mounted) setState(() => _anularMotolinkBusyId = null);
    }
  }

  Widget _buildAdminExpandedFooter(
    BuildContext context,
    TransactionRequestModel r,
  ) {
    if (widget.isTransportistaView) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contacto e importadores ya están en la ficha expandida (arriba).
          if (r.status == TransactionRequestStatus.enTransito) ...[
            TransactionRequestRouteMapSection(request: r),
            const SizedBox(height: 12),
          ],
          if (r.hasFacturaAliado) ...[
            TransportistaFacturaAliadoSection(request: r),
            const SizedBox(height: 12),
          ],
          EfectivoRespaldoRegistrar(
            request: r,
            onRegistered: _load,
          ),
          const Divider(height: 20),
          OrderMotolinkThreadSection(
            key: ValueKey<String>('trm-trans-${r.id}'),
            transactionRequestId: r.id,
            allowReplyAsAliado: false,
            allowReplyAsAdmin: false,
            allowReplyAsTransportista: true,
            onThreadChanged: _load,
            orderPrecioTotalUsd: r.precioTotal,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.motolinkPuedeAnularComoAdmin) ...[
          OutlinedButton.icon(
            onPressed: _anularMotolinkBusyId != null
                ? null
                : () => _anularPedidoPorMotolink(context, r),
            icon: _anularMotolinkBusyId == r.id
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.gpp_bad_outlined, size: 20, color: Colors.red.shade800),
            label: Text(
              _anularMotolinkBusyId == r.id
                  ? 'Anulando…'
                  : 'Anular pedido (MotoLink) — requiere motivo',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pedido aprobado o en curso: MotoLink puede cerrar la operación. '
            'Si había plan de cuotas, se limpia; el inventario vuelve si ya se descontó al facturar.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.35,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
        ],
        AdminTransportistaAssignmentSection(
          key: ValueKey<String>('tr-assign-${r.id}-${r.assignedTransportistaId ?? ''}'),
          request: r,
          onMutated: _load,
        ),
        if (r.status == TransactionRequestStatus.enTransito ||
            r.status == TransactionRequestStatus.entregado)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EfectivoRespaldoRegistrar(
              request: r,
              onRegistered: _load,
            ),
          ),
        if (r.status == TransactionRequestStatus.enPreparacion ||
            r.status == TransactionRequestStatus.pedidoListo)
          AdminOrderPreTransitSection(
            request: r,
            onRefresh: _load,
            onMarcarEnTransito: () => _marcarEnTransito(context, r),
          ),
        if (r.hasFacturaAliado &&
            (r.status == TransactionRequestStatus.enTransito ||
                r.status == TransactionRequestStatus.entregado))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminPagoRevisionSection(
              request: r,
              onRefresh: _load,
              highlightEntregadoPagado:
                  r.status == TransactionRequestStatus.entregado &&
                  r.pagoEstadoRevisionEfectivo == PagoRevisionEstado.aprobado,
            ),
          ),
        const Divider(height: 20),
        OrderMotolinkThreadSection(
          key: ValueKey<String>('trm-admin-${r.id}'),
          transactionRequestId: r.id,
          allowReplyAsAliado: false,
          allowReplyAsAdmin: true,
          onThreadChanged: _load,
          orderPrecioTotalUsd: r.precioTotal,
          creditPlanRescheduleLocked: r.creditPlanLockedForAdminReschedule,
        ),
      ],
    );
  }

  Future<void> _marcarEnTransito(
    BuildContext context,
    TransactionRequestModel r,
  ) async {
    try {
      await SupabaseService.adminMarcaPedidoEnTransito(requestId: r.id);
      try {
        await SupabaseService.adminTryAutoPublishRutaMapsUrl(r.id);
      } catch (_) {}
      if (!context.mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      // Evita desmontar el subárbol del pedido en el mismo frame que aún tiene foco/herencia activa.
      await SchedulerBinding.instance.endOfFrame;
      await Future<void>.delayed(Duration.zero);
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
              hintText: widget.isTransportistaView
                  ? 'Buscar por aliado, importador, producto o SKU'
                  : 'Buscar por producto, SKU o empresa',
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
                            expandedFooter:
                                _buildAdminExpandedFooter(context, r),
                            cardViewerRole: widget.isTransportistaView
                                ? AppHomeRole.transportista
                                : AppHomeRole.administrador,
                            onRequestMutated: _load,
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
