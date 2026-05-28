import 'package:flutter/material.dart';

import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../utils/importer_order_advance.dart';
import '../theme/app_theme.dart';
import '../utils/aliado_order_grouping.dart';
import '../utils/notification_related_order_match.dart';
import '../utils/transaction_request_filter_utils.dart';
import 'importer_expandable_order_card.dart';
import 'importer_promo_widgets.dart';
import 'importer_cancelar_pedido_dialog.dart';
import 'importer_order_invoice_section.dart';
import 'importer_order_pago_verification_section.dart';
import 'order_rating_sheet.dart';
import 'importer_notificar_ajuste_cantidad_dialog.dart';
import 'main_shell_tab.dart';
import 'order_list_filter_bar.dart';

enum _ImporterQuickFilter {
  nuevos,
  enProceso,
  cerrados,
}

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
  _ImporterQuickFilter _quickFilter = _ImporterQuickFilter.nuevos;
  bool _morosoOnly = false;

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
    if (MainShellTabController.consumeImporterPedidosPreferCerradosFilter()) {
      setState(() {
        _quickFilter = _ImporterQuickFilter.cerrados;
        _morosoOnly = true;
      });
    } else if (MainShellTabController
        .consumeImporterPedidosPreferNuevosFilter()) {
      setState(() => _quickFilter = _ImporterQuickFilter.nuevos);
    }
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    final key = _expandKeyForPendingId(pending);
    if (key != null) {
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _expandedRequestId = key);
    } else if (!_loading) {
      _load();
    }
  }

  void _tryExpandFromPendingNotification() {
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    final key = _expandKeyForPendingId(pending);
    if (key != null) {
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _expandedRequestId = key);
    }
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
      if (!mounted) return;
      setState(() {
        _rows = rows;
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

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _quickFilter = _ImporterQuickFilter.nuevos;
      _morosoOnly = false;
    });
  }

  bool _matchesQuickFilter(TransactionRequestModel r) {
    final s = r.status;
    switch (_quickFilter) {
      case _ImporterQuickFilter.nuevos:
        return s == TransactionRequestStatus.pendiente;
      case _ImporterQuickFilter.enProceso:
        return s == TransactionRequestStatus.enPreparacion ||
            s == TransactionRequestStatus.pedidoListo ||
            s == TransactionRequestStatus.enTransito ||
            s == TransactionRequestStatus.enviado;
      case _ImporterQuickFilter.cerrados:
        return s == TransactionRequestStatus.entregado ||
            s == TransactionRequestStatus.rechazado;
    }
  }

  List<TransactionRequestModel> get _filtered {
    final searched = TransactionRequestFilterUtils.apply(
      _rows,
      searchQuery: _searchCtrl.text,
      statusFilter: null,
      morosoOnly: _morosoOnly,
    );
    return searched.where(_matchesQuickFilter).toList();
  }

  String _rowKey(TransactionRequestModel r) => r.id;

  Widget _quickFilterBar() {
    Widget chip(String label, _ImporterQuickFilter value) {
      final sel = _quickFilter == value;
      return FilterChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _quickFilter = value),
        selectedColor: AppColors.brand.withOpacity(0.18),
        checkmarkColor: AppColors.brand,
        labelStyle: TextStyle(
          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          color: sel ? AppColors.brand : AppColors.textPrimary,
          fontSize: 12.5,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          chip(
            'Pendientes · nuevos',
            _ImporterQuickFilter.nuevos,
          ),
          chip('En proceso', _ImporterQuickFilter.enProceso),
          chip('Despachados · cerrados', _ImporterQuickFilter.cerrados),
          if (_quickFilter == _ImporterQuickFilter.cerrados)
            FilterChip(
              label: const Text('Morosos'),
              selected: _morosoOnly,
              onSelected: (v) => setState(() => _morosoOnly = v),
              selectedColor: Colors.red.shade100,
              checkmarkColor: Colors.red.shade800,
              labelStyle: TextStyle(
                fontWeight: _morosoOnly ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12.5,
                color:
                    _morosoOnly ? Colors.red.shade900 : AppColors.textPrimary,
              ),
              avatar: Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: _morosoOnly ? Colors.red.shade800 : Colors.grey.shade600,
              ),
            ),
        ],
      ),
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
              ? 'Pedido marcado en tránsito con ETA registrado.'
              : 'Estado actualizado.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load(silent: true);
  }

  bool _canCancelGroup(List<TransactionRequestModel> g) {
    return g.every(
      (r) =>
          r.status == TransactionRequestStatus.pendiente ||
          r.status == TransactionRequestStatus.enPreparacion ||
          r.status == TransactionRequestStatus.pedidoListo,
    );
  }

  bool _canNotifyQtyAdjustment(List<TransactionRequestModel> g) {
    if (!g.every((r) => r.status == TransactionRequestStatus.pendiente)) {
      return false;
    }
    if (g.any((r) => r.qtyAdjustmentPendienteAliado)) return false;
    return g.any((r) => r.cantidad > 1);
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
          bundleAliadoId:
              (isBundle && aid.isNotEmpty) ? aid : null,
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
                ? 'Carrito cancelado. Complete la valoración del aliado.'
                : 'Pedido cancelado. Complete la valoración del aliado.',
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
              'Propuesta enviada: el aliado debe aceptar o rechazar antes de avanzar el pedido.',
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
          content: Text('Ajuste notificado al aliado por chat.'),
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
                'Aparecen aquí los pedidos que MotoLink te asigne. En «Nuevos» ves lo último.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.35),
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _filtered;
    final groups = _groupsForDisplay(filtered);
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ImporterActivePromoBanner(),
              OrderListFilterBar(
                searchController: _searchCtrl,
                onSearchChanged: (_) => setState(() {}),
                hintText: 'Buscar por producto, SKU o aliado',
              ),
              _quickFilterBar(),
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
                                  child: const Text(
                                      'Limpiar búsqueda y volver a Nuevos'),
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
                            final isBundle = g.length > 1;
                            final nextBase =
                                TransactionRequestStatus.nextForImporter(
                              primary.status,
                            );
                            final blockQtyAdj = g.any(
                              (r) => r.qtyAdjustmentPendienteAliado,
                            );
                            final next = (nextBase != null && !blockQtyAdj)
                                ? nextBase
                                : null;
                            final headline = TransactionRequestStatus
                                .importerOperationalHeadline(primary.status);
                            final rk = _displayGroupKey(g);
                            final canCancel = _canCancelGroup(g);
                            final canNotifyQty = _canNotifyQtyAdjustment(g);
                            return ImporterExpandableOrderCard(
                              request: primary,
                              checkoutGroupLines: isBundle ? g : null,
                              ratingBar: g.any(
                                (r) =>
                                    r.status ==
                                        TransactionRequestStatus.entregado ||
                                    (r.status ==
                                            TransactionRequestStatus
                                                .rechazado &&
                                        (r.canceladoPorImportador ||
                                            r.canceladoPorAliado)),
                              )
                                  ? ImporterOrderRatingBar(
                                      request: primary,
                                      lines: g,
                                      onSubmitted: _load,
                                      bundleCheckoutGroupId: isBundle
                                          ? primary.checkoutGroupId
                                          : null,
                                      bundleAliadoId: isBundle
                                          ? primary.aliadoId
                                          : null,
                                    )
                                  : null,
                              expanded: _expandedRequestId == rk,
                              onToggle: () => _toggleExpand(rk),
                              statusLabel: TransactionRequestStatus
                                  .importerFilterStatusLabelEs(primary.status),
                              operationalHeadline: headline,
                              nextStatus: next,
                              nextActionLabel: next != null
                                  ? TransactionRequestStatus
                                      .importerAdvanceButtonLabel(
                                      next,
                                      checkoutGroup: isBundle,
                                    )
                                  : null,
                              onAdvance: next != null
                                  ? () => _advanceGroup(context, g, next)
                                  : null,
                              canCancelByImporter: canCancel,
                              cancelBusy: _cancelBusyKey == rk,
                              onCancelByImporter: canCancel
                                  ? () => _cancelarGroupAsImporter(
                                        context,
                                        g,
                                        rk,
                                      )
                                  : null,
                              canNotifyQtyAdjustment: canNotifyQty,
                              onNotifyQtyAdjustment: canNotifyQty
                                  ? () => _notificarAjusteCantidad(context, g)
                                  : null,
                              onThreadChanged: _load,
                              expandedFooter: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (g.length == 1) ...[
                                    ImporterOrderPagoVerificationSection(
                                      request: g.single,
                                      onChanged: _load,
                                    ),
                                    ImporterOrderInvoiceSection(
                                      request: g.single,
                                      onChanged: _load,
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
                                  ],
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
