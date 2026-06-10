import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/admin_aliado_morosidad_flag.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/admin_order_panel_utils.dart';
import '../utils/aliado_order_grouping.dart';
import '../utils/notification_related_order_match.dart';
import '../models/importer_pedidos_filters_draft.dart';
import '../utils/importer_order_date.dart';
import '../utils/transaction_request_filter_utils.dart';
import 'importer_pedidos_filters_sheet.dart';
import 'admin_checkout_group_expanded_section.dart';
import 'admin_expandable_order_card.dart';
import 'admin_motolink_anula_pedido_dialog.dart';
import 'admin_order_pre_transit_section.dart';
import 'admin_aliado_morosidad_actions.dart';
import 'admin_pago_revision_section.dart';
import 'efectivo_respaldo_registrar.dart';
import 'main_shell_tab.dart';
import 'order_card_collapsible_layout.dart';
import 'profile_section_helpers.dart';
import 'order_list_filter_bar.dart';
import 'order_motolink_thread_section.dart';

/// Bandeja admin unificada: pedidos en curso, cerrados o todos, con filtros por estado.
class AdminOrdersPanel extends StatefulWidget {
  const AdminOrdersPanel({super.key});

  @override
  State<AdminOrdersPanel> createState() => _AdminOrdersPanelState();
}

enum _AdminOrdersScope {
  enCurso,
  cerrados,
  todos,
}

class _AdminOrdersPanelState extends State<AdminOrdersPanel> {
  List<TransactionRequestModel> _rows = [];
  bool _loading = true;
  String? _error;
  String? _expandedRequestId;
  late final TextEditingController _searchCtrl;
  String? _statusFilter;
  String? _anularMotolinkBusyId;
  bool _morosoOnly = false;
  Map<String, AdminAliadoMorosidadFlag> _morosidadFlags = {};
  _AdminOrdersScope _scope = _AdminOrdersScope.enCurso;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  List<OrderStatusFilterOption> get _statusChipOptions {
    final statuses = switch (_scope) {
      _AdminOrdersScope.enCurso =>
        TransactionRequestStatus.motoconectaAdminOperationalActive,
      _AdminOrdersScope.cerrados => TransactionRequestStatus.adminClosedOrders,
      _AdminOrdersScope.todos =>
        TransactionRequestStatus.adminBandejaUnifiedStatuses,
    };
    return statuses
        .map(
          (s) => OrderStatusFilterOption(
            status: s,
            label: TransactionRequestStatus.labelEs(s),
          ),
        )
        .toList();
  }

  String get _emptyMessage => switch (_scope) {
        _AdminOrdersScope.enCurso => 'No hay pedidos en curso.',
        _AdminOrdersScope.cerrados => 'No hay pedidos cerrados.',
        _AdminOrdersScope.todos => 'No hay pedidos.',
      };

  bool get _showMorosoChip =>
      _scope == _AdminOrdersScope.cerrados || _scope == _AdminOrdersScope.todos;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    MainShellTabController.registerAdminPedidosBandejaNotificationHandler(
      _onBandejaNotificationFromMain,
    );
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerAdminPedidosBandejaNotificationHandler(null);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onBandejaNotificationFromMain() {
    final pending = MainShellTabController.consumePendingAdminPedidosScope();
    if (pending != null) {
      setState(() {
        _scope = switch (pending) {
          AdminPedidosNotificationScope.enCurso => _AdminOrdersScope.enCurso,
          AdminPedidosNotificationScope.cerrados => _AdminOrdersScope.cerrados,
        };
        _statusFilter = null;
        _morosoOnly = false;
      });
    }
    unawaited(_load());
  }

  void _tryExpandFromPendingNotification() {
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    final expandId = adminExpandRequestIdForNotification(_rows, pending);
    if (expandId != null) {
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _expandedRequestId = expandId);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<TransactionRequestModel> rows;
      Map<String, AdminAliadoMorosidadFlag> flags = {};

      switch (_scope) {
        case _AdminOrdersScope.enCurso:
          rows = await SupabaseService.fetchActiveTransactionRequestsForAdmin();
          break;
        case _AdminOrdersScope.cerrados:
          rows = await SupabaseService.fetchClosedTransactionRequestsForAdmin();
          flags = await SupabaseService.adminAliadosPedidosMorososFlags();
          break;
        case _AdminOrdersScope.todos:
          rows =
              await SupabaseService.fetchUnifiedTransactionRequestsForAdmin();
          flags = await SupabaseService.adminAliadosPedidosMorososFlags();
          break;
      }

      if (!mounted) return;
      final prevExpanded = _expandedRequestId;
      setState(() {
        _rows = rows;
        _morosidadFlags = flags;
        _loading = false;
        _expandedRequestId = prevExpanded;
      });
      _tryExpandFromPendingNotification();
      if (_scope == _AdminOrdersScope.enCurso) {
      }
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
    setState(() {
      _statusFilter = null;
      _morosoOnly = false;
      _dateFrom = null;
      _dateTo = null;
    });
  }

  Future<void> _openDateFilters() async {
    final draft = await ImporterPedidosFiltersSheet.show(
      context,
      initial: ImporterPedidosFiltersDraft(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      ),
    );
    if (draft == null || !mounted) return;
    setState(() {
      _dateFrom = draft.dateFrom;
      _dateTo = draft.dateTo;
    });
  }

  bool get _hasDateFilter => _dateFrom != null || _dateTo != null;

  void _onScopeChanged(_AdminOrdersScope next) {
    if (next == _scope) return;
    setState(() {
      _scope = next;
      _statusFilter = null;
      _morosoOnly = false;
      _dateFrom = null;
      _dateTo = null;
    });
    _load();
  }

  List<TransactionRequestModel> get _filteredFlat {
    final list = TransactionRequestFilterUtils.apply(
      _rows,
      searchQuery: _searchCtrl.text,
      statusFilter: _statusFilter,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      useOrderPanelDate: true,
    );
    list.sort(ImporterOrderDate.compareByFechaReciente);
    return list;
  }

  List<List<TransactionRequestModel>> get _displayGroups {
    var groups = groupAdminOrdersForDisplay(_filteredFlat);
    if (_showMorosoChip && _morosoOnly) {
      groups = groups.where((g) => g.any((r) => r.esPedidoMoroso)).toList();
    }
    return groups;
  }

  void _toggleExpand(String id) {
    setState(() {
      _expandedRequestId = _expandedRequestId == id ? null : id;
    });
  }

  bool _groupHasOperational(List<TransactionRequestModel> g) => g.any(
        (r) => TransactionRequestStatus.isAdminBandejaOperational(r.status),
      );

  bool _groupCanAnular(List<TransactionRequestModel> g) =>
      g.any((r) => r.motolinkPuedeAnularComoAdmin);

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

  Future<void> _marcarEnTransito(
    BuildContext context,
    TransactionRequestModel r,
  ) async {
    try {
      await SupabaseService.adminMarcaPedidoEnTransito(requestId: r.id);
      if (!context.mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
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

  Widget _buildOperationalSingleFooter(
    BuildContext context,
    TransactionRequestModel r,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.motolinkPuedeAnularComoAdmin) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _anularMotolinkBusyId != null
                      ? null
                      : () => _anularPedidoPorMotolink(context, r),
                  icon: _anularMotolinkBusyId == r.id
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.gpp_bad_outlined,
                          size: 20, color: Colors.red.shade800),
                  label: Text(
                    _anularMotolinkBusyId == r.id
                        ? 'Anulando…'
                        : 'Anular pedido (MotoLink)',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade800,
                  ),
                ),
              ),
              const ProfileInfoIcon(
                title: 'Anular pedido',
                message: OrderSectionHelp.adminAnularPedido,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
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
        if (r.hasProveedorFactura &&
            (r.status == TransactionRequestStatus.enTransito ||
                r.status == TransactionRequestStatus.entregado))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminPagoRevisionSection(
              request: r,
              onRefresh: _load,
              highlightEntregadoPagado: r.status ==
                      TransactionRequestStatus.entregado &&
                  r.pagoEstadoRevisionEfectivo == PagoRevisionEstado.aprobado,
            ),
          ),
        const SizedBox(height: kOrderCardSectionGap),
        OrderCardCollapsibleSection(
          title: 'Mensajes',
          subtitle: 'Hilo con aliado, importador y supervisión MotoLink',
          infoMessage: OrderSectionHelp.chatPedido,
          child: OrderMotolinkThreadSection(
            key: ValueKey<String>('trm-admin-${r.id}'),
            transactionRequestId: r.id,
            allowReplyAsAliado: false,
            allowReplyAsAdmin: true,
            onThreadChanged: _load,
            suppressBuiltinTitle: true,
            suppressInlineHelp: true,
          ),
        ),
      ],
    );
  }

  Widget _buildClosedSingleFooter(
    BuildContext context,
    TransactionRequestModel primary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (primary.esPedidoMoroso) ...[
          AdminAliadoMorosidadActions(
            aliadoId: primary.aliadoId,
            aliadoName: primary.aliadoBusinessName ?? 'Aliado',
            pedidosSuspendidosMorosidad: _morosidadFlags[primary.aliadoId]
                    ?.pedidosSuspendidosMorosidad ??
                false,
            onChanged: _load,
          ),
          const SizedBox(height: 10),
        ],
        if (primary.hasProveedorFactura)
          AdminPagoRevisionSection(
            request: primary,
            onRefresh: _load,
            highlightEntregadoPagado:
                primary.status == TransactionRequestStatus.entregado &&
                    primary.pagoEstadoRevisionEfectivo ==
                        PagoRevisionEstado.aprobado,
          ),
        EfectivoRespaldoRegistrar(
          request: primary,
          onRegistered: _load,
        ),
        const SizedBox(height: kOrderCardSectionGap),
        OrderCardCollapsibleSection(
          title: 'Mensajes',
          subtitle: 'Hilo con aliado, importador y supervisión MotoLink',
          infoMessage: OrderSectionHelp.chatPedido,
          child: OrderMotolinkThreadSection(
            key: ValueKey<String>('trm-admin-closed-${primary.id}'),
            transactionRequestId: primary.id,
            allowReplyAsAliado: false,
            allowReplyAsAdmin: true,
            onThreadChanged: _load,
            suppressBuiltinTitle: true,
            suppressInlineHelp: true,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedFooter(
    BuildContext context,
    List<TransactionRequestModel> group,
  ) {
    if (group.length > 1) {
      final morosoFooter = _showMorosoChip && adminCheckoutGroupEsMoroso(group)
          ? AdminAliadoMorosidadActions(
              aliadoId: adminCheckoutGroupMorosoRef(group).aliadoId,
              aliadoName:
                  adminCheckoutGroupMorosoRef(group).aliadoBusinessName ??
                      'Aliado',
              pedidosSuspendidosMorosidad:
                  _morosidadFlags[adminCheckoutGroupMorosoRef(group).aliadoId]
                          ?.pedidosSuspendidosMorosidad ??
                      false,
              onChanged: _load,
            )
          : null;
      return AdminCheckoutGroupExpandedSection(
        lines: group,
        onRefresh: _load,
        onMarcarEnTransito: _groupHasOperational(group)
            ? (r) => _marcarEnTransito(context, r)
            : null,
        onAnularMotolink: _groupCanAnular(group)
            ? (r) => _anularPedidoPorMotolink(context, r)
            : null,
        anularBusyId: _anularMotolinkBusyId,
        morosidadFooter: morosoFooter,
      );
    }

    final r = group.single;
    if (TransactionRequestStatus.isAdminBandejaClosed(r.status)) {
      return _buildClosedSingleFooter(context, r);
    }
    return _buildOperationalSingleFooter(context, r);
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          children: [
            _buildScopeBar(context),
            const SizedBox(height: 16),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: Center(child: Text(_emptyMessage)),
            ),
          ],
        ),
      );
    }

    final groups = _displayGroups;
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildScopeBar(context),
              OrderListFilterBar(
                searchController: _searchCtrl,
                onSearchChanged: (_) => setState(() {}),
                hintText: 'Buscar por producto, SKU o empresa',
                statusOptions: _statusChipOptions,
                selectedStatus: _statusFilter,
                onStatusChanged: (s) => setState(() => _statusFilter = s),
                morosoOnly: _showMorosoChip ? _morosoOnly : false,
                onMorosoOnlyChanged: _showMorosoChip
                    ? (v) => setState(() => _morosoOnly = v)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: Text(_hasDateFilter ? 'Fecha ✓' : 'Filtrar por fecha'),
                    selected: _hasDateFilter,
                    onSelected: (_) => _openDateFilters(),
                    selectedColor: AppColors.brandBlue.withOpacity(0.18),
                    checkmarkColor: AppColors.brandBlue,
                    avatar: Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: _hasDateFilter
                          ? AppColors.brandBlue
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: groups.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 48),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  'Ningún pedido coincide con los filtros.',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
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
                          itemCount: groups.length,
                          itemBuilder: (context, i) {
                            final g = groups[i];
                            final primary = g.first;
                            final expandKey = checkoutGroupExpandKey(g);
                            return AdminExpandableOrderCard(
                              request: primary,
                              checkoutGroupLines: g.length > 1 ? g : null,
                              expanded: _expandedRequestId == expandKey,
                              onToggle: () => _toggleExpand(expandKey),
                              statusLabel: adminCheckoutGroupStatusLabel(g),
                              expandedFooter: _buildExpandedFooter(context, g),
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

  Widget _buildScopeBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: SegmentedButton<_AdminOrdersScope>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: _AdminOrdersScope.enCurso,
            label: Text('En curso'),
            icon: Icon(Icons.local_shipping_outlined, size: 18),
          ),
          ButtonSegment(
            value: _AdminOrdersScope.cerrados,
            label: Text('Cerrados'),
            icon: Icon(Icons.archive_outlined, size: 18),
          ),
          ButtonSegment(
            value: _AdminOrdersScope.todos,
            label: Text('Todos'),
            icon: Icon(Icons.dashboard_outlined, size: 18),
          ),
        ],
        selected: {_scope},
        onSelectionChanged: (next) {
          if (next.isEmpty) return;
          _onScopeChanged(next.first);
        },
      ),
    );
  }
}
