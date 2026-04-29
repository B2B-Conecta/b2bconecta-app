import 'package:flutter/material.dart';

import '../models/profile_model.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/transaction_request_filter_utils.dart';
import 'aliado_cancelar_pedido_dialog.dart';
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
  ProfileModel? _profile;
  double _openCreditExposureSum = 0;
  bool _loading = true;
  String? _error;
  String? _expandedRequestId;
  late final TextEditingController _searchCtrl;
  String? _statusFilter;
  String? _entregaBusyId;
  String? _cancelarBusyId;

  static List<OrderStatusFilterOption> get _statusOptions =>
      TransactionRequestStatus.aliadoPedidosActivosYCerrados
          .map(
            (s) => OrderStatusFilterOption(
              status: s,
              label: TransactionRequestStatus.labelEs(
                s,
              ),
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
      final profile = await SupabaseService.fetchMyProfile();
      final exposure =
          await SupabaseService.fetchOpenCreditExposureForCurrentAliado();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _profile = profile;
        _openCreditExposureSum = exposure;
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
      } else if (msg.contains('Debe indicar un motivo') ||
          msg.contains('3 caracteres')) {
        msg = 'El motivo es obligatorio (mín. 3 caracteres).';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar: $msg')),
      );
    } finally {
      if (mounted) {
        setState(() => _cancelarBusyId = null);
      }
    }
  }

  Future<void> _confirmarEntrega(
    BuildContext context,
    TransactionRequestModel r,
  ) async {
    if (_entregaBusyId != null) return;
    setState(() => _entregaBusyId = r.id);
    try {
      final pagoPendienteAntes = r.pagoMotolinkPendienteEnTransito;
      await SupabaseService.aliadoMarcarPedidoEntregado(r.id);
      MainShellTabController.notifyImporterInventoryReload();
      if (!context.mounted) return;
      if (pagoPendienteAntes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Recepción registrada. La mercancía queda como entregada; el comprobante de pago '
              'sigue pendiente de registrar o aprobar por MotoLink. Revise la ficha del pedido.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Recepción confirmada. El pedido queda cerrado y registrado para MotoLink.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _load();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _entregaBusyId = null);
    }
  }

  String _label(TransactionRequestModel r) =>
      r.statusLabelEs(aliadoViewer: true);

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
                                  statusLabel: _label(r),
                                  onConfirmarRecepcion:
                                      r.status ==
                                              TransactionRequestStatus
                                                  .enTransito
                                          ? () => _confirmarEntrega(context, r)
                                          : null,
                                  confirmarRecepcionBusy:
                                      _entregaBusyId == r.id,
                                  onCancelarSolicitudPendiente: r
                                          .aliadoPuedeCancelarAntesDeGestionImportadores
                                      ? () => _cancelarPendiente(
                                            context,
                                            r,
                                          )
                                      : null,
                                  cancelarSolicitudPendienteBusy:
                                      _cancelarBusyId == r.id,
                                  expandedFooter: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AliadoOrderPagoSection(
                                        request: r,
                                        profile: _profile,
                                        openCreditExposureSum:
                                            _openCreditExposureSum,
                                        onChanged: _load,
                                      ),
                                      OrderMotolinkThreadSection(
                                        key: ValueKey<String>(
                                          'trm-aliado-${r.id}',
                                        ),
                                        transactionRequestId: r.id,
                                        allowReplyAsAliado: _esEnCurso(r.status),
                                        allowReplyAsAdmin: false,
                                        onThreadChanged: _load,
                                        orderPrecioTotalUsd: r.precioTotal,
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
                                  statusLabel: _label(r),
                                  onConfirmarRecepcion:
                                      r.status ==
                                              TransactionRequestStatus
                                                  .enTransito
                                          ? () => _confirmarEntrega(context, r)
                                          : null,
                                  confirmarRecepcionBusy:
                                      _entregaBusyId == r.id,
                                  onCancelarSolicitudPendiente: r
                                          .aliadoPuedeCancelarAntesDeGestionImportadores
                                      ? () => _cancelarPendiente(
                                            context,
                                            r,
                                          )
                                      : null,
                                  cancelarSolicitudPendienteBusy:
                                      _cancelarBusyId == r.id,
                                  expandedFooter: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      AliadoOrderPagoSection(
                                        request: r,
                                        profile: _profile,
                                        openCreditExposureSum:
                                            _openCreditExposureSum,
                                        onChanged: _load,
                                      ),
                                      OrderMotolinkThreadSection(
                                        key: ValueKey<String>(
                                          'trm-aliado-${r.id}',
                                        ),
                                        transactionRequestId: r.id,
                                        allowReplyAsAliado: _esEnCurso(r.status),
                                        allowReplyAsAdmin: false,
                                        onThreadChanged: _load,
                                        orderPrecioTotalUsd: r.precioTotal,
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
