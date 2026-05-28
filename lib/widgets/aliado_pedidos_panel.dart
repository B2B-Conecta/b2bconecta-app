import 'package:flutter/material.dart';

import '../models/aliado_pedidos_filters_draft.dart';
import '../models/profile_model.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/aliado_order_grouping.dart';
import '../utils/notification_related_order_match.dart';
import '../utils/motolink_volume_discount.dart';
import 'aliado_importador_factura_section.dart';
import '../utils/transaction_request_filter_utils.dart';
import '../utils/ves_amount_format.dart';
import 'aliado_cancelar_pedido_dialog.dart';
import 'aliado_expandable_order_card.dart';
import 'aliado_confirmar_recepcion_section.dart';
import '../utils/aliado_experience_utils.dart';
import 'aliado_order_pago_section.dart';
import 'order_rating_sheet.dart';
import 'aliado_qty_adjustment_actions.dart';
import '../utils/aliado_multi_importer_payment.dart';
import 'main_shell_tab.dart';
import 'order_motolink_thread_section.dart';
import 'moroso_order_visual.dart';
import 'aliado_pedidos_filters_sheet.dart';
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
  bool _loading = true;
  String? _error;
  String? _expandedRequestId;
  late final TextEditingController _searchCtrl;
  String? _statusFilter;
  bool _morosoOnly = false;
  DateTime? _dateFrom;
  DateTime? _dateTo;
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
    _searchCtrl.addListener(_onSearchTextChanged);
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

  String? _expandKeyForTransactionId(String id) =>
      orderExpandKeyForNotification(_rows, id);

  void _onNotificationPedidosDeepLink() {
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    final key = _expandKeyForTransactionId(pending);
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
    final key = _expandKeyForTransactionId(pending);
    if (key != null) {
      MainShellTabController.consumePendingNotificationRelatedId();
      setState(() => _expandedRequestId = key);
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
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _profile = profile;
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

  void _onSearchTextChanged() {
    if (mounted) setState(() {});
  }

  AliadoPedidosFiltersDraft _currentFiltersDraft() {
    return AliadoPedidosFiltersDraft(
      statusFilter: _statusFilter,
      morosoOnly: _morosoOnly,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
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

  void _applyFiltersDraft(AliadoPedidosFiltersDraft draft) {
    setState(() {
      _statusFilter = draft.statusFilter;
      _morosoOnly = draft.morosoOnly;
      _dateFrom = draft.dateFrom;
      _dateTo = draft.dateTo;
    });
  }

  Future<void> _openPedidosFiltersSheet() async {
    final result = await AliadoPedidosFiltersSheet.show(
      context,
      initial: _currentFiltersDraft(),
      statusOptions: _statusOptions,
    );
    if (result == null || !mounted) return;
    _applyFiltersDraft(result);
  }

  String? _statusFilterLabel() {
    final s = _statusFilter;
    if (s == null || s.isEmpty) return null;
    for (final o in _statusOptions) {
      if (o.status == s) return o.label;
    }
    return TransactionRequestStatus.labelEs(s);
  }

  String _dateFilterChipLabel() {
    final from = _dateFrom;
    final to = _dateTo;
    if (from != null && to != null) {
      return '${formatAliadoPedidosFilterDate(from)} – ${formatAliadoPedidosFilterDate(to)}';
    }
    if (from != null) {
      return 'Desde ${formatAliadoPedidosFilterDate(from)}';
    }
    return 'Hasta ${formatAliadoPedidosFilterDate(to!)}';
  }

  InputDecoration _pedidosSearchDecoration({required int filterBadge}) {
    return InputDecoration(
      hintText: 'Buscar por producto, SKU o importador…',
      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.2),
      ),
      isDense: true,
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_searchCtrl.text.trim().isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              color: AppColors.textSecondary,
              onPressed: () => _searchCtrl.clear(),
            ),
          IconButton(
            tooltip: 'Filtros',
            onPressed: _openPedidosFiltersSheet,
            icon: Badge(
              isLabelVisible: filterBadge > 0,
              label: Text('$filterBadge'),
              backgroundColor: AppColors.brandOrange,
              child: Icon(
                Icons.tune,
                color: filterBadge > 0
                    ? AppColors.brandOrange
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeFilterChip({
    required String label,
    required VoidCallback onDeleted,
    Color? accent,
  }) {
    final color = accent ?? AppColors.brandBlue;
    return InputChip(
      label: Text(label),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onDeleted,
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.35)),
      labelStyle: const TextStyle(
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

    final statusLabel = _statusFilterLabel();
    if (statusLabel != null) {
      chips.add(_activeFilterChip(
        label: statusLabel,
        onDeleted: () => setState(() => _statusFilter = null),
      ));
    }
    if (draft.morosoOnly) {
      chips.add(_activeFilterChip(
        label: 'Morosos',
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

    if (chips.isEmpty) return null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TransactionRequestModel> get _filtered {
    return TransactionRequestFilterUtils.apply(
      _rows,
      searchQuery: _searchCtrl.text,
      statusFilter: _statusFilter,
      morosoOnly: _morosoOnly,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
  }

  void _toggleExpand(String id) {
    setState(() {
      _expandedRequestId = _expandedRequestId == id ? null : id;
    });
  }

  List<TransactionRequestModel>? _grupoPorExpandKey(String expandKey) {
    for (final g in groupAliadoOrdersByCheckout(_rows)) {
      if (checkoutGroupExpandKey(g) == expandKey) return g;
    }
    return null;
  }

  Future<void> _abrirValoracionTrasCancelacionAliado(
    BuildContext context,
    List<TransactionRequestModel> g, {
    required String motivo,
  }) async {
    if (g.isEmpty) return;
    final ref = aliadoLineaReferenciaValoracion(g);
    final cg = (ref.checkoutGroupId ??
            ref.originalCheckoutGroupId ??
            g.first.checkoutGroupId)
        ?.trim();
    final imp = ref.ownerId.trim();
    final label = ref.ownerBusinessName?.trim();

    if (!context.mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showAliadoOrderRatingSheet(
        context,
        request: ref,
        onSubmitted: _load,
        bundleCheckoutGroupId:
            (cg != null && cg.isNotEmpty) ? cg : null,
        bundleImportadorId: imp.isNotEmpty ? imp : null,
        importadorLabel:
            (label != null && label.isNotEmpty) ? label : null,
        cancellationReason: motivo,
      );
    });
  }

  Future<void> _cancelarGrupoPendiente(
    BuildContext context,
    List<TransactionRequestModel> rows,
  ) async {
    if (_cancelarBusyId != null) return;
    final expandKey = checkoutGroupExpandKey(rows);
    final m = await showAliadoCancelarPedidoPendienteDialog(context);
    if (m == null) return;
    if (!context.mounted) return;
    setState(() => _cancelarBusyId = expandKey);
    try {
      for (final r in rows) {
        if (!r.aliadoPuedeCancelarHastaFacturaProveedor) continue;
        await SupabaseService.aliadoCancelaPedidoPendiente(
          transactionRequestId: r.id,
          motivo: m,
        );
      }
      if (!context.mounted) return;
      await _load();
      if (!context.mounted) return;
      final refreshed = _grupoPorExpandKey(expandKey) ?? rows;
      await _abrirValoracionTrasCancelacionAliado(
        context,
        refreshed,
        motivo: m,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pedido cancelado. Complete la valoración del proveedor.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      var msg = e.toString();
      if (msg.contains('emitió su factura')) {
        msg = 'No puede cancelar: el proveedor ya emitió su factura.';
      } else if (msg.contains('propuesta de cantidad')) {
        msg = 'Responda primero a la propuesta de cantidad del proveedor.';
      } else if (msg.contains('ya está cerrado')) {
        msg = 'El pedido ya está cerrado.';
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

  String _entregaBusyKeyForImportadorChunk(
    List<TransactionRequestModel> chunk,
    String? checkoutGroupId,
  ) {
    final imp = chunk.first.ownerId.trim();
    final cg = checkoutGroupId?.trim();
    if (cg != null && cg.isNotEmpty) return '$cg|$imp';
    return chunk.first.id;
  }

  List<TransactionRequestModel> _lineasEnTransitoOCerrables(
    List<TransactionRequestModel> chunk,
  ) {
    return chunk
        .where(
          (r) =>
              r.status == TransactionRequestStatus.enTransito ||
              r.status == TransactionRequestStatus.enviado,
        )
        .toList();
  }

  bool _puedeConfirmarRecepcionImportador(
    List<TransactionRequestModel> chunk,
  ) {
    final pend = _lineasEnTransitoOCerrables(chunk);
    if (pend.isEmpty) return false;
    return pend.every((r) => r.puedeConfirmarRecepcionAliado);
  }

  Future<void> _confirmarEntregaGrupoImportador(
    BuildContext context, {
    required List<TransactionRequestModel> chunk,
    required String? checkoutGroupId,
  }) async {
    final key = _entregaBusyKeyForImportadorChunk(chunk, checkoutGroupId);
    if (_entregaBusyId != null) return;
    setState(() => _entregaBusyId = key);
    try {
      final pagoPendienteAntes =
          chunk.any((r) => r.pagoMotolinkPendienteEnTransito);
      final cg = checkoutGroupId?.trim();
      if (cg != null && cg.isNotEmpty) {
        await SupabaseService.aliadoMarcarPedidosEntregadosImportadorEnGrupo(
          checkoutGroupId: cg,
          importadorId: chunk.first.ownerId,
        );
      } else {
        for (final r in chunk) {
          if (r.status == TransactionRequestStatus.enTransito ||
              r.status == TransactionRequestStatus.enviado) {
            await SupabaseService.aliadoMarcarPedidoEntregado(r.id);
          }
        }
      }
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
      orderListStatusLabel(r, aliadoViewer: true);

  String _labelGrupo(List<TransactionRequestModel> g) {
    if (g.isEmpty) return '';
    final st0 = g.first.status;
    if (g.every((r) => r.status == st0)) return _label(g.first);
    return 'Varios estados';
  }

  bool _grupoPuedeCancelar(List<TransactionRequestModel> g) {
    return g.isNotEmpty &&
        g.every((r) => r.aliadoPuedeCancelarHastaFacturaProveedor);
  }

  Widget _buildRecepcionLeading(
    BuildContext context,
    List<TransactionRequestModel> g,
  ) {
    final cg = g.first.checkoutGroupId?.trim();
    final bloques = aliadoRecepcionBloquesDesdePedido(
      lines: g,
      lineaPuedeConfirmar: (r) => r.puedeConfirmarRecepcionAliado,
      chunkPuedeConfirmar: _puedeConfirmarRecepcionImportador,
      busyKeyForChunk: (chunk) =>
          _entregaBusyKeyForImportadorChunk(chunk, cg),
      entregaBusyId: _entregaBusyId,
      onConfirmarLinea: (r) => _confirmarEntrega(context, r),
      onConfirmarChunk: (chunk) => _confirmarEntregaGrupoImportador(
        context,
        chunk: chunk,
        checkoutGroupId: cg,
      ),
    );
    return AliadoConfirmarRecepcionSection(bloques: bloques);
  }

  Widget _orderCardFooter(
    BuildContext context,
    List<TransactionRequestModel> g,
  ) {
    final isMulti = g.length > 1;

    if (!isMulti) {
      final r = g.single;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.qtyAdjustmentPendienteAliado) ...[
            AliadoQtyAdjustmentActions(request: r, onChanged: _load),
            const SizedBox(height: 12),
          ],
          AliadoImportadorFacturaSection(lines: [r], compact: true),
          const SizedBox(height: 10),
          _PasarelaPagoMotoLinkCard(
            lineCount: 1,
            importerName: r.ownerBusinessName,
            montoRef: r.precioTotal,
            child: AliadoOrderPagoSection(
              request: r,
              profile: _profile,
              onChanged: _load,
              suppressPrimaryTitle: true,
              suppressNegotiationIntro: false,
            ),
          ),
          const SizedBox(height: 14),
          OrderMotolinkThreadSection(
            key: ValueKey<String>('trm-aliado-${r.id}'),
            transactionRequestId: r.id,
            allowReplyAsAliado: _esEnCurso(r.status),
            allowReplyAsAdmin: false,
            onThreadChanged: _load,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _multiImporterPanelContent(
    BuildContext context,
    List<TransactionRequestModel> chunk, {
    required int importerIndex,
    required int importerTotal,
    required String? bundleCheckoutGroupId,
  }) {
    final name = chunk.first.ownerBusinessName ?? 'Importador';
    final subtotal = subtotalBloqueImportador(chunk);
    final disc = computeVolumeDiscountForLines(chunk);
    final cg = chunk.first.checkoutGroupId?.trim() ?? '';
    final usePagoUnificado = chunk.length > 1 &&
        cg.isNotEmpty &&
        chunk.every((TransactionRequestModel r) => r.checkoutGroupId?.trim() == cg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAliadoRatingBar(
          context,
          chunk,
          bundleCheckoutGroupId: bundleCheckoutGroupId,
          importadorId: chunk.first.ownerId,
          importadorLabel: name,
          onExpandCard: null,
        ),
        if (disc != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              disc.resumenEs,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: Colors.green.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        AliadoImportadorFacturaSection(lines: chunk, compact: true),
        const SizedBox(height: 10),
        _PasarelaPagoMotoLinkCard(
          lineCount: chunk.length,
          singleComprobantePorProveedor: usePagoUnificado,
          importerName: name,
          pagoIndex: importerIndex,
          pagoTotal: importerTotal,
          montoRef: subtotal,
          child: usePagoUnificado
              ? _columnPagoUnificadoImportador(chunk)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < chunk.length; i++) ...[
                      if (chunk.length > 1) ...[
                        if (i > 0) ...[
                          const SizedBox(height: 8),
                          Divider(height: 1, color: Colors.grey.shade200),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          chunk[i].etiquetaProductoAliado,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.brandBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      AliadoOrderPagoSection(
                        request: chunk[i],
                        profile: _profile,
                        onChanged: _load,
                        suppressPrimaryTitle: true,
                        suppressNegotiationIntro: i > 0,
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 14),
        if (chunk.any((l) => l.qtyAdjustmentPendienteAliado)) ...[
          for (final line in chunk.where((l) => l.qtyAdjustmentPendienteAliado))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AliadoQtyAdjustmentActions(
                key: ValueKey<String>('qty-adj-${line.id}'),
                request: line,
                onChanged: _load,
              ),
            ),
        ],
        if (chunk.length > 1) ...[
          Text(
            'Mensajes con MotoLink — un hilo por proveedor en este carrito.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
              color: Colors.grey.shade800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          OrderMotolinkThreadSection(
            key: ValueKey<String>(
              'trm-aliado-merge-${chunk.first.ownerId}-${chunk.map((e) => e.id).join("-")}',
            ),
            transactionRequestId: chunk.first.id,
            mergedThreadRequestIds: chunk.map((e) => e.id).toList(),
            allowReplyAsAliado:
                chunk.any((l) => _esEnCurso(l.status)),
            allowReplyAsAdmin: false,
            onThreadChanged: _load,
            suppressBuiltinTitle: true,
          ),
        ] else ...[
          OrderMotolinkThreadSection(
            key: ValueKey<String>('trm-aliado-${chunk.single.id}'),
            transactionRequestId: chunk.single.id,
            allowReplyAsAliado: _esEnCurso(chunk.single.status),
            allowReplyAsAdmin: false,
            onThreadChanged: _load,
          ),
        ],
      ],
    );
  }

  /// Carrito multi-importador expandido: barra por pestaña; colapsado: resumen en ficha.
  bool _aliadoRatingBarVisibleEnFicha(
    List<TransactionRequestModel> lines, {
    required bool expanded,
  }) {
    if (!lineasEntregadasParaValorar(lines).any((_) => true)) return false;
    final variosImportadores = lines.map((r) => r.ownerId).toSet().length > 1;
    if (variosImportadores && expanded) return false;
    return true;
  }

  Widget _buildAliadoRatingBar(
    BuildContext context,
    List<TransactionRequestModel> lines, {
    String? bundleCheckoutGroupId,
    String? importadorId,
    String? importadorLabel,
    VoidCallback? onExpandCard,
  }) {
    if (!lineasEntregadasParaValorar(lines).any((_) => true)) {
      return const SizedBox.shrink();
    }

    final ref = aliadoLineaReferenciaValoracion(
      lines,
      importadorId: importadorId,
    );
    final pending = aliadoGrupoTieneValoracionPendiente(
      lines,
      importadorId: importadorId,
    );
    final pendingImportadores = aliadoLineasPendientesValoracion(lines)
        .map((r) => r.ownerId)
        .toSet()
        .length;

    String pendingLabel = 'Valorar pedido';
    if (importadorLabel != null && importadorLabel.trim().isNotEmpty) {
      pendingLabel = 'Valorar a ${importadorLabel.trim()}';
    } else if (pendingImportadores > 1) {
      pendingLabel =
          'Valorar proveedores ($pendingImportadores pendientes)';
    }

    return OrderRatingPendingBar(
      pending: pending,
      completedSummary: !pending && aliadoTieneValoracionRegistrada(ref)
          ? aliadoValoracionResumenCortoEs(ref)
          : null,
      pendingLabel: pendingLabel,
      onTapPending: () {
        if (importadorId == null &&
            pendingImportadores > 1 &&
            onExpandCard != null) {
          onExpandCard();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Valorá cada proveedor en su pestaña dentro de este pedido.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        showAliadoOrderRatingSheet(
          context,
          request: ref,
          onSubmitted: _load,
          bundleCheckoutGroupId: bundleCheckoutGroupId,
          bundleImportadorId: importadorId,
          importadorLabel: importadorLabel,
        );
      },
      onTapView: !pending
          ? () => showAliadoOrderRatingSheet(
                context,
                request: ref,
                onSubmitted: _load,
                bundleCheckoutGroupId: bundleCheckoutGroupId,
                bundleImportadorId: importadorId,
                importadorLabel: importadorLabel,
                readOnly: true,
              )
          : null,
    );
  }

  /// Una pasarela de pago y un comprobante para todas las líneas de este importador (sin plan de cuotas).
  Widget _columnPagoUnificadoImportador(List<TransactionRequestModel> chunk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AliadoOrderPagoSection(
          request: chunk.first,
          profile: _profile,
          onChanged: _load,
          pagoBundleLines: chunk,
          suppressPrimaryTitle: true,
          suppressNegotiationIntro: false,
        ),
      ],
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    List<TransactionRequestModel> g,
  ) {
    final expandKey = checkoutGroupExpandKey(g);
    final primary = g.first;
    final isMulti = g.length > 1;
    final checkoutGroupId = g.first.checkoutGroupId?.trim();
    final cgForBundle =
        (checkoutGroupId != null && checkoutGroupId.isNotEmpty)
            ? checkoutGroupId
            : null;

    return AliadoExpandableOrderCard(
      request: primary,
      checkoutGroupLines: isMulti ? g : null,
      expanded: _expandedRequestId == expandKey,
      onToggle: () => _toggleExpand(expandKey),
      statusLabel: isMulti ? _labelGrupo(g) : _label(primary),
      ratingBar: _aliadoRatingBarVisibleEnFicha(
            g,
            expanded: _expandedRequestId == expandKey,
          )
          ? _buildAliadoRatingBar(
              context,
              g,
              bundleCheckoutGroupId: cgForBundle,
              onExpandCard: isMulti && cgForBundle != null
                  ? () => _toggleExpand(expandKey)
                  : null,
            )
          : null,
      expandedLeading: _buildRecepcionLeading(context, g),
      onCancelarSolicitudPendiente: _grupoPuedeCancelar(g)
          ? () => _cancelarGrupoPendiente(context, g)
          : null,
      cancelarSolicitudPendienteBusy: _cancelarBusyId == expandKey,
      expandedFooter: isMulti ? null : _orderCardFooter(context, g),
      multiImporterPanelBuilder: isMulti
          ? (ctx, chunk, idx, total) => _multiImporterPanelContent(
                ctx,
                chunk,
                importerIndex: idx,
                importerTotal: total,
                bundleCheckoutGroupId: cgForBundle,
              )
          : null,
    );
  }

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
                'Tras aprobación MotoLink, aquí verás pedidos en curso y cerrados.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _filtered;
    final filterBadge = _currentFiltersDraft().activePanelFilterCount;
    final activeFilterChips = _buildActiveFilterChipsRow();
    final showFilteredCount = filterBadge > 0 ||
        _searchCtrl.text.trim().isNotEmpty;
    final enCursoGroups = groupAliadoOrdersByCheckout(
      filtered.where((r) => _esEnCurso(r.status)).toList(),
    );
    final cerradosGroups = groupAliadoOrdersByCheckout(
      filtered.where((r) => !_esEnCurso(r.status)).toList(),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => setState(() {}),
                  decoration: _pedidosSearchDecoration(filterBadge: filterBadge),
                ),
              ),
              if (activeFilterChips != null) activeFilterChips,
              if (showFilteredCount)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    '${filtered.length} de ${_rows.length} pedidos',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
                            if (enCursoGroups.isNotEmpty) ...[
                              _sectionTitle('En curso'),
                              ...enCursoGroups.map(
                                (g) => _buildOrderCard(context, g),
                              ),
                            ],
                            if (cerradosGroups.isNotEmpty) ...[
                              _sectionTitle('Cerrados'),
                              ...cerradosGroups.map(
                                (g) => _buildOrderCard(context, g),
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

/// Contenedor único de pasarela MotoLink por bloque importador–aliado en el pie del pedido.
class _PasarelaPagoMotoLinkCard extends StatelessWidget {
  const _PasarelaPagoMotoLinkCard({
    required this.lineCount,
    this.singleComprobantePorProveedor = false,
    this.importerName,
    this.pagoIndex,
    this.pagoTotal,
    this.montoRef,
    required this.child,
  });

  final int lineCount;
  /// Varios ítems mismo importador: un archivo para todas las líneas (sin duplicar UI).
  final bool singleComprobantePorProveedor;
  final String? importerName;
  final int? pagoIndex;
  final int? pagoTotal;
  final double? montoRef;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 22,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pagoIndex != null && pagoTotal != null && pagoTotal! > 1
                            ? 'Su pago $pagoIndex de $pagoTotal'
                            : 'Pasarela de pago MotoLink',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (importerName != null &&
                          importerName!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          importerName!.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                      if (montoRef != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Monto de este proveedor: ${formatRefAmount(montoRef!)} REF',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandBlue,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        singleComprobantePorProveedor
                            ? 'Un solo comprobante cubre todas las líneas de este proveedor; '
                                'el importador lo revisa una vez.'
                            : lineCount > 1
                                ? 'Registre el pago de cada línea de este proveedor.'
                                : 'Método y comprobante para este proveedor.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
