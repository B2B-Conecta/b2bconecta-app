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
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
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
import 'package:motolink_pro_app/features/profile/profile_section_helpers.dart';
import 'package:motolink_pro_app/features/orders/shared/order_list_filter_bar.dart';
import 'package:motolink_pro_app/features/orders/shared/order_date_shortcuts.dart';
import 'package:motolink_pro_app/features/orders/shared/order_signal_filters.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'package:motolink_pro_app/core/layout/filter_chip_strip.dart';
import 'package:motolink_pro_app/core/layout/filter_menu_button.dart';
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

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _statusFilter = null;
      _morosoOnly = false;
      _creditOnly = false;
      _replacementOnly = false;
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

  void _setDateShortcut(OrderDateShortcut shortcut, {bool toggle = true}) {
    if (shortcut == OrderDateShortcut.custom) {
      _openDateFilters();
      return;
    }
    final active = OrderDateShortcuts.active(_dateFrom, _dateTo);
    final today = OrderDateShortcuts.day(DateTime.now());
    final next =
        toggle && active == shortcut ? OrderDateShortcut.all : shortcut;
    setState(() {
      switch (next) {
        case OrderDateShortcut.today:
          _dateFrom = today;
          _dateTo = today;
        case OrderDateShortcut.days7:
          _dateFrom = today.subtract(const Duration(days: 6));
          _dateTo = today;
        case OrderDateShortcut.days30:
          _dateFrom = today.subtract(const Duration(days: 29));
          _dateTo = today;
        case OrderDateShortcut.all:
        case OrderDateShortcut.custom:
          _dateFrom = null;
          _dateTo = null;
      }
    });
  }

  String _customDateLabel() {
    String fmt(DateTime? d) => d == null
        ? '…'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return '${fmt(_dateFrom)} – ${fmt(_dateTo)}';
  }

  Widget _desktopFilterToolbar() {
    final date = OrderDateShortcuts.active(_dateFrom, _dateTo);
    final dateLabel = switch (date) {
      OrderDateShortcut.all => 'Fecha',
      OrderDateShortcut.today => 'Fecha · Hoy',
      OrderDateShortcut.days7 => 'Fecha · 7 días',
      OrderDateShortcut.days30 => 'Fecha · 30 días',
      OrderDateShortcut.custom => 'Fecha · ${_customDateLabel()}',
    };
    final signalCount = [
      _creditOnly,
      _replacementOnly,
      _showMorosoChip && _morosoOnly,
    ].where((v) => v).length;
    final anyActive = date != OrderDateShortcut.all || signalCount > 0;

    FilterMenuOption dateOption(String label, OrderDateShortcut s) =>
        FilterMenuOption(
          label: label,
          selected: date == s,
          onPressed: () => _setDateShortcut(s, toggle: false),
        );

    return FilterToolbar(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      children: [
        FilterMenuButton(
          icon: Icons.calendar_today_outlined,
          label: dateLabel,
          active: date != OrderDateShortcut.all,
          menuChildren: [
            dateOption('Todas las fechas', OrderDateShortcut.all),
            dateOption('Hoy', OrderDateShortcut.today),
            dateOption('Últimos 7 días', OrderDateShortcut.days7),
            dateOption('Últimos 30 días', OrderDateShortcut.days30),
            const Divider(height: 8),
            FilterMenuOption(
              label: date == OrderDateShortcut.custom
                  ? 'Personalizado · ${_customDateLabel()}'
                  : 'Personalizado…',
              icon: Icons.date_range_outlined,
              selected: date == OrderDateShortcut.custom,
              onPressed: _openDateFilters,
            ),
          ],
        ),
        FilterMenuButton(
          icon: Icons.filter_list,
          label: signalCount == 0 ? 'Señales' : 'Señales ($signalCount)',
          active: signalCount > 0,
          tone: _showMorosoChip && _morosoOnly ? Colors.red.shade700 : null,
          menuChildren: [
            FilterMenuCheck(
              label: 'Bajo crédito',
              value: _creditOnly,
              onChanged: (v) => setState(() {
                _creditOnly = v;
                if (v) _replacementOnly = false;
              }),
            ),
            FilterMenuCheck(
              label: 'Cambio de producto',
              value: _replacementOnly,
              onChanged: (v) => setState(() {
                _replacementOnly = v;
                if (v) _creditOnly = false;
              }),
            ),
            if (_showMorosoChip)
              FilterMenuCheck(
                label: 'Pago pendiente',
                value: _morosoOnly,
                onChanged: (v) => setState(() => _morosoOnly = v),
              ),
          ],
        ),
        if (anyActive)
          TextButton(
            onPressed: () => setState(() {
              _dateFrom = null;
              _dateTo = null;
              _creditOnly = false;
              _replacementOnly = false;
              _morosoOnly = false;
            }),
            child: const Text('Limpiar'),
          ),
      ],
    );
  }

  List<Widget> _quickFilterChips() {
    final date = OrderDateShortcuts.active(_dateFrom, _dateTo);
    String customLabel() =>
        date == OrderDateShortcut.custom ? _customDateLabel() : 'Fechas…';

    return [
      StripChip(
        label: 'Hoy',
        selected: date == OrderDateShortcut.today,
        onTap: () => _setDateShortcut(OrderDateShortcut.today),
      ),
      StripChip(
        label: '7 días',
        selected: date == OrderDateShortcut.days7,
        onTap: () => _setDateShortcut(OrderDateShortcut.days7),
      ),
      StripChip(
        label: '30 días',
        selected: date == OrderDateShortcut.days30,
        onTap: () => _setDateShortcut(OrderDateShortcut.days30),
      ),
      StripChip(
        label: customLabel(),
        icon: Icons.calendar_today_outlined,
        selected: date == OrderDateShortcut.custom,
        onTap: () => _setDateShortcut(OrderDateShortcut.custom),
      ),
      const StripDivider(),
      StripChip(
        label: 'Bajo crédito',
        selected: _creditOnly,
        onTap: () => setState(() {
          _creditOnly = !_creditOnly;
          if (_creditOnly) _replacementOnly = false;
        }),
      ),
      StripChip(
        label: 'Cambio de producto',
        selected: _replacementOnly,
        onTap: () => setState(() {
          _replacementOnly = !_replacementOnly;
          if (_replacementOnly) _creditOnly = false;
        }),
      ),
      if (_showMorosoChip)
        StripChip(
          label: 'Pago pendiente',
          icon: Icons.warning_amber_rounded,
          tone: Colors.red.shade700,
          selected: _morosoOnly,
          onTap: () => setState(() => _morosoOnly = !_morosoOnly),
        ),
    ];
  }

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
    return filterOrderGroupsBySignals(
      groups,
      creditOnly: _creditOnly,
      replacementOnly: _replacementOnly,
    );
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final masterDetail =
            constraints.maxWidth >= _kOrdersMasterDetailMinWidth;
        final listColumn = _buildListColumn(
          context,
          groups,
          masterDetail: masterDetail,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: masterDetail
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: _kOrdersMasterListWidth,
                          child: listColumn,
                        ),
                        VerticalDivider(width: 1, color: AppColors.divider),
                        Expanded(child: _buildDetailPane(context, groups)),
                      ],
                    )
                  : listColumn,
            ),
            if (_loading)
              const Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDetailPane(
    BuildContext context,
    List<List<TransactionRequestModel>> groups,
  ) {
    final selected = groups
        .where((g) => checkoutGroupExpandKey(g) == _expandedRequestId)
        .firstOrNull;
    if (selected == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              'Seleccione un pedido para ver el detalle.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    final expandKey = checkoutGroupExpandKey(selected);
    return SingleChildScrollView(
      key: PageStorageKey<String>('admin-order-detail-$expandKey'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: AdminExpandableOrderCard(
        key: ValueKey<String>('admin-order-detail-card-$expandKey'),
        request: selected.first,
        checkoutGroupLines: selected.length > 1 ? selected : null,
        expanded: true,
        onToggle: () => _toggleExpand(expandKey),
        statusLabel: adminCheckoutGroupStatusLabel(selected),
        expandedFooter: _buildExpandedFooter(context, selected),
        onRequestMutated: _load,
      ),
    );
  }

  Widget _buildListColumn(
    BuildContext context,
    List<List<TransactionRequestModel>> groups, {
    required bool masterDetail,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OrdersListHeading(count: groups.length)),
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
        if (isAdminDesktopLayout(context))
          _desktopFilterToolbar()
        else
          FilterChipStrip(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            children: _quickFilterChips(),
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
              : PagedItems<List<TransactionRequestModel>>(
                  items: groups,
                  pagerAtBottom: true,
                  itemKey: checkoutGroupExpandKey,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  onRefresh: _load,
                  itemBuilder: (g) {
                    final primary = g.first;
                    final expandKey = checkoutGroupExpandKey(g);
                    final isSelected = _expandedRequestId == expandKey;
                    return AdminExpandableOrderCard(
                      request: primary,
                      checkoutGroupLines: g.length > 1 ? g : null,
                      expanded: !masterDetail && isSelected,
                      highlighted: masterDetail && isSelected,
                      onToggle: () => _toggleExpand(expandKey),
                      statusLabel: adminCheckoutGroupStatusLabel(g),
                      expandedFooter: masterDetail
                          ? null
                          : _buildExpandedFooter(context, g),
                      onRequestMutated: _load,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Ancho del panel para mostrar lista + detalle de pedido lado a lado.
const double _kOrdersMasterDetailMinWidth = 1080;
const double _kOrdersMasterListWidth = 440;
