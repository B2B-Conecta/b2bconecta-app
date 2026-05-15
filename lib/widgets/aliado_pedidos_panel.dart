import 'package:flutter/material.dart';

import '../models/profile_model.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/aliado_order_grouping.dart';
import '../utils/motolink_volume_discount.dart';
import '../utils/transaction_request_filter_utils.dart';
import '../utils/ves_amount_format.dart';
import 'aliado_cancelar_pedido_dialog.dart';
import 'aliado_expandable_order_card.dart';
import 'aliado_order_experience_section.dart';
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

  String? _expandKeyForTransactionId(String id) {
    for (final g in groupAliadoOrdersByCheckout(_rows)) {
      if (g.any((r) => r.id == id)) return checkoutGroupExpandKey(g);
    }
    return null;
  }

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
        await SupabaseService.aliadoCancelaPedidoPendiente(
          transactionRequestId: r.id,
          motivo: m,
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            rows.length > 1
                ? 'Se cancelaron ${rows.length} solicitudes. MotoLink ha sido notificada.'
                : 'Solicitud cancelada. MotoLink ha sido notificada.',
          ),
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
    return pend.every((r) => r.transportistaCompletoRecogidaAlmacen);
  }

  bool _algunaLineaEsperaRecogidaImportador(
    List<TransactionRequestModel> chunk,
  ) {
    final pend = _lineasEnTransitoOCerrables(chunk);
    return pend.isNotEmpty &&
        pend.any((r) => !r.transportistaCompletoRecogidaAlmacen);
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
      r.statusLabelEs(aliadoViewer: true);

  String _labelGrupo(List<TransactionRequestModel> g) {
    if (g.isEmpty) return '';
    final st0 = g.first.status;
    if (g.every((r) => r.status == st0)) return _label(g.first);
    return 'Varios estados';
  }

  bool _grupoPuedeCancelar(List<TransactionRequestModel> g) {
    return g.isNotEmpty &&
        g.every(
          (r) =>
              r.aliadoPuedeCancelarAntesDeGestionImportadores &&
              r.status == TransactionRequestStatus.pendiente,
        );
  }

  Widget _orderCardFooter(
    BuildContext context,
    List<TransactionRequestModel> g,
  ) {
    final isMulti = g.length > 1;
    final checkoutGroupId = g.first.checkoutGroupId?.trim();

    if (!isMulti) {
      final r = g.single;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PasarelaPagoMotoLinkCard(
            lineCount: 1,
            child: AliadoOrderPagoSection(
              request: r,
              profile: _profile,
              openCreditExposureSum: _openCreditExposureSum,
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
            orderPrecioTotalUsd: r.precioTotal,
          ),
        ],
      );
    }

    final porImportador = groupCheckoutLinesByImportador(g);
    final cgForBundle =
        (checkoutGroupId != null && checkoutGroupId.isNotEmpty)
            ? checkoutGroupId
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Pago y recepción por importador. Mensajes con MotoLink: un hilo por proveedor en este carrito.',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade800,
              height: 1.35,
            ),
          ),
        ),
        for (var bi = 0; bi < porImportador.length; bi++) ...[
          _bloqueFooterImportador(
            context,
            porImportador[bi],
            bundleCheckoutGroupId: cgForBundle,
          ),
          if (bi < porImportador.length - 1)
            Divider(height: 32, thickness: 1, color: Colors.grey.shade300),
        ],
      ],
    );
  }

  /// Una pasarela de pago y un comprobante para todas las líneas de este importador (sin plan de cuotas).
  Widget _columnPagoUnificadoImportador(
    List<TransactionRequestModel> chunk, {
    required bool suppressExperienceParent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AliadoOrderPagoSection(
          request: chunk.first,
          profile: _profile,
          openCreditExposureSum: _openCreditExposureSum,
          onChanged: _load,
          pagoBundleLines: chunk,
          suppressExperience: suppressExperienceParent,
          suppressPrimaryTitle: true,
          suppressNegotiationIntro: false,
        ),
      ],
    );
  }

  Widget _bloqueFooterImportador(
    BuildContext context,
    List<TransactionRequestModel> chunk, {
    required String? bundleCheckoutGroupId,
  }) {
    final name = chunk.first.ownerBusinessName ?? 'Importador';
    final subtotal =
        chunk.fold<double>(0, (s, r) => s + r.precioTotal);
    final disc = computeVolumeDiscountForLines(chunk);
    final busyKey =
        _entregaBusyKeyForImportadorChunk(chunk, bundleCheckoutGroupId);
    final puede = _puedeConfirmarRecepcionImportador(chunk);
    final esperaRecogida = _algunaLineaEsperaRecogidaImportador(chunk);
    final cg = chunk.first.checkoutGroupId?.trim() ?? '';
    final usePagoUnificado = chunk.length > 1 &&
        !chunk.any((TransactionRequestModel r) => r.hasAgreedCreditPlan) &&
        cg.isNotEmpty &&
        chunk.every((TransactionRequestModel r) => r.checkoutGroupId?.trim() == cg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${chunk.length} línea(s) · Subtotal ${formatRefAmount(subtotal)} REF',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        if (disc != null) ...[
          const SizedBox(height: 6),
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
        ],
        const SizedBox(height: 8),
        if (_lineasEnTransitoOCerrables(chunk).isNotEmpty) ...[
          FilledButton.icon(
            onPressed: (_entregaBusyId != null || !puede)
                ? null
                : () => _confirmarEntregaGrupoImportador(
                      context,
                      chunk: chunk,
                      checkoutGroupId: bundleCheckoutGroupId,
                    ),
            icon: _entregaBusyId == busyKey
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.inventory_2_outlined, size: 20),
            label: Text(
              _entregaBusyId == busyKey
                  ? 'Confirmando…'
                  : 'Confirmar recepción en tu taller',
            ),
          ),
          if (esperaRecogida) ...[
            const SizedBox(height: 8),
            Material(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Podrá confirmar cuando el transportista haya marcado la recogida '
                        'en almacén para los envíos en tránsito de este proveedor.',
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.35,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
        _PasarelaPagoMotoLinkCard(
          lineCount: chunk.length,
          singleComprobantePorProveedor: usePagoUnificado,
          child: usePagoUnificado
              ? _columnPagoUnificadoImportador(
                  chunk,
                  suppressExperienceParent: bundleCheckoutGroupId != null,
                )
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
                        openCreditExposureSum: _openCreditExposureSum,
                        onChanged: _load,
                        suppressExperience: bundleCheckoutGroupId != null,
                        suppressPrimaryTitle: true,
                        suppressNegotiationIntro: i > 0,
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 14),
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
            orderPrecioTotalUsd: chunk.fold<double>(
              0,
              (a, r) => a + r.precioTotal,
            ),
            suppressBuiltinTitle: true,
          ),
        ] else ...[
          OrderMotolinkThreadSection(
            key: ValueKey<String>('trm-aliado-${chunk.single.id}'),
            transactionRequestId: chunk.single.id,
            allowReplyAsAliado: _esEnCurso(chunk.single.status),
            allowReplyAsAdmin: false,
            onThreadChanged: _load,
            orderPrecioTotalUsd: chunk.single.precioTotal,
          ),
        ],
        if (bundleCheckoutGroupId != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AliadoOrderExperienceSection(
              request: chunk.first,
              onChanged: _load,
              bundleCheckoutGroupId: bundleCheckoutGroupId,
              bundleImportadorId: chunk.first.ownerId,
            ),
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
    return AliadoExpandableOrderCard(
      request: primary,
      checkoutGroupLines: isMulti ? g : null,
      expanded: _expandedRequestId == expandKey,
      onToggle: () => _toggleExpand(expandKey),
      statusLabel: isMulti ? _labelGrupo(g) : _label(primary),
      onConfirmarRecepcion: isMulti
          ? null
          : ((primary.status == TransactionRequestStatus.enTransito ||
                  primary.status == TransactionRequestStatus.enviado)
              ? () => _confirmarEntrega(context, primary)
              : null),
      confirmarRecepcionBusy: !isMulti && _entregaBusyId == primary.id,
      onCancelarSolicitudPendiente: _grupoPuedeCancelar(g)
          ? () => _cancelarGrupoPendiente(context, g)
          : null,
      cancelarSolicitudPendienteBusy: _cancelarBusyId == expandKey,
      expandedFooter: _orderCardFooter(context, g),
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
    required this.child,
  });

  final int lineCount;
  /// Varios ítems mismo importador: un archivo para todas las líneas (sin duplicar UI).
  final bool singleComprobantePorProveedor;
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
                      const Text(
                        'Pasarela de pago MotoLink',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        singleComprobantePorProveedor
                            ? 'Un comprobante por proveedor; el importador revisa aquí.'
                            : lineCount > 1
                                ? 'Plan de cuotas u otros casos: un registro por ítem.'
                                : 'Método y comprobante según el estado de esta línea.',
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
