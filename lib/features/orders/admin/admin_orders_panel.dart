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
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/orders/shared/admin_order_panel_utils.dart';
import 'package:motolink_pro_app/features/orders/shared/aliado_order_grouping.dart';
import 'package:motolink_pro_app/core/notifications/notification_related_order_match.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_pedidos_filters_draft.dart';
import 'package:motolink_pro_app/features/orders/shared/importer_order_date.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_filter_utils.dart';
import 'package:motolink_pro_app/features/orders/importador/importer_pedidos_filters_sheet.dart'
    show formatImporterPedidosFilterDate;
import 'admin_checkout_group_expanded_section.dart';
import 'admin_delete_pedido_dialog.dart';
import 'admin_expandable_order_card.dart';
import 'admin_motolink_anula_pedido_dialog.dart';
import 'admin_order_pre_transit_section.dart';
import 'admin_orders_filters_dialog.dart';
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
import 'package:motolink_pro_app/features/orders/shared/order_priority_controls.dart';
import 'package:motolink_pro_app/features/orders/shared/order_workspace.dart';
import 'package:motolink_pro_app/core/widgets/admin_list_skeleton.dart';
import 'package:motolink_pro_app/features/orders/shared/pedidos_scope_bar.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/b2b_data_table_shell.dart';
import 'package:motolink_pro_app/features/payments/pago_metodo.dart';

/// Alias de producto del módulo Pedidos (`/admin/orders`).
typedef OrdersModule = AdminOrdersPanel;

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
  bool _pendingOnly = false;
  bool _pendingFirst = true;
  String? _loadedKind;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  /// Multi-select: `aprobado` | `pendiente` | `pago_movil` | `divisas`.
  final Set<String> _paymentFilters = {};

  /// Multi-select: `revision` | `preparacion` | `transito` | `entregado`.
  final Set<String> _fulfillmentFilters = {};

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
      _paymentFilters.clear();
      _fulfillmentFilters.clear();
      _pendingOnly = false;
    });
    if (_fetchKind != _loadedKind) _load();
  }

  void _togglePaymentFilter(String key) {
    setState(() {
      _expandedRequestId = null;
      if (!_paymentFilters.add(key)) _paymentFilters.remove(key);
    });
  }

  void _toggleFulfillmentFilter(String key) {
    setState(() {
      _expandedRequestId = null;
      if (!_fulfillmentFilters.add(key)) _fulfillmentFilters.remove(key);
    });
  }

  bool _groupMatchesPayment(List<TransactionRequestModel> group) {
    if (_paymentFilters.isEmpty) return true;
    return _paymentFilters.any((f) {
      switch (f) {
        case 'aprobado':
          return group.any((r) =>
              r.pagoEstadoRevisionEfectivo == PagoRevisionEstado.aprobado ||
              r.pedidoEntregadoYPagado);
        case 'pendiente':
          return group.any((r) =>
              r.esPedidoMoroso ||
              r.pagoEstadoRevisionEfectivo == PagoRevisionEstado.pendiente ||
              r.pagoEstadoRevisionEfectivo == PagoRevisionEstado.enRevision);
        case 'pago_movil':
          return group.any((r) => r.pagoMetodo?.trim() == PagoMetodo.pagoMovil);
        case 'divisas':
          return group.any(
            (r) => PagoMetodo.qualifiesForUsdDiscount(r.pagoMetodo),
          );
        default:
          return false;
      }
    });
  }

  bool _groupMatchesFulfillment(List<TransactionRequestModel> group) {
    if (_fulfillmentFilters.isEmpty) return true;
    return _fulfillmentFilters.any((f) {
      switch (f) {
        case 'revision':
          return group.any((r) => r.status == TransactionRequestStatus.pendiente);
        case 'preparacion':
          return group.any((r) =>
              r.status == TransactionRequestStatus.enPreparacion ||
              r.status == TransactionRequestStatus.pedidoListo ||
              r.status == TransactionRequestStatus.aprobadoAdmin);
        case 'transito':
          return group.any((r) =>
              r.status == TransactionRequestStatus.enTransito ||
              r.status == TransactionRequestStatus.enviado);
        case 'entregado':
          return group
              .any((r) => r.status == TransactionRequestStatus.entregado);
        default:
          return false;
      }
    });
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
    final narrow =
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
    if (narrow) {
      await _openMobileFiltersSheet();
      return;
    }
    final draft = await AdminOrdersFiltersDialog.show(
      context,
      initial: _currentFiltersDraft(),
    );
    if (draft == null || !mounted) return;
    _applyFiltersDraft(draft);
  }

  /// BottomSheet móvil: estado, pago, encomienda y periodo en un solo panel.
  Future<void> _openMobileFiltersSheet() async {
    final theme = B2BThemeExtension.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.dialogSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            void refreshModal() => setModal(() {});

            Widget section(String title, List<Widget> children) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: theme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: children),
                  ],
                ),
              );
            }

            B2bDataTableFilterPill pill({
              required String label,
              required bool selected,
              required VoidCallback onTap,
            }) {
              return B2bDataTableFilterPill(
                label: label,
                selected: selected,
                onTap: onTap,
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  16 + MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.borderSubtle,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Filtrar pedidos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Estado, pago, encomienda y periodo',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      section('Estado del listado', [
                        pill(
                          label: 'Todos',
                          selected: !_pendingOnly &&
                              _scope == PedidosListScope.todos,
                          onTap: () {
                            setState(() {
                              _expandedRequestId = null;
                              _scope = PedidosListScope.todos;
                              _pendingOnly = false;
                              _statusFilter = null;
                            });
                            refreshModal();
                          },
                        ),
                        pill(
                          label: 'Por confirmar',
                          selected: _pendingOnly,
                          onTap: () {
                            setState(() {
                              _expandedRequestId = null;
                              _scope = PedidosListScope.todos;
                              _statusFilter = null;
                              _pendingOnly = true;
                            });
                            refreshModal();
                          },
                        ),
                        pill(
                          label: 'En curso',
                          selected: !_pendingOnly &&
                              _scope == PedidosListScope.enCurso,
                          onTap: () {
                            _onScopeChanged(PedidosListScope.enCurso);
                            refreshModal();
                          },
                        ),
                        pill(
                          label: 'Entregados',
                          selected: !_pendingOnly &&
                              _scope == PedidosListScope.entregados,
                          onTap: () {
                            _onScopeChanged(PedidosListScope.entregados);
                            refreshModal();
                          },
                        ),
                        pill(
                          label: 'Cancelados',
                          selected: !_pendingOnly &&
                              _scope == PedidosListScope.cancelados,
                          onTap: () {
                            _onScopeChanged(PedidosListScope.cancelados);
                            refreshModal();
                          },
                        ),
                      ]),
                      section('Estado de pago', [
                        for (final e in const [
                          ('aprobado', 'Aprobado'),
                          ('pendiente', 'Pendiente'),
                          ('pago_movil', 'Pago Móvil'),
                          ('divisas', 'Divisas'),
                        ])
                          pill(
                            label: e.$2,
                            selected: _paymentFilters.contains(e.$1),
                            onTap: () {
                              _togglePaymentFilter(e.$1);
                              refreshModal();
                            },
                          ),
                      ]),
                      section('Estado de encomienda', [
                        for (final e in const [
                          ('revision', 'Nuevo en revisión'),
                          ('preparacion', 'En preparación'),
                          ('transito', 'En tránsito'),
                          ('entregado', 'Entregado'),
                        ])
                          pill(
                            label: e.$2,
                            selected: _fulfillmentFilters.contains(e.$1),
                            onTap: () {
                              _toggleFulfillmentFilter(e.$1);
                              refreshModal();
                            },
                          ),
                      ]),
                      FilledButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final draft = await AdminOrdersFiltersDialog.show(
                            context,
                            initial: _currentFiltersDraft(),
                          );
                          if (draft == null || !mounted) return;
                          _applyFiltersDraft(draft);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.brand,
                          foregroundColor: theme.surfaceCard,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('Periodo y más filtros…'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          _clearFilters();
                          Navigator.of(ctx).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.textPrimary,
                          side: BorderSide(color: theme.borderStrong),
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const Text('Limpiar filtros'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          'Listo',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: theme.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
    setState(() {
      _expandedRequestId = null;
      _scope = next;
      _pendingOnly = false;
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
    groups = filterOrderGroupsBySignals(
      groups,
      creditOnly: _creditOnly,
      replacementOnly: _replacementOnly,
    );
    if (_pendingOnly) {
      groups = groups
          .where((g) => OrderListEntry(g).awaitingConfirmation)
          .toList();
    }
    groups = groups
        .where(_groupMatchesPayment)
        .where(_groupMatchesFulfillment)
        .toList();
    if (_pendingFirst) groups = prioritizePendingOrders(groups);
    return groups;
  }

  Future<void> _cancelGroup(
    BuildContext context,
    List<TransactionRequestModel> group,
  ) async {
    TransactionRequestModel? target;
    for (final r in group) {
      if (r.motolinkPuedeAnularComoAdmin) {
        target = r;
        break;
      }
    }
    if (target == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este pedido no se puede cancelar en su estado actual.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _anularPedidoPorMotolink(context, target);
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
    const danger = Color(0xFFDC2626);
    final dangerBg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0x26DC2626)
        : const Color(0xFFFEF2F2);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _deletePedidoBusyId != null
            ? null
            : () => _eliminarPedido(context, r),
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: danger,
                ),
              )
            : const LucideIcon(
                LucideGlyph.trash2,
                size: 15,
                color: danger,
              ),
        label: Text(busy ? 'Eliminando…' : (label ?? 'Eliminar pedido')),
        style: OutlinedButton.styleFrom(
          foregroundColor: danger,
          backgroundColor: dangerBg,
          side: BorderSide(color: danger.withOpacity(0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle:
              const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
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
          initiallyExpanded: false,
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
          initiallyExpanded: false,
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
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
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
              ),
            ),
          );
        },
      );
    }
    // Aunque la consulta del alcance actual venga vacía (p. ej. solo hay
    // entregados y estamos en «En curso»), hay que mostrar la barra de alcance
    // para poder cambiar a Entregados / Cancelados / Todos.
    final groups = _displayGroups;
    final filterBadge = _currentFiltersDraft().activePanelFilterCount;
    final activeFilterChips = _buildActiveFilterChipsRow();
    final pendingBase = filterOrderGroupsBySignals(
      groupAdminOrdersForDisplay(_filteredFlat),
      creditOnly: _creditOnly,
      replacementOnly: _replacementOnly,
    );
    final pendingCount =
        pendingBase.where((g) => OrderListEntry(g).awaitingConfirmation).length;

    return OrderWorkspace(
      viewerRole: AppHomeRole.administrador,
      groups: groups,
      selectedKey: _expandedRequestId,
      onSelect: (key) => setState(() => _expandedRequestId = key),
      onClose: () => setState(() => _expandedRequestId = null),
      onClearFilters: _clearFilters,
      loading: _loading,
      onRefresh: _load,
      emptyMessage: groups.isEmpty
          ? (_pendingOnly
              ? 'No hay pedidos por confirmar.'
              : _emptyMessage)
          : null,
      canCancelGroup: _groupCanAnular,
      onCancelGroup: (g) => _cancelGroup(context, g),
      resetKey: Object.hash(
        _scope,
        _pendingOnly,
        _pendingFirst,
        _statusFilter,
        _morosoOnly,
        _creditOnly,
        _replacementOnly,
        _dateFrom,
        _dateTo,
        _searchCtrl.text,
        Object.hashAll(_paymentFilters),
        Object.hashAll(_fulfillmentFilters),
      ),
      detailBuilder: (group) => _orderDetail(context, group),
      controls: LayoutBuilder(
        builder: (context, constraints) {
          final mobile =
              constraints.maxWidth < AppBreakpoints.mobileMenu;
          final filterCount = filterBadge +
              _paymentFilters.length +
              _fulfillmentFilters.length +
              (_pendingOnly ? 1 : 0) +
              (_scope != PedidosListScope.enCurso && !_pendingOnly ? 1 : 0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrdersListHeading(count: groups.length),
              OrderListFilterBar(
                softStyle: true,
                searchController: _searchCtrl,
                onSearchChanged: (_) => setState(() {
                  _expandedRequestId = null;
                }),
                hintText: 'Buscar taller, RIF o ID de pedido…',
                padding: const EdgeInsets.only(bottom: 8),
                onFilters: _openPedidosFiltersSheet,
                activeFilterCount: filterCount,
                filterButtonLabel: mobile ? 'Filtrar' : 'Filtros',
              ),
              if (!mobile) ...[
                OrderPriorityControls(
                  scope: _scope,
                  onScope: _onScopeChanged,
                  pendingOnly: _pendingOnly,
                  pendingCount: pendingCount,
                  onPending: () => setState(() {
                    _expandedRequestId = null;
                    _scope = PedidosListScope.todos;
                    _statusFilter = null;
                    _pendingOnly = true;
                  }),
                  pendingFirst: _pendingFirst,
                  onSort: (value) => setState(() => _pendingFirst = value),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final e in const [
                        ('aprobado', 'Aprobado'),
                        ('pendiente', 'Pendiente'),
                        ('pago_movil', 'Pago Móvil'),
                        ('divisas', 'Divisas'),
                      ]) ...[
                        B2bDataTableFilterPill(
                          label: e.$2,
                          selected: _paymentFilters.contains(e.$1),
                          onTap: () => _togglePaymentFilter(e.$1),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Builder(
                        builder: (context) {
                          final t = B2BThemeExtension.of(context);
                          return Container(
                            width: 1,
                            height: 22,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            color: t.borderSubtle,
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      for (final e in const [
                        ('revision', 'Nuevo en revisión'),
                        ('preparacion', 'En preparación'),
                        ('transito', 'En tránsito'),
                        ('entregado', 'Entregado'),
                      ]) ...[
                        B2bDataTableFilterPill(
                          label: e.$2,
                          selected: _fulfillmentFilters.contains(e.$1),
                          onTap: () => _toggleFulfillmentFilter(e.$1),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: PopupMenuButton<bool>(
                    tooltip: 'Ordenar pedidos',
                    initialValue: _pendingFirst,
                    onSelected: (v) => setState(() => _pendingFirst = v),
                    itemBuilder: (_) => [
                      CheckedPopupMenuItem(
                        value: true,
                        checked: _pendingFirst,
                        child: const Text('Pendientes primero'),
                      ),
                      CheckedPopupMenuItem(
                        value: false,
                        checked: !_pendingFirst,
                        child: const Text('Orden habitual'),
                      ),
                    ],
                    child: Builder(
                      builder: (context) {
                        final t = B2BThemeExtension.of(context);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_vert,
                                  size: 18, color: t.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                _pendingFirst
                                    ? 'Pendientes primero'
                                    : 'Orden habitual',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: t.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              if (activeFilterChips != null) activeFilterChips,
            ],
          );
        },
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
