import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/profile_model.dart';
import '../models/payment_schedule_model.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/ves_amount_format.dart';
import '../utils/app_date_format.dart';
import 'aliado_order_experience_section.dart';

/// Método de pago y comprobante. El importador verifica la acreditación (negociación por chat).
class AliadoOrderPagoSection extends StatefulWidget {
  const AliadoOrderPagoSection({
    super.key,
    required this.request,
    required this.onChanged,
    this.profile,
    this.openCreditExposureSum,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;
  final ProfileModel? profile;

  /// Suma de `precio_total` de pedidos abiertos del aliado (misma regla que el cupo en servidor).
  final double? openCreditExposureSum;

  @override
  State<AliadoOrderPagoSection> createState() => _AliadoOrderPagoSectionState();
}

class _AliadoOrderPagoSectionState extends State<AliadoOrderPagoSection> {
  String? _metodoSeleccionado;
  bool _busy = false;
  final Map<String, String> _metodoPorCuotaId = {};

  /// MotoConecta: Zelle, Pago Móvil, Binance y transferencia (verificación por el importador).
  List<String> get _metodosPermitidos => PagoMetodo.valuesMotoconecta;

  void _syncMetodoSeleccionado() {
    final permitidos = _metodosPermitidos;
    final m = widget.request.pagoMetodo?.trim();
    if (m != null && m.isNotEmpty && permitidos.contains(m)) {
      _metodoSeleccionado = m;
    } else {
      _metodoSeleccionado = permitidos.first;
    }
  }

  @override
  void initState() {
    super.initState();
    _syncMetodoSeleccionado();
  }

  @override
  void didUpdateWidget(covariant AliadoOrderPagoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id) {
      _metodoPorCuotaId.clear();
    }
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.profile?.primerosPedidosContadoEntregados !=
            widget.profile?.primerosPedidosContadoEntregados ||
        oldWidget.profile?.creditLimit != widget.profile?.creditLimit) {
      _syncMetodoSeleccionado();
    }
  }

  List<String> get _metodosComprobanteCuota => PagoMetodo.valuesMotoconecta;

  String _metodoParaCuota(String scheduleId) {
    final m = _metodoPorCuotaId[scheduleId]?.trim();
    final allowed = _metodosComprobanteCuota;
    if (m != null && m.isNotEmpty && allowed.contains(m)) return m;
    return allowed.isNotEmpty ? allowed.first : PagoMetodo.transferencia;
  }

  Future<void> _abrirComprobanteCuota(
    BuildContext context,
    PaymentScheduleModel c,
  ) async {
    final path = c.pagoComprobanteStoragePath?.trim();
    if (path == null || path.isEmpty) return;
    try {
      final url = await SupabaseService.createSignedUrlForComprobantePago(path);
      final uri = Uri.parse(url);
      if (!context.mounted) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _subirComprobanteCuota(
    BuildContext context,
    PaymentScheduleModel c,
  ) async {
    if (c.id.isEmpty) return;
    final metodo = _metodoParaCuota(c.id);
    if (!_metodosComprobanteCuota.contains(metodo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un método de pago para esta cuota.')),
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final bytes = f.bytes;
    final name = f.name.trim();
    if (bytes == null || bytes.isEmpty || name.isEmpty) return;

    setState(() => _busy = true);
    try {
      await SupabaseService.aliadoSubmitComprobantePagoCuota(
        paymentScheduleId: c.id,
        metodo: metodo,
        bytes: bytes,
        fileName: name,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comprobante de cuota enviado. El importador lo revisará.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _abrirFacturaPath(BuildContext context, String path) async {
    final p = path.trim();
    if (p.isEmpty) return;
    try {
      final url = await SupabaseService.createSignedUrlForFacturaAliado(p);
      final uri = Uri.parse(url);
      if (!context.mounted) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _abrirComprobante(BuildContext context) async {
    final path = widget.request.comprobantePagoStoragePath?.trim();
    if (path == null || path.isEmpty) return;
    try {
      final url = await SupabaseService.createSignedUrlForComprobantePago(path);
      final uri = Uri.parse(url);
      if (!context.mounted) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _subirComprobante(BuildContext context) async {
    final r = widget.request;
    final metodo = _metodoSeleccionado;
    if (metodo == null || !_metodosPermitidos.contains(metodo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un método de pago.')),
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final bytes = f.bytes;
    final name = f.name.trim();
    if (bytes == null || bytes.isEmpty || name.isEmpty) return;

    setState(() => _busy = true);
    try {
      await SupabaseService.aliadoSubmitComprobantePago(
        transactionRequestId: r.id,
        metodo: metodo,
        bytes: bytes,
        fileName: name,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comprobante enviado. El importador verificará la acreditación.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _estadoPermiteDeclaracionPago(TransactionRequestModel r) {
    return TransactionRequestStatus.aliadoDeclaracionPagoMultietapa
        .contains(r.status);
  }

  /// Mientras el importador no confirme el pago, el aliado puede adjuntar o reemplazar comprobante.
  bool _puedeModificarComprobante(TransactionRequestModel r) {
    if (!_estadoPermiteDeclaracionPago(r)) return false;
    final pe = r.pagoEstadoRevisionEfectivo;
    if (pe == PagoRevisionEstado.aprobado) return false;
    return pe == PagoRevisionEstado.pendiente ||
        pe == PagoRevisionEstado.enRevision ||
        pe == PagoRevisionEstado.rechazado;
  }

  /// Cambiar método solo antes de enviar a revisión o tras rechazo (no durante revisión).
  bool _puedeCambiarMetodo(TransactionRequestModel r) {
    final pe = r.pagoEstadoRevisionEfectivo;
    return pe == PagoRevisionEstado.pendiente ||
        pe == PagoRevisionEstado.rechazado;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final mostrar = r.status != TransactionRequestStatus.rechazado &&
        (_estadoPermiteDeclaracionPago(r) || r.tieneDocumentacionFacturaPago);
    if (!mostrar) return const SizedBox.shrink();

    final pe = r.pagoEstadoRevisionEfectivo;
    final puedeModificarComprobante = _puedeModificarComprobante(r);
    final referenciaHistorica =
        r.status == TransactionRequestStatus.entregado &&
            r.tieneDocumentacionFacturaPago &&
            !puedeModificarComprobante &&
            pe == PagoRevisionEstado.aprobado;
    final puedeCambiarMetodo =
        puedeModificarComprobante && _puedeCambiarMetodo(r);
    final mostrarGestionPago = !referenciaHistorica
        ? (_estadoPermiteDeclaracionPago(r) ||
            r.hasComprobantePago ||
            r.hasFacturaAliado)
        : r.tieneDocumentacionFacturaPago;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          referenciaHistorica ? 'Pago (referencia)' : 'Pago al importador',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        if (r.hasAgreedCreditPlan) ...[
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: AppColors.brandBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.brandBlue.withOpacity(0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.creditPlanType == 1
                      ? 'Pago al contado acordado con MotoLink (1 cuota).'
                      : 'Plan de ${r.creditPlanType} cuotas acordado con MotoLink (venc. cada 15 días, desde la fecha de registro).',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey.shade900,
                    height: 1.3,
                  ),
                ),
                if (r.creditPlanConfirmedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Plan confirmado: ${formatEsShortDateTime(r.creditPlanConfirmedAt)} (fecha/hora al formalizar con MotoLink).',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                      color: Colors.blueGrey.shade800,
                      height: 1.3,
                    ),
                  ),
                ],
                if (r.saldoPendienteRealConPlan != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Saldo pendiente real: ${formatRefAmount(r.saldoPendienteRealConPlan!)} REF (total menos cuotas aprobadas por MotoLink).',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.indigo.shade900,
                      height: 1.3,
                    ),
                  ),
                ],
                if (r.creditMontoBloqueado != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Monto vinculado a su cupo: ${formatRefAmount(r.creditMontoBloqueado!)} REF al formalizar el plan.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.blueGrey.shade800,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                ...r.paymentSchedule.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'Cuota ${e.installmentIndex}: ${_fmtMoney(e.amountUsd)} — '
                      'vence ${_formatDueEs(e.dueOn)} · ${e.pagoAprobado ? 'Aprobada' : _etiquetaEstadoPago(e.pagoEstadoEfectivo)}'
                      '${e.pagoSubmittedAt != null ? ' · registrada: ${formatEsShortDateTime(e.pagoSubmittedAt)}' : ''}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade800,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (!referenciaHistorica)
          Text(
            'Negocie condiciones y documentos con el importador en el chat del pedido. '
            'Aquí solo registra método de pago y comprobante; el importador confirma que recibió el pago.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.35,
              color: Colors.grey.shade700,
            ),
          ),
        if (!referenciaHistorica) const SizedBox(height: 6),
        if (referenciaHistorica)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Documentación confirmada · solo consulta (conservada aunque el pedido ya esté entregado).',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        if (!referenciaHistorica && r.aliadoPagoEstadoResumenEs != null)
          Text(
            r.aliadoPagoEstadoResumenEs!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brandBlue.withOpacity(0.95),
              height: 1.25,
            ),
          ),
        if (!referenciaHistorica && r.aliadoPagoEstadoResumenEs != null)
          const SizedBox(height: 8),
        if (referenciaHistorica) ...[
          Text(
            'Estado del pago: ${_etiquetaEstadoPago(pe)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (!r.hasFacturaAliado &&
            referenciaHistorica &&
            r.hasComprobantePago) ...[
          OutlinedButton.icon(
            onPressed: () => _abrirComprobante(context),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Ver comprobante de pago'),
          ),
          const SizedBox(height: 8),
        ],
        if (r.hasFacturaAliado) ...[
          Text(
            r.motolinkAllyInvoicesDescargables.length > 1
                ? 'Facturas MotoLink (${r.motolinkAllyInvoicesDescargables.length} documentos)'
                : 'Factura MotoLink: ${r.facturaAliadoFileName ?? 'documento'}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
          Text(
            'Emitida: ${formatEsShortDateTime(r.facturaAliadoSubmittedAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          if (r.motolinkAllyInvoicesDescargables.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in r.motolinkAllyInvoicesDescargables)
                  OutlinedButton.icon(
                    onPressed: e.storagePath == null ||
                            e.storagePath!.trim().isEmpty
                        ? null
                        : () => _abrirFacturaPath(context, e.storagePath!),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(
                      e.downloadButtonLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            )
          else if (r.facturaAliadoStoragePath != null &&
              r.facturaAliadoStoragePath!.trim().isNotEmpty)
            OutlinedButton.icon(
              onPressed: () =>
                  _abrirFacturaPath(context, r.facturaAliadoStoragePath!),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Ver / descargar factura'),
            ),
        ] else if (!referenciaHistorica && !mostrarGestionPago)
          Text(
            'Aquí podrá registrar método de pago y comprobante cuando el pedido lo permita.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.25,
            ),
          ),
        if (mostrarGestionPago && r.hasAgreedCreditPlan && r.hasFacturaAliado) ...[
          if (!referenciaHistorica) ...[
            const Text(
              'Pago de cada cuota',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ...r.paymentSchedule.map((c) {
              if (c.id.isEmpty) return const SizedBox.shrink();
              final pe = c.pagoEstadoEfectivo;
              final puede = _estadoPermiteDeclaracionPago(r) &&
                  pe != PagoRevisionEstado.aprobado &&
                  (pe == PagoRevisionEstado.pendiente ||
                      pe == PagoRevisionEstado.enRevision ||
                      pe == PagoRevisionEstado.rechazado);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cuota ${c.installmentIndex} · vence ${_formatDueEs(c.dueOn)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Importe: ${_fmtMoney(c.amountUsd)} · ${_etiquetaEstadoPago(pe)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                        ),
                        if (c.pagoSubmittedAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Pago registrado: ${formatEsShortDateTime(c.pagoSubmittedAt)}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: Colors.blueGrey.shade800,
                            ),
                          ),
                        ],
                        if (c.hasPagoComprobante) ...[
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: () => _abrirComprobanteCuota(context, c),
                            icon: const Icon(Icons.receipt, size: 16),
                            label: const Text('Ver comprobante de esta cuota'),
                          ),
                        ],
                        if (c.pagoComprobanteRechazoNota != null &&
                            c.pagoComprobanteRechazoNota!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Importador: ${c.pagoComprobanteRechazoNota}',
                            style: TextStyle(
                                fontSize: 10, color: Colors.red.shade800),
                          ),
                        ],
                        if (puede) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _metodoParaCuota(c.id),
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Método',
                              border: OutlineInputBorder(),
                            ),
                            items: _metodosComprobanteCuota
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(PagoMetodo.labelEs(m)),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _metodoPorCuotaId[c.id] = v);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () => _subirComprobanteCuota(context, c),
                              child: const Text('Subir comprobante (esta cuota)'),
                            ),
                          ),
                        ],
                        if (!puede && pe == PagoRevisionEstado.aprobado)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Pago de esta cuota confirmado por el importador.',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ] else if (mostrarGestionPago) ...[
          const SizedBox(height: 14),
          const Text(
            'Método de pago',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          if (!referenciaHistorica)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Disponibles: Zelle, Pago Móvil, Binance y transferencia bancaria. '
                'El importador verifica el comprobante.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          if (puedeCambiarMetodo)
            DropdownButtonFormField<String>(
              value: _metodoSeleccionado,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _metodosPermitidos
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(PagoMetodo.labelEs(c)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _metodoSeleccionado = v),
            )
          else
            Text(
              r.pagoMetodo != null && r.pagoMetodo!.trim().isNotEmpty
                  ? PagoMetodo.labelEs(r.pagoMetodo!)
                  : '—',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          if (r.hasComprobantePago) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _abrirComprobante(context),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Ver comprobante de pago'),
            ),
          ],
          if (puedeModificarComprobante && _metodoSeleccionado != null) ...[
            const SizedBox(height: 10),
            Text(
              pe == PagoRevisionEstado.enRevision
                  ? 'Si subió un archivo por error, puede reemplazarlo; el importador verá de nuevo el comprobante.'
                  : 'Adjunte una imagen o PDF claro del comprobante según el método elegido (Zelle, Pago Móvil, Binance o transferencia).',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : () => _subirComprobante(context),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _labelBotonComprobante(r, pe),
                      ),
              ),
            ),
          ],
        if (!referenciaHistorica && pe == PagoRevisionEstado.enRevision)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Comprobante en revisión por el importador. Puede reemplazar el archivo con el botón de arriba si hubo un error.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ),
          if (!referenciaHistorica && pe == PagoRevisionEstado.aprobado)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pago confirmado por el importador.',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
            ),
          if (!referenciaHistorica &&
              pe == PagoRevisionEstado.rechazado &&
              r.pagoComprobanteRechazoNota != null &&
              r.pagoComprobanteRechazoNota!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Importador: ${r.pagoComprobanteRechazoNota}',
                style: TextStyle(
                    fontSize: 11, color: Colors.red.shade900, height: 1.3),
              ),
            ),
        ],
        AliadoOrderExperienceSection(
          request: r,
          onChanged: widget.onChanged,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  static String _labelBotonComprobante(
    TransactionRequestModel r,
    String pe,
  ) {
    if (pe == PagoRevisionEstado.enRevision && r.hasComprobantePago) {
      return 'Reemplazar comprobante';
    }
    if (pe == PagoRevisionEstado.rechazado) {
      return 'Enviar nuevo comprobante';
    }
    return 'Adjuntar comprobante de pago';
  }

  static String _fmtMoney(double v) => '${formatRefAmount(v)} REF';

  static String _formatDueEs(DateTime d) {
    final l = d.isUtc ? d.toLocal() : d;
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  static String _etiquetaEstadoPago(String pe) {
    switch (pe) {
      case PagoRevisionEstado.pendiente:
        return 'Pendiente';
      case PagoRevisionEstado.enRevision:
        return 'En revisión';
      case PagoRevisionEstado.aprobado:
        return 'Confirmado';
      case PagoRevisionEstado.rechazado:
        return 'Rechazado';
      default:
        return pe;
    }
  }
}
