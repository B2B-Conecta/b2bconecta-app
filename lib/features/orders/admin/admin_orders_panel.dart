import 'package:motolink_pro_app/features/orders/shared/orders_list_heading.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:motolink_pro_app/features/kyc/admin_aliado_morosidad_flag.dart';
import 'package:motolink_pro_app/features/payments/pago_revision_estado.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/orders/shared/admin_order_panel_utils.dart';
import 'package:motolink_pro_app/features/orders/shared/aliado_order_grouping.dart';
import 'package:motolink_pro_app/core/notifications/notification_related_order_match.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_pedidos_filters_draft.dart';
import 'package:motolink_pro_app/features/orders/shared/importer_order_date.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_filter_utils.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_pedidos_filters_sheet.dart';
import 'admin_checkout_group_expanded_section.dart';
import 'admin_delete_pedido_dialog.dart';
import 'admin_expandable_order_card.dart';
import 'admin_motolink_anula_pedido_dialog.dart';
import 'admin_order_pre_transit_section.dart';
import 'package:motolink_pro_app/features/kyc/admin_aliado_morosidad_actions.dart';
import 'package:motolink_pro_app/features/payments/admin_pago_revision_section.dart';
import 'package:motolink_pro_app/features/payments/efectivo_respaldo_registrar.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_launch.dart';
import 'package:motolink_pro_app/features/orders/shared/order_return_buttons.dart';
import 'package:motolink_pro_app/features/orders/shared/order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/profile/app_home_role.dart';
import 'package:motolink_pro_app/features/profile/profile_section_helpers.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_filter_bar.dart';
import 'package:motolink_pro_app/features/orders/shared/order_signal_filters.dart';
import 'package:motolink_pro_app/features/orders/shared/order_workspace.dart';
import 'package:motolink_pro_app/core/widgets/admin_list_skeleton.dart';
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
  String? _deletePedidoBusyId;
  bool _morosoOnly = false;
  bool _creditOnly = false;
  bool _replacementOnly = false;
  Map<String, AdminAliadoMorosidadFlag> _morosidadFlags = {};
  PedidosListScope _scope = PedidosListScope.enCurso;
  String? _loadedKind;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  String get _fetchKind => switch (_scope) {
        PedidosListScope.todos => 'todos',
        PedidosListScope.enCurso => 'curso',
        PedidosListScope.entregados ||
        PedidosListScope.cancelados =>
          'cerrados',
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

  ImporterPedidosFiltersDraft _currentFiltersDraft() {
    return ImporterPedidosFiltersDraft(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      morosoOnly: _morosoOnly,
      creditOnly: _creditOnly,
      replacementOnly: _replacementOnly,
    );
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _expandedRequestId = null;
      _statusFilter = null;
      _scope = PedidosListScope.todos;
      _morosoOnly = false;
      _creditOnly = false;
      _replacementOnly = false;
      _dateFrom = null;
      _dateTo = null;
    });
    if (_fetchKind != _loadedKind) _load();
  }

  void _applyFiltersDraft(ImporterPedidosFiltersDraft draft) {
    setState(() {
      _expandedRequestId = null;
      if (draft.morosoOnly) {
        _scope = PedidosListScope.todos;
      }
      _dateFrom = draft.dateFrom;
      _dateTo = draft.dateTo;
      _morosoOnly = draft.morosoOnly;
      _creditOnly = draft.creditOnly;
      _replacementOnly = draft.replacementOnly;
    });
    if (_fetchKind != _loadedKind) _load();
  }

  Future<void> _openPedidosFiltersSheet() async {
    final draft = await ImporterPedidosFiltersSheet.show(
      context,
      initial: _currentFiltersDraft(),
      showOnlyNuevos: false,
    );
    if (draft == null || !mounted) return;
    _applyFiltersDraft(draft);
  }

  String _dateFilterChipLabel() {
    final from = _dateFrom;
    final to = _dateTo;
    if (from != null && to != null) {
      return '${formatImporterPedidosFilterDate(from)} – ${formatImporterPedidosFilterDate(to)}';
    }
    if (from != null) {
      return 'Desde ${formatImporterPedidosFilterDate(from)}';
    }
    return 'Hasta ${formatImporterPedidosFilterDate(to!)}';
  }

  Widget _activeFilterChip({
    required String label,
    required VoidCallback onDeleted,
    Color? accent,
  }) {
    final color = accent ?? AppColors.brandAccent;
    return InputChip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDeleted,
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.35)),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget? _buildActiveFilterChipsRow() {
    final draft = _currentFiltersDraft();
    final chips = <Widget>[];
    if (draft.morosoOnly) {
      chips.add(_activeFilterChip(
        label: 'Pago pendiente',
        accent: Colors.red.shade800,
        onDeleted: () => setState(() => _morosoOnly = false),
      ));
    }
    if (draft.hasDateFilter) {
      chips.add(_activeFilterChip(
        label: _dateFilterChipLabel(),
        onDeleted: () => setState(() {
          _dateFrom = null;
          _dateTo = null;
        }),
      ));
    }
    if (draft.creditOnly) {
      chips.add(_activeFilterChip(
        label: 'Saldo aplicado',
        onDeleted: () => setState(() => _creditOnly = false),
      ));
    }
    if (draft.replacementOnly) {
      chips.add(_activeFilterChip(
        label: 'Cambio de producto',
        onDeleted: () => setState(() => _replacementOnly = false),
      ));
    }
    if (chips.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          TextButton(
            onPressed: _clearFilters,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Limpiar',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _onScopeChanged(PedidosListScope next) {
    if (next == _scope) return;
    setState(() {
      _expandedRequestId = null;
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
    return filterOrderGroupsBySignals(
      groups,
      creditOnly: _creditOnly,
      replacementOnly: _replacementOnly,
    );
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
          content: Text(
              'Pedido anulado. Se notificó a la tienda minorista e importador.'),
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

  Future<void> _eliminarPedido(
    BuildContext context,
    TransactionRequestModel r,
  ) async {
    if (_deletePedidoBusyId != null) return;
    List<TransactionRequestModel> lines;
    try {
      lines = await OrdersService.fetchCheckoutGroupLinesForTransactionRequest(
        r.id,
      );
    } catch (_) {
      lines = [r];
    }
    if (!context.mounted) return;
    final siblings = lines.where((line) => line.id != r.id).toList();
    final confirmed = await confirmAdminDeletePedido(context, line: r);
    if (!confirmed || !context.mounted) return;

    var deleteGroup = false;
    final anySiblingDelivered = siblings.any(
      (line) => line.status == TransactionRequestStatus.entregado,
    );
    if (siblings.isNotEmpty) {
      final scope = await confirmAdminDeletePedidoGroup(
        context,
        siblings: siblings,
        includesDelivered: anySiblingDelivered ||
            r.status == TransactionRequestStatus.entregado,
      );
      if (scope == null || !context.mounted) return;
      deleteGroup = scope == AdminDeletePedidoScope.checkoutGroup;
    }

    final touchesDelivered = r.status == TransactionRequestStatus.entregado ||
        (deleteGroup && anySiblingDelivered);
    String? motivo;
    if (touchesDelivered) {
      motivo = await askAdminDeleteEntregadoMotivo(context);
      if (motivo == null || !context.mounted) return;
    }

    setState(() => _deletePedidoBusyId = r.id);
    try {
      final deleted = await SupabaseService.adminDeletePedido(
        transactionRequestId: r.id,
        deleteCheckoutGroup: deleteGroup,
        motivo: motivo,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted > 1
                ? 'Se eliminaron $deleted pedidos del carrito.'
                : 'Pedido eliminado.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    } finally {
      if (mounted) setState(() => _deletePedidoBusyId = null);
    }
  }

  Widget _deletePedidoButton(
    BuildContext context,
    TransactionRequestModel r, {
    String? label,
  }) {
    final busy = _deletePedidoBusyId == r.id;
    return OutlinedButton.icon(
      onPressed: _deletePedidoBusyId != null
          ? null
          : () => _eliminarPedido(context, r),
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.delete_outline, size: 20, color: Colors.red.shade800),
      label: Text(busy ? 'Eliminando…' : (label ?? 'Eliminar pedido')),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade800),
    );
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
        _deletePedidoButton(context, r),
        const SizedBox(height: 12),
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
          subtitle:
              'Hilo con tienda minorista, importador y supervisión B2B Conecta',
          infoMessage: OrderSectionHelp.chatPedido,
          initiallyExpanded: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrderOpenChatButton(
                relatedOrderIds: [r.id],
                onPressed: () {
                  showOrderChatSheet(
                    context: context,
                    transactionRequestId: r.id,
                    orderLines: [r],
                    allowReplyAsAliado: false,
                    allowReplyAsAdmin: true,
                    title: 'Chat del pedido',
                    onThreadChanged: _load,
                  );
                },
              ),
              OrderReturnButtons(
                lines: [r],
                allowReplyAsAliado: false,
                allowReplyAsImportador: false,
              ),
            ],
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
        _deletePedidoButton(context, primary),
        const SizedBox(height: 12),
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
          subtitle:
              'Hilo con tienda minorista, importador y supervisión B2B Conecta',
          infoMessage: OrderSectionHelp.chatPedido,
          initiallyExpanded: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrderOpenChatButton(
                relatedOrderIds: [primary.id],
                onPressed: () {
                  showOrderChatSheet(
                    context: context,
                    transactionRequestId: primary.id,
                    orderLines: [primary],
                    allowReplyAsAliado: false,
                    allowReplyAsAdmin: true,
                    title: 'Chat del pedido',
                    onThreadChanged: _load,
                  );
                },
              ),
              OrderReturnButtons(
                lines: [primary],
                allowReplyAsAliado: false,
                allowReplyAsImportador: false,
              ),
            ],
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
        onEliminarPedido: (r) => _eliminarPedido(context, r),
        deleteBusyId: _deletePedidoBusyId,
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
      return const AdminListSkeleton();
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
    // Aunque la consulta del alcance actual venga vacía (p. ej. solo hay
    // entregados y estamos en «En curso»), hay que mostrar la barra de alcance
    // para poder cambiar a Entregados / Cancelados / Todos.
    final groups = _displayGroups;
    final filterBadge = _currentFiltersDraft().activePanelFilterCount;
    final activeFilterChips = _buildActiveFilterChipsRow();

    return OrderWorkspace(
      viewerRole: AppHomeRole.administrador,
      groups: groups,
      selectedKey: _expandedRequestId,
      onSelect: (key) => setState(() => _expandedRequestId = key),
      onClose: () => setState(() => _expandedRequestId = null),
      onClearFilters: _clearFilters,
      loading: _loading,
      onRefresh: _load,
      emptyMessage: groups.isEmpty ? _emptyMessage : null,
      resetKey: Object.hash(
        _scope,
        _statusFilter,
        _morosoOnly,
        _creditOnly,
        _replacementOnly,
        _dateFrom,
        _dateTo,
        _searchCtrl.text,
      ),
      detailBuilder: (group) => _orderDetail(context, group),
      controls: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrdersListHeading(count: groups.length),
          OrderListFilterBar(
            softStyle: true,
            searchController: _searchCtrl,
            onSearchChanged: (_) => setState(() {
              _expandedRequestId = null;
            }),
            hintText: 'Buscar por producto, SKU o empresa…',
            padding: const EdgeInsets.only(bottom: 8),
            onFilters: _openPedidosFiltersSheet,
            activeFilterCount: filterBadge,
          ),
          PedidosScopeBar(
            selected: _scope,
            onSelected: _onScopeChanged,
            filledStyle: true,
          ),
          if (activeFilterChips != null) activeFilterChips,
        ],
      ),
    );
  }

  Widget _orderDetail(
    BuildContext context,
    List<TransactionRequestModel> group,
  ) {
    final expandKey = checkoutGroupExpandKey(group);
    return AdminExpandableOrderCard(
      key: ValueKey<String>('admin-order-detail-card-$expandKey'),
      workspaceDetail: true,
      request: group.first,
      checkoutGroupLines: group.length > 1 ? group : null,
      expanded: true,
      onToggle: () => setState(() => _expandedRequestId = null),
      statusLabel: adminCheckoutGroupStatusLabel(group),
      expandedFooter: _buildExpandedFooter(context, group),
      onRequestMutated: _load,
    );
  }
}
