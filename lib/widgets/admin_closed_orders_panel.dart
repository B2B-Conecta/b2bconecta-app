import 'package:flutter/material.dart';

import '../models/admin_aliado_morosidad_flag.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/admin_order_panel_utils.dart';
import '../utils/aliado_order_grouping.dart';
import '../utils/transaction_request_filter_utils.dart';
import 'admin_checkout_group_expanded_section.dart';
import 'admin_aliado_morosidad_actions.dart';
import 'admin_expandable_order_card.dart';
import 'admin_pago_revision_section.dart';
import 'efectivo_respaldo_registrar.dart';
import '../utils/notification_related_order_match.dart';
import 'main_shell_tab.dart';
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
  bool _morosoOnly = false;
  Map<String, AdminAliadoMorosidadFlag> _morosidadFlags = {};

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
    MainShellTabController.registerAdminCerradosNotificationDeepLink(
      _onNotificationAdminCerradosDeepLink,
    );
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerAdminCerradosNotificationDeepLink(null);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onNotificationAdminCerradosDeepLink() {
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    final expandId = adminExpandRequestIdForNotification(_rows, pending);
    if (expandId != null) {
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _expandedRequestId = expandId);
    } else if (!_loading) {
      _load();
    }
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
      final rows = await SupabaseService.fetchClosedTransactionRequestsForAdmin();
      final flags = await SupabaseService.adminAliadosPedidosMorososFlags();
      if (!mounted) return;
      final prevExpanded = _expandedRequestId;
      setState(() {
        _rows = rows;
        _morosidadFlags = flags;
        _loading = false;
        _expandedRequestId = prevExpanded;
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
    setState(() {
      _statusFilter = null;
      _morosoOnly = false;
    });
  }

  List<TransactionRequestModel> get _filteredFlat {
    return TransactionRequestFilterUtils.apply(
      _rows,
      searchQuery: _searchCtrl.text,
      statusFilter: _statusFilter,
    );
  }

  List<List<TransactionRequestModel>> get _displayGroups {
    var groups = groupAdminOrdersForDisplay(_filteredFlat);
    if (_morosoOnly) {
      groups = groups
          .where((g) => g.any((r) => r.esPedidoMoroso))
          .toList();
    }
    return groups;
  }

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

    final groups = _displayGroups;
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
                morosoOnly: _morosoOnly,
                onMorosoOnlyChanged: (v) => setState(() => _morosoOnly = v),
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
                          itemCount: groups.length,
                          itemBuilder: (context, i) {
                            final g = groups[i];
                            final primary = g.first;
                            final expandKey = checkoutGroupExpandKey(g);
                            final morosoRef = adminCheckoutGroupMorosoRef(g);
                            return AdminExpandableOrderCard(
                              request: primary,
                              checkoutGroupLines: g.length > 1 ? g : null,
                              expanded: _expandedRequestId == expandKey,
                              onToggle: () => _toggleExpand(expandKey),
                              statusLabel: adminCheckoutGroupStatusLabel(g),
                              expandedFooter: g.length > 1
                                  ? AdminCheckoutGroupExpandedSection(
                                      lines: g,
                                      onRefresh: _load,
                                      morosidadFooter:
                                          adminCheckoutGroupEsMoroso(g)
                                              ? AdminAliadoMorosidadActions(
                                                  aliadoId: morosoRef.aliadoId,
                                                  aliadoName: morosoRef
                                                          .aliadoBusinessName ??
                                                      'Aliado',
                                                  pedidosSuspendidosMorosidad:
                                                      _morosidadFlags[morosoRef
                                                                  .aliadoId]
                                                              ?.pedidosSuspendidosMorosidad ??
                                                          false,
                                                  onChanged: _load,
                                                )
                                              : null,
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (primary.esPedidoMoroso) ...[
                                          AdminAliadoMorosidadActions(
                                            aliadoId: primary.aliadoId,
                                            aliadoName:
                                                primary.aliadoBusinessName ??
                                                    'Aliado',
                                            pedidosSuspendidosMorosidad:
                                                _morosidadFlags[primary.aliadoId]
                                                        ?.pedidosSuspendidosMorosidad ??
                                                    false,
                                            onChanged: _load,
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        if (primary.hasFacturaAliado)
                                          AdminPagoRevisionSection(
                                            request: primary,
                                            onRefresh: _load,
                                            highlightEntregadoPagado:
                                                primary.status ==
                                                    TransactionRequestStatus
                                                        .entregado &&
                                                primary.pagoEstadoRevisionEfectivo ==
                                                    PagoRevisionEstado.aprobado,
                                          ),
                                        EfectivoRespaldoRegistrar(
                                          request: primary,
                                          onRegistered: _load,
                                        ),
                                        const Divider(height: 20),
                                        OrderMotolinkThreadSection(
                                          key: ValueKey<String>(
                                            'trm-admin-closed-${primary.id}',
                                          ),
                                          transactionRequestId: primary.id,
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
