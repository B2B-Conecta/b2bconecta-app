import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/features/orders/shared/importer_order_advance.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'package:motolink_pro_app/core/layout/filter_menu_button.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/widgets/admin_list_skeleton.dart';
import 'package:motolink_pro_app/features/orders/shared/aliado_order_grouping.dart';
import 'package:motolink_pro_app/core/notifications/notification_related_order_match.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_filter_utils.dart';
import 'importer_expandable_order_card.dart';
import 'package:motolink_pro_app/features/catalog/importer_promo_widgets.dart';
import 'importer_cancelar_pedido_dialog.dart';
import 'importer_order_invoice_section.dart';
import 'package:motolink_pro_app/features/logistics/importer_order_flete_invoice_section.dart';
import 'package:motolink_pro_app/features/logistics/importer_order_flete_comprobante_section.dart';
import 'package:motolink_pro_app/features/logistics/importer_order_carrier_summary_section.dart';
import 'package:motolink_pro_app/features/logistics/importer_confirm_pickup_section.dart';
import 'package:motolink_pro_app/features/payments/importer_order_pago_verification_section.dart';
import 'package:motolink_pro_app/features/reputation/order_rating_sheet.dart';
import 'importer_notificar_ajuste_cantidad_dialog.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'importer_pedidos_filters_draft.dart';
import 'package:motolink_pro_app/features/orders/shared/b2b_orders_panel_layout.dart';
import 'package:motolink_pro_app/features/orders/shared/importer_order_date.dart';
import 'importer_pedidos_filters_sheet.dart';
import 'package:motolink_pro_app/features/orders/shared/order_date_shortcuts.dart';
import 'package:motolink_pro_app/features/orders/shared/order_chat_launch.dart';
import 'package:motolink_pro_app/features/orders/shared/order_signal_filters.dart';
import 'package:motolink_pro_app/features/orders/shared/pedidos_scope_bar.dart';
import 'package:motolink_pro_app/features/orders/shared/orders_service.dart';

/// Pedidos del importador: ingreso directo, filtros rápidos y ciclo completo en una sola vista.
class ImporterActiveOrdersPanel extends StatefulWidget {
  const ImporterActiveOrdersPanel({super.key});

  @override
  State<ImporterActiveOrdersPanel> createState() =>
      _ImporterActiveOrdersPanelState();
}

class _ImporterActiveOrdersPanelState extends State<ImporterActiveOrdersPanel> {
  List<TransactionRequestModel> _rows = [];
  bool _loading = true;
  String? _error;
  String? _expandedRequestId;
  String? _cancelBusyKey;
  late final TextEditingController _searchCtrl;
  PedidosListScope _scope = PedidosListScope.enCurso;
  bool _onlyNuevos = false;
  bool _morosoOnly = false;
  bool _creditOnly = false;
  bool _replacementOnly = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  List<AliadoCreditBalance> _credits = const [];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    MainShellTabController.registerImporterPedidosReload(() => _load());
    MainShellTabController.registerPedidosNotificationDeepLink(
      _onNotificationPedidosDeepLink,
    );
    MainShellTabController.registerImportadorValidadosNotificationDeepLink(
      _onNotificationPedidosDeepLink,
    );
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerImporterPedidosReload(null);
    MainShellTabController.registerPedidosNotificationDeepLink(null);
    MainShellTabController.registerImportadorValidadosNotificationDeepLink(
        null);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onNotificationPedidosDeepLink() {
    _prepareImporterFilterForNotificationDeepLink();
    final expanded = _tryApplyExpandFromPendingNotification();
    if (!expanded && !_loading) {
      _load(silent: true);
    } else if (!_loading) {
      _load(silent: true);
    }
    MainShellTabController.consumePendingNotificationType();
  }

  void _prepareImporterFilterForNotificationDeepLink() {
    final explore =
        MainShellTabController.consumeImporterPedidosExploreFilter();
    if (explore != null) {
      setState(() {
        _scope = switch (explore) {
          'cerrados' => PedidosListScope.entregados,
          _ => PedidosListScope.enCurso,
        };
        _onlyNuevos = explore == 'nuevos';
        _morosoOnly = false;
      });
      return;
    }

    if (MainShellTabController.consumeImporterPedidosPreferCerradosFilter()) {
      setState(() {
        _scope = PedidosListScope.entregados;
        _morosoOnly = true;
      });
      return;
    }

    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending != null) {
      final match = findTransactionForNotificationRelatedId(_rows, pending);
      if (match != null) {
        setState(() {
          _scope = _scopeForOrderStatus(match.status);
          if (_scope != PedidosListScope.entregados &&
              _scope != PedidosListScope.cancelados) {
            _morosoOnly = false;
          }
        });
        return;
      }
    }

    final notifType = MainShellTabController.peekPendingNotificationType();
    if (notifType != null) {
      final hint = importerPedidosQuickFilterForNotificationType(notifType);
      if (hint != null) {
        setState(() {
          _scope = _scopeFromHint(hint);
          _morosoOnly = hint == ImporterPedidosQuickFilterHint.cerrados &&
              notifType == 'morosidad';
        });
        return;
      }
    }

    if (MainShellTabController.consumeImporterPedidosPreferEnProcesoFilter()) {
      setState(() {
        _scope = PedidosListScope.enCurso;
        _morosoOnly = false;
      });
      return;
    }

    if (MainShellTabController.consumeImporterPedidosPreferNuevosFilter()) {
      setState(() {
        _scope = PedidosListScope.enCurso;
        _onlyNuevos = true;
        _morosoOnly = false;
      });
    }
  }

  PedidosListScope _scopeForOrderStatus(String status) {
    if (status == TransactionRequestStatus.entregado) {
      return PedidosListScope.entregados;
    }
    if (status == TransactionRequestStatus.rechazado) {
      return PedidosListScope.cancelados;
    }
    return PedidosListScope.enCurso;
  }

  PedidosListScope _scopeFromHint(ImporterPedidosQuickFilterHint hint) {
    switch (hint) {
      case ImporterPedidosQuickFilterHint.nuevos:
      case ImporterPedidosQuickFilterHint.enProceso:
        return PedidosListScope.enCurso;
      case ImporterPedidosQuickFilterHint.cerrados:
        return PedidosListScope.entregados;
    }
  }

  bool _tryApplyExpandFromPendingNotification() {
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return false;
    final key = _expandKeyForPendingId(pending);
    if (key == null) return false;
    final openChat = MainShellTabController.consumePendingOpenOrderChat();
    MainShellTabController.consumePendingNotificationRelatedId();
    setState(() => _expandedRequestId = key);
    if (openChat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        openOrderChatForNotification(
          context: context,
          rows: _rows,
          relatedId: pending,
          asAliado: false,
          onThreadChanged: () => _load(silent: true),
        );
      });
    }
    return true;
  }

  void _tryExpandFromPendingNotification() {
    if (MainShellTabController.peekPendingNotificationRelatedId() == null) {
      return;
    }
    _prepareImporterFilterForNotificationDeepLink();
    _tryApplyExpandFromPendingNotification();
    MainShellTabController.consumePendingNotificationType();
  }

  String? _expandKeyForPendingId(String id) =>
      orderExpandKeyForNotification(_rows, id);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows =
          await SupabaseService.fetchUnifiedTransactionRequestsForImporter();
      List<AliadoCreditBalance> credits = const [];
      try {
        credits = await OrdersService.fetchAliadoCreditBalancesForImporter();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _credits = credits;
        _loading = false;
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

  double? _creditFor(String aliadoId) {
    for (final credit in _credits) {
      if (credit.aliadoId == aliadoId) return credit.remaining;
    }
    return null;
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _scope = PedidosListScope.enCurso;
      _onlyNuevos = false;
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

  bool _matchesScope(TransactionRequestModel r) {
    switch (_scope) {
      case PedidosListScope.todos:
        return true;
      case PedidosListScope.enCurso:
        return TransactionRequestStatus.aliadoPedidosEnCurso.contains(r.status);
      case PedidosListScope.entregados:
        return r.status == TransactionRequestStatus.entregado;
      case PedidosListScope.cancelados:
        return r.status == TransactionRequestStatus.rechazado;
    }
  }

  List<TransactionRequestModel> get _filtered {
    final searched = TransactionRequestFilterUtils.apply(
      _rows,
      searchQuery: _searchCtrl.text,
      statusFilter: null,
      morosoOnly: _morosoOnly,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      useOrderPanelDate: true,
    );
    final list = searched.where(_matchesScope).where((r) {
      if (!_onlyNuevos) return true;
      return r.status == TransactionRequestStatus.pendiente;
    }).toList()
      ..sort(ImporterOrderDate.compareByFechaReciente);
    return list;
  }

  String _rowKey(TransactionRequestModel r) => r.id;

  String get _fechaFilterId =>
      OrderDateShortcuts.active(_dateFrom, _dateTo).name;

  String get _senalFilterId {
    if (_creditOnly) return 'credito';
    if (_replacementOnly) return 'cambio';
    return 'todos';
  }

  void _onScopeChanged(PedidosListScope next) {
    setState(() {
      if (next != _scope) _onlyNuevos = false;
      _scope = next;
      if (next != PedidosListScope.entregados &&
          next != PedidosListScope.todos) {
        _morosoOnly = false;
      }
    });
  }

  void _selectFecha(String id) {
    final today = OrderDateShortcuts.day(DateTime.now());
    switch (id) {
      case 'today':
        setState(() {
          _dateFrom = today;
          _dateTo = today;
        });
      case 'days7':
        setState(() {
          _dateFrom = today.subtract(const Duration(days: 6));
          _dateTo = today;
        });
      case 'days30':
        setState(() {
          _dateFrom = today.subtract(const Duration(days: 29));
          _dateTo = today;
        });
      case 'custom':
        _openDateFilters();
      default:
        setState(() {
          _dateFrom = null;
          _dateTo = null;
        });
    }
  }

  void _selectSenal(String id) {
    setState(() {
      _creditOnly = id == 'credito';
      _replacementOnly = id == 'cambio';
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
    final showPago = _scope == PedidosListScope.entregados ||
        _scope == PedidosListScope.todos;
    final signalCount = [
      _creditOnly,
      _replacementOnly,
      _onlyNuevos,
      showPago && _morosoOnly,
    ].where((v) => v).length;
    final anyActive = date != OrderDateShortcut.all || signalCount > 0;

    FilterMenuOption dateOption(String label, String id) => FilterMenuOption(
          label: label,
          selected: _fechaFilterId == id,
          onPressed: () => _selectFecha(id),
        );

    return FilterToolbar(
      padding: const EdgeInsets.only(top: 2),
      children: [
        FilterMenuButton(
          icon: Icons.calendar_today_outlined,
          label: dateLabel,
          active: date != OrderDateShortcut.all,
          menuChildren: [
            dateOption('Todas las fechas', 'all'),
            dateOption('Hoy', 'today'),
            dateOption('Últimos 7 días', 'days7'),
            dateOption('Últimos 30 días', 'days30'),
            FilterMenuOption(
              label: date == OrderDateShortcut.custom
                  ? 'Personalizado · ${_customDateLabel()}'
                  : 'Personalizado…',
              icon: Icons.date_range_outlined,
              selected: date == OrderDateShortcut.custom,
              onPressed: () => _selectFecha('custom'),
            ),
          ],
        ),
        FilterMenuButton(
          icon: Icons.filter_list,
          label: signalCount == 0 ? 'Señales' : 'Señales ($signalCount)',
          active: signalCount > 0,
          tone: showPago && _morosoOnly ? Colors.red.shade700 : null,
          menuChildren: [
            FilterMenuCheck(
              label: 'Pedido nuevo',
              value: _onlyNuevos,
              onChanged: (v) => setState(() {
                _onlyNuevos = v;
                if (v) {
                  _scope = PedidosListScope.enCurso;
                  _morosoOnly = false;
                }
              }),
            ),
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
            if (showPago)
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
              _onlyNuevos = false;
              _morosoOnly = false;
              _creditOnly = false;
              _replacementOnly = false;
              _dateFrom = null;
              _dateTo = null;
            }),
            child: const Text('Limpiar'),
          ),
      ],
    );
  }

  Widget _quickFilterBar({required double pad}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 10, pad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PedidosScopeBar(
            selected: _scope,
            onSelected: _onScopeChanged,
          ),
          if (isAdminDesktopLayout(context))
            _desktopFilterToolbar()
          else
            _mobileFilterDisclosure(),
        ],
      ),
    );
  }

  Widget _mobileFilterDisclosure() {
    final showPago = _scope == PedidosListScope.entregados ||
        _scope == PedidosListScope.todos;
    const fechaOptions = [
      (id: 'all', label: 'Todas'),
      (id: 'today', label: 'Hoy'),
      (id: 'days7', label: '7 días'),
      (id: 'days30', label: '30 días'),
      (id: 'custom', label: 'Fechas'),
    ];
    const senalOptions = [
      (id: 'todos', label: 'Todos'),
      (id: 'credito', label: 'Bajo crédito'),
      (id: 'cambio', label: 'Cambio de producto'),
    ];
    const pagoOptions = [
      (id: 'todos', label: 'Todos'),
      (id: 'pendiente', label: 'Pago pendiente'),
    ];
    String labelOf(List<({String id, String label})> options, String id) {
      for (final option in options) {
        if (option.id == id) return option.label;
      }
      return options.first.label;
    }

    final summary = [
      labelOf(fechaOptions, _fechaFilterId),
      labelOf(senalOptions, _senalFilterId),
      if (_onlyNuevos) 'Pedido nuevo',
      if (showPago) labelOf(pagoOptions, _morosoOnly ? 'pendiente' : 'todos'),
    ].join(' · ');
    final menus = <Widget>[
      _OrdersFilterMenu(
        label: 'Fecha',
        value: _fechaFilterId,
        options: fechaOptions,
        onSelected: _selectFecha,
      ),
      _OrdersFilterMenu(
        label: 'Señales',
        value: _senalFilterId,
        options: senalOptions,
        onSelected: _selectSenal,
      ),
      if (showPago)
        _OrdersFilterMenu(
          label: 'Pago',
          value: _morosoOnly ? 'pendiente' : 'todos',
          options: pagoOptions,
          onSelected: (id) => setState(() => _morosoOnly = id == 'pendiente'),
        ),
    ];
    return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return _OrdersFiltersDisclosure(
              summary: summary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < menus.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    menus[i],
                  ],
                ],
              ),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < menus.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: menus[i]),
              ],
            ],
          );
        },
      );
  }

  /// Agrupa por `checkout_group_id`; si un grupo tiene estados distintos, muestra tarjetas sueltas.
  List<List<TransactionRequestModel>> _groupsForDisplay(
    List<TransactionRequestModel> filtered,
  ) {
    final buckets = groupAliadoOrdersByCheckout(filtered);
    final out = <List<TransactionRequestModel>>[];
    for (final g in buckets) {
      if (g.length <= 1) {
        out.add(g);
        continue;
      }
      final statuses = g.map((x) => x.status).toSet();
      if (statuses.length == 1) {
        out.add(g);
      } else {
        for (final r in g) {
          out.add(<TransactionRequestModel>[r]);
        }
      }
    }
    return out;
  }

  String _displayGroupKey(List<TransactionRequestModel> g) {
    if (g.length == 1) return _rowKey(g.single);
    return checkoutGroupExpandKey(g);
  }

  void _toggleExpand(String key) {
    setState(() {
      _expandedRequestId = _expandedRequestId == key ? null : key;
    });
  }

  Future<void> _advanceGroup(
    BuildContext context,
    List<TransactionRequestModel> g,
    String next,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await advanceImporterOrderGroup(
      context,
      lines: g,
      nextStatus: next,
    );
    if (!mounted) return;
    if (!ok) return;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          next == TransactionRequestStatus.enTransito
              ? 'Pedido marcado en tránsito. La tienda ya ve el tiempo de llegada.'
              : 'Estado actualizado.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load(silent: true);
    if (!mounted) return;
  }

  bool _canCancelGroup(List<TransactionRequestModel> g) {
    return g.every(
      (r) =>
          r.status == TransactionRequestStatus.pendiente ||
          r.status == TransactionRequestStatus.enPreparacion ||
          r.status == TransactionRequestStatus.pedidoListo,
    );
  }

  bool _showQtyAdjustmentSection(List<TransactionRequestModel> g) {
    if (!g.every((r) => r.status == TransactionRequestStatus.pendiente)) {
      return false;
    }
    return !g.any((r) => r.qtyAdjustmentPendienteAliado);
  }

  bool _canNotifyQtyAdjustment(List<TransactionRequestModel> g) {
    if (!_showQtyAdjustmentSection(g)) return false;
    return g.any((r) => r.cantidad > 1);
  }

  String? _qtyAdjustmentDisabledHint(List<TransactionRequestModel> g) {
    if (!_showQtyAdjustmentSection(g) || _canNotifyQtyAdjustment(g)) {
      return null;
    }
    if (g.length > 1) {
      return 'En carritos multi-partida use el chat para acordar unidades; '
          'la propuesta formal aplica cuando alguna partida tiene más de 1 unidad.';
    }
    return 'Solo aplica si la tienda minorista pidió más de 1 unidad.';
  }

  int _requestedQtyForGroup(List<TransactionRequestModel> g) =>
      g.fold<int>(0, (a, r) => a + r.cantidad);

  Future<void> _cancelarGroupAsImporter(
    BuildContext context,
    List<TransactionRequestModel> g,
    String key,
  ) async {
    if (_cancelBusyKey != null) return;
    final draft = await showImporterCancelarPedidoDialog(
      context,
      productName:
          g.length == 1 ? (g.first.productName ?? 'Pedido') : 'carrito',
    );
    if (draft == null) return;
    if (!context.mounted) return;
    setState(() => _cancelBusyKey = key);
    try {
      for (final r in g) {
        await SupabaseService.importerCancelaPedidoEnGestion(
          transactionRequestId: r.id,
          motivo: draft,
        );
      }
      if (!context.mounted) return;
      await _load(silent: true);
      if (!context.mounted) return;
      final refreshed = _rows.where((r) => g.any((x) => x.id == r.id)).toList();
      final primary = refreshed.isNotEmpty ? refreshed.first : g.first;
      final cg = (primary.checkoutGroupId ??
              primary.originalCheckoutGroupId ??
              g.first.checkoutGroupId)
          ?.trim();
      final isBundle = refreshed.length > 1;
      final aid = primary.aliadoId.trim();
      void openRatingSheet() {
        showImporterOrderRatingSheet(
          context,
          request: primary,
          onSubmitted: () => _load(silent: true),
          bundleCheckoutGroupId:
              (isBundle && cg != null && cg.isNotEmpty) ? cg : null,
          bundleAliadoId: (isBundle && aid.isNotEmpty) ? aid : null,
          cancellationReason: draft,
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        openRatingSheet();
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            g.length > 1
                ? 'Carrito cancelado. Complete la valoración de la tienda minorista.'
                : 'Pedido cancelado. Complete la valoración de la tienda minorista.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cancelar: $e')),
      );
    } finally {
      if (mounted) setState(() => _cancelBusyKey = null);
    }
  }

  Future<void> _notificarAjusteCantidad(
    BuildContext context,
    List<TransactionRequestModel> g,
  ) async {
    final requested = _requestedQtyForGroup(g);
    final draft = await showImporterNotificarAjusteCantidadDialog(
      context,
      requestedQty: requested,
    );
    if (draft == null) return;
    if (!context.mounted) return;

    if (g.length == 1) {
      try {
        await SupabaseService.importerProponeAjusteCantidad(
          transactionRequestId: g.single.id,
          offeredQty: draft.availableQty,
          note: draft.note,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Propuesta enviada: la tienda minorista debe aceptar o rechazar antes de avanzar el pedido.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _load(silent: true);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar la propuesta: $e')),
        );
      }
      return;
    }

    final msg = StringBuffer()
      ..write(
        'Ajuste de disponibilidad (varias partidas): solicitaste $requested uds y '
        'podemos ofrecer ${draft.availableQty} uds en total.',
      );
    if (draft.note.isNotEmpty) {
      msg.write('\nDetalle del proveedor: ${draft.note}');
    }
    msg.write(
      '\nConfirma por este chat cómo repartimos las unidades entre las partidas.',
    );

    try {
      for (final r in g) {
        await SupabaseService.insertTransactionRequestMessageAsImportador(
          transactionRequestId: r.id,
          body: msg.toString(),
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajuste notificado a la tienda minorista por chat.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load(silent: true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el aviso: $e')),
      );
    }
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
          children: [
            const SizedBox(height: 100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Sin pedidos asignados',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.35),
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _filtered;
    final groups = filterOrderGroupsBySignals(
      _groupsForDisplay(filtered),
      creditOnly: _creditOnly,
      replacementOnly: _replacementOnly,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final masterDetail =
            constraints.maxWidth >= _kImporterOrdersMasterDetailMinWidth;
        final screenWidth = masterDetail
            ? _kImporterOrdersMasterListWidth
            : MediaQuery.sizeOf(context).width;
        final listPad = masterDetail
            ? 12.0
            : B2bOrdersPanelLayout.listHorizontalPadding(
                MediaQuery.sizeOf(context).width,
              );
        final listColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(listPad, 12, listPad, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                style: TextStyle(color: AppColors.textPrimary),
                cursorColor: AppColors.brand,
                decoration: InputDecoration(
                  hintText: 'Buscar por producto, SKU o tienda minorista',
                  hintStyle: AppColors.hintStyle,
                  prefixIcon:
                      Icon(Icons.search, color: AppColors.textSecondary),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          color: AppColors.textSecondary,
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.fieldFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.brand,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            _quickFilterBar(pad: listPad),
            ImporterThirdPartyAdsCarousel(
              padding: EdgeInsets.fromLTRB(listPad, 12, listPad, 0),
            ),
            ImporterActivePromoBanner(
              padding: EdgeInsets.fromLTRB(listPad, 8, listPad, 0),
            ),
            Expanded(
              child: filtered.isEmpty || groups.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(listPad, 12, listPad, 24),
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Ningún pedido coincide con los filtros.',
                                style:
                                    TextStyle(color: AppColors.textSecondary),
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
                      resetKey: Object.hash(
                        _scope,
                        _onlyNuevos,
                        _morosoOnly,
                        _creditOnly,
                        _replacementOnly,
                        _dateFrom,
                        _dateTo,
                        _searchCtrl.text,
                      ),
                      padding: EdgeInsets.fromLTRB(
                        listPad,
                        12,
                        listPad,
                        B2bOrdersPanelLayout.listBottomPadding(screenWidth),
                      ),
                      onRefresh: _load,
                      itemKey: _displayGroupKey,
                      itemBuilder: (g) => _orderCard(
                        context,
                        g,
                        masterDetail: masterDetail,
                      ),
                    ),
            ),
          ],
        );
        return Stack(
          children: [
            Positioned.fill(
              child: masterDetail
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: _kImporterOrdersMasterListWidth,
                          child: listColumn,
                        ),
                        VerticalDivider(width: 1, color: AppColors.divider),
                        Expanded(child: _buildDetailPane(context, groups)),
                      ],
                    )
                  : listColumn,
            ),
            if (_loading)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: IgnorePointer(
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.brand,
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
        .where((g) => _displayGroupKey(g) == _expandedRequestId)
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
    final key = _displayGroupKey(selected);
    return SingleChildScrollView(
      key: PageStorageKey<String>('importer-order-detail-$key'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: _orderCard(context, selected,
          masterDetail: false, forceExpanded: true),
    );
  }

  Widget _orderCard(
    BuildContext context,
    List<TransactionRequestModel> g, {
    required bool masterDetail,
    bool forceExpanded = false,
  }) {
    final primary = g.first;
    final isBundle = g.length > 1;
    final nextBase = TransactionRequestStatus.nextForImporter(primary.status);
    final blockQtyAdj = g.any((r) => r.qtyAdjustmentPendienteAliado);
    final next = (nextBase != null && !blockQtyAdj) ? nextBase : null;
    final headline =
        TransactionRequestStatus.importerOperationalHeadline(primary.status);
    final rk = _displayGroupKey(g);
    final isSelected = _expandedRequestId == rk;
    final canCancel = _canCancelGroup(g);
    final showQtyAdj = _showQtyAdjustmentSection(g);
    final canNotifyQty = _canNotifyQtyAdjustment(g);
    final qtyAdjHint = _qtyAdjustmentDisabledHint(g);
    return ImporterExpandableOrderCard(
      request: primary,
      checkoutGroupLines: isBundle ? g : null,
      ratingBar: g.any(
        (r) =>
            r.status == TransactionRequestStatus.entregado ||
            (r.status == TransactionRequestStatus.rechazado &&
                (r.canceladoPorImportador || r.canceladoPorAliado)),
      )
          ? ImporterOrderRatingBar(
              request: primary,
              lines: g,
              onSubmitted: _load,
              bundleCheckoutGroupId: isBundle ? primary.checkoutGroupId : null,
              bundleAliadoId: isBundle ? primary.aliadoId : null,
            )
          : null,
      expanded: forceExpanded || (!masterDetail && isSelected),
      highlighted: masterDetail && !forceExpanded && isSelected,
      onToggle: () => _toggleExpand(rk),
      statusLabel:
          TransactionRequestStatus.importerFilterStatusLabelEs(primary.status),
      operationalHeadline: headline,
      nextStatus: next,
      nextActionLabel: next != null
          ? TransactionRequestStatus.importerAdvanceButtonLabel(
              next,
              checkoutGroup: isBundle,
            )
          : null,
      onAdvance: next != null ? () => _advanceGroup(context, g, next) : null,
      canCancelByImporter: canCancel,
      cancelBusy: _cancelBusyKey == rk,
      onCancelByImporter: canCancel
          ? () => _cancelarGroupAsImporter(
                context,
                g,
                rk,
              )
          : null,
      canNotifyQtyAdjustment: showQtyAdj,
      onNotifyQtyAdjustment:
          canNotifyQty ? () => _notificarAjusteCantidad(context, g) : null,
      qtyAdjustmentDisabledHint: qtyAdjHint,
      onThreadChanged: _load,
      aliadoCreditRemaining: _creditFor(primary.aliadoId),
      expandedFooter: masterDetail && !forceExpanded
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (g.any((r) =>
                    r.status == TransactionRequestStatus.pedidoListo)) ...[
                  ImporterOrderCarrierSummarySection(
                    lines: g,
                  ),
                  if (g.first.importadorMuestraSeccionRecoleccion) ...[
                    const SizedBox(height: 12),
                    ImporterConfirmPickupSection(
                      lines: g,
                      onChanged: _load,
                    ),
                  ],
                ],
                if (g.length == 1) ...[
                  ImporterOrderPagoVerificationSection(
                    request: g.single,
                    onChanged: _load,
                  ),
                  ImporterOrderInvoiceSection(
                    request: g.single,
                    onChanged: _load,
                  ),
                  const SizedBox(height: 12),
                  ImporterOrderFleteInvoiceSection(
                    request: g.single,
                    onChanged: () => _load(silent: true),
                  ),
                  ImporterOrderFleteComprobanteSection(
                    request: g.single,
                    onChanged: () => _load(silent: true),
                  ),
                ] else ...[
                  ImporterOrderPagoVerificationSection(
                    request: g.first,
                    bundleLines: g,
                    onChanged: _load,
                  ),
                  const SizedBox(height: 12),
                  ImporterOrderInvoiceSection(
                    request: g.first,
                    invoiceBundleLines: g,
                    onChanged: _load,
                  ),
                  const SizedBox(height: 12),
                  ImporterOrderFleteInvoiceSection(
                    request: g.first,
                    onChanged: () => _load(silent: true),
                  ),
                  ImporterOrderFleteComprobanteSection(
                    request: g.first,
                    onChanged: () => _load(silent: true),
                  ),
                ],
              ],
            ),
    );
  }
}

const double _kImporterOrdersMasterDetailMinWidth = 1080;
const double _kImporterOrdersMasterListWidth = 440;

class _OrdersFiltersDisclosure extends StatefulWidget {
  const _OrdersFiltersDisclosure({
    required this.summary,
    required this.child,
  });

  final String summary;
  final Widget child;

  @override
  State<_OrdersFiltersDisclosure> createState() =>
      _OrdersFiltersDisclosureState();
}

class _OrdersFiltersDisclosureState extends State<_OrdersFiltersDisclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _open ? AppColors.brand : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 18, color: AppColors.brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filtros',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

class _OrdersFilterMenu extends StatelessWidget {
  const _OrdersFilterMenu({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String value;
  final List<({String id, String label})> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final current = options.firstWhere(
      (option) => option.id == value,
      orElse: () => options.first,
    );
    return SizedBox(
      width: double.infinity,
      child: PopupMenuButton<String>(
        onSelected: onSelected,
        tooltip: label,
        offset: const Offset(0, 46),
        itemBuilder: (context) => [
          for (final option in options)
            PopupMenuItem<String>(
              value: option.id,
              child: Text(
                option.label,
                style: TextStyle(
                  fontWeight:
                      option.id == value ? FontWeight.w800 : FontWeight.w500,
                  color: option.id == value
                      ? AppColors.brand
                      : AppColors.textPrimary,
                ),
              ),
            ),
        ],
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: AppColors.fieldFill,
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
            suffixIcon: Icon(
              Icons.expand_more,
              size: 20,
              color: AppColors.textSecondary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderSubtle),
            ),
          ),
          child: Text(
            current.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
