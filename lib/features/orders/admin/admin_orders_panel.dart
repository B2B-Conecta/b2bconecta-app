import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:motolink_pro_app/features/kyc/admin_aliado_morosidad_flag.dart';
import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/features/orders/shared/admin_order_panel_utils.dart';
import 'package:motolink_pro_app/features/orders/shared/aliado_order_grouping.dart';
import 'package:motolink_pro_app/core/notifications/notification_related_order_match.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_pedidos_filters_draft.dart';
import 'package:motolink_pro_app/features/orders/shared/importer_order_date.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_filter_utils.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_pedidos_filters_sheet.dart';
import 'admin_checkout_group_expanded_section.dart';
import 'admin_expandable_order_card.dart';
import 'admin_motolink_anula_pedido_dialog.dart';
import 'admin_order_pre_transit_section.dart';
import 'package:motolink_pro_app/features/kyc/admin_aliado_morosidad_actions.dart';
import 'package:motolink_pro_app/features/payments/admin_pago_revision_section.dart';
import 'package:motolink_pro_app/features/payments/efectivo_respaldo_registrar.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_launch.dart';
import 'package:motolink_pro_app/features/orders/shared/order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/profile/profile_section_helpers.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_filter_bar.dart';
import 'package:motolink_pro_app/features/orders/shared/pedidos_scope_bar.dart';

/// Bandeja admin unificada: pedidos en curso, cerrados o todos, con filtros por estado.
class AdminOrdersPanel extends StatefulWidget {
  const AdminOrdersPanel({super.key});

  @override
  State<AdminOrdersPanel> createState() => _AdminOrdersPanelState();
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
  PedidosListScope _scope = PedidosListScope.enCurso;
  String? _loadedKind;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  String get _fetchKind => switch (_scope) {
        PedidosListScope.todos => 'todos',
        PedidosListScope.enCurso => 'curso',
        PedidosListScope.entregados || PedidosListScope.cancelados => 'cerrados',
      };

  String get _emptyMessage => switch (_scope) {
        PedidosListScope.enCurso => 'No hay pedidos en curso.',
        PedidosListScope.entregados => 'No hay pedidos entregados.',
        PedidosListScope.cancelados => 'No hay pedidos cancelados.',
        PedidosListScope.todos => 'No hay pedidos.',
      };

  bool get _showMorosoChip =>
      _scope == PedidosListScope.entregados || _scope == PedidosListScope.todos;

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
          AdminPedidosNotificationScope.enCurso => PedidosListScope.enCurso,
          AdminPedidosNotificationScope.cerrados => PedidosListScope.entregados,
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
    final kind = _fetchKind;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<TransactionRequestModel> rows;
      Map<String, AdminAliadoMorosidadFlag> flags = {};

      switch (kind) {
        case 'curso':
          rows = await SupabaseService.fetchActiveTransactionRequestsForAdmin();
          break;
        case 'cerrados':
          rows = await SupabaseService.fetchClosedTransactionRequestsForAdmin();
          flags = await SupabaseService.adminAliadosPedidosMorososFlags();
          break;
        default:
          rows =
              await SupabaseService.fetchUnifiedTransactionRequestsForAdmin();
          flags = await SupabaseService.adminAliadosPedidosMorososFlags();
          break;
      }

      if (!mounted) return;
      final pending = MainShellTabController.peekPendingNotificationRelatedId();
      var scope = _scope;
      if (pending != null && scope == PedidosListScope.entregados) {
        final match = findTransactionForNotificationRelatedId(rows, pending);
        if (match?.status == TransactionRequestStatus.rechazado) {
          scope = PedidosListScope.cancelados;
        }
      }
      final prevExpanded = _expandedRequestId;
      setState(() {
        _rows = rows;
        _morosidadFlags = flags;
        _scope = scope;
        _loadedKind = kind;
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

  void _onScopeChanged(PedidosListScope next) {
    if (next == _scope) return;
    setState(() {
      _scope = next;
      _statusFilter = null;
      if (next != PedidosListScope.entregados &&
          next != PedidosListScope.todos) {
        _morosoOnly = false;
      }
    });
    if (_fetchKind != _loadedKind) _load();
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
    final scoped = switch (_scope) {
      PedidosListScope.entregados => list
          .where((r) => r.status == TransactionRequestStatus.entregado)
          .toList(),
      PedidosListScope.cancelados => list
          .where((r) => r.status == TransactionRequestStatus.rechazado)
          .toList(),
      _ => list,
    };
    scoped.sort(ImporterOrderDate.compareByFechaReciente);
    return scoped;
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
          content: Text('Pedido anulado. Se notificó a la tienda minorista e importador.'),
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
                        : 'Anular pedido (B2B Conecta)',
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
          subtitle: 'Hilo con tienda minorista, importador y supervisión B2B Conecta',
          infoMessage: OrderSectionHelp.chatPedido,
          initiallyExpanded: true,
          child: OrderOpenChatButton(
            relatedOrderIds: [r.id],
            onPressed: () {
              showOrderChatSheet(
                context: context,
                transactionRequestId: r.id,
                allowReplyAsAliado: false,
                allowReplyAsAdmin: true,
                title: 'Chat del pedido',
                onThreadChanged: _load,
              );
            },
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
            aliadoName: primary.aliadoBusinessName ?? 'Tienda minorista',
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
          subtitle: 'Hilo con tienda minorista, importador y supervisión B2B Conecta',
          infoMessage: OrderSectionHelp.chatPedido,
          initiallyExpanded: true,
          child: OrderOpenChatButton(
            relatedOrderIds: [primary.id],
            onPressed: () {
              showOrderChatSheet(
                context: context,
                transactionRequestId: primary.id,
                allowReplyAsAliado: false,
                allowReplyAsAdmin: true,
                title: 'Chat del pedido',
                onThreadChanged: _load,
              );
            },
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
                      'Tienda minorista',
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
            PedidosScopeBar(
              selected: _scope,
              onSelected: _onScopeChanged,
            ),
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
              OrderListFilterBar(
                searchController: _searchCtrl,
                onSearchChanged: (_) => setState(() {}),
                hintText: 'Buscar por producto, SKU o empresa',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PedidosScopeBar(
                  selected: _scope,
                  onSelected: _onScopeChanged,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: Text(_hasDateFilter ? 'Fecha ✓' : 'Fecha'),
                      selected: _hasDateFilter,
                      onSelected: (_) => _openDateFilters(),
                      visualDensity: VisualDensity.compact,
                      selectedColor: AppColors.brandBlue.withOpacity(0.18),
                      checkmarkColor: AppColors.brandBlue,
                      avatar: Icon(
                        Icons.calendar_month_outlined,
                        size: 16,
                        color: _hasDateFilter
                            ? AppColors.brandBlue
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (_showMorosoChip)
                      FilterChip(
                        label: const Text('Pago pendiente'),
                        selected: _morosoOnly,
                        onSelected: (v) => setState(() => _morosoOnly = v),
                        visualDensity: VisualDensity.compact,
                        selectedColor: Colors.red.shade100,
                        checkmarkColor: Colors.red.shade800,
                        avatar: Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: _morosoOnly
                              ? Colors.red.shade800
                              : AppColors.textSecondary,
                        ),
                      ),
                  ],
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
                                    color: AppColors.textSecondary,
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
                    : PagedItems(
                        items: groups,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        onRefresh: _load,
                        itemBuilder: (g) {
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
