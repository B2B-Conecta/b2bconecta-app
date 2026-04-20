import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/profile_model.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// Factura MotoLink, método de pago y comprobante.
/// En preparación: edición según estado de revisión. Tras confirmación o con pedido cerrado: solo consulta.
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

  static const double _creditTol = 0.01;

  /// Primeros pedidos: solo transferencia/efectivo. Después: resto de medios + crédito si hay cupo;
  /// transferencia y efectivo siguen en [PagoMetodo.values] / [PagoMetodo.valuesPostContadoConCredito].
  List<String> get _metodosPermitidos {
    final p = widget.profile;
    if (p?.esAliadoEnFaseContado ?? false) {
      if (p?.puedeUsarLineaCreditoMotoLinkPreactivada ?? false) {
        return PagoMetodo.valuesPostContadoConCredito;
      }
      return PagoMetodo.valuesFaseContado;
    }
    final cl = p?.creditLimit;
    if (cl != null && cl > 0) {
      return PagoMetodo.valuesPostContadoConCredito;
    }
    return PagoMetodo.values;
  }

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
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.profile?.primerosPedidosContadoEntregados !=
            widget.profile?.primerosPedidosContadoEntregados ||
        oldWidget.profile?.creditLimit != widget.profile?.creditLimit) {
      _syncMetodoSeleccionado();
    }
  }

  Future<void> _abrirFactura(BuildContext context) async {
    final path = widget.request.facturaAliadoStoragePath?.trim();
    if (path == null || path.isEmpty) return;
    try {
      final url = await SupabaseService.createSignedUrlForFacturaAliado(path);
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
    if (metodo == PagoMetodo.creditoSistema) {
      await _declararCreditoSistema(context);
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
        SnackBar(
          content: Text(
            metodo == PagoMetodo.efectivo
                ? 'Comprobante de efectivo enviado. MotoLink lo revisará.'
                : 'Comprobante enviado. MotoLink lo revisará.',
          ),
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

  Future<void> _declararCreditoSistema(BuildContext context) async {
    final r = widget.request;
    setState(() => _busy = true);
    try {
      final profileFresh = await SupabaseService.fetchMyProfile();
      final lim = profileFresh?.creditLimit;
      final cons = profileFresh?.creditoConsumidoAcumulado ?? 0;
      final exposure =
          await SupabaseService.fetchOpenCreditExposureForCurrentAliado();
      if (lim != null && exposure + cons > lim + _creditTol) {
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cupo insuficiente'),
            content: const Text(
              'Con su línea actual no alcanza para los pedidos abiertos más el crédito '
              'ya utilizado en entregas. Use Pago Móvil, Zelle, transferencia o efectivo, '
              'o consulte con MotoLink.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
        return;
      }
      await SupabaseService.aliadoDeclararPagoCreditoSistema(
        transactionRequestId: r.id,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud enviada. MotoLink revisará el uso de su línea de crédito.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onChanged();
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString();
      final friendly = msg.contains('CUPO_INSUFICIENTE')
          ? 'No tiene cupo suficiente para esta operación. Elija otro medio de pago o consulte con MotoLink.'
          : msg;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Mientras el pago no esté aprobado por MotoLink, el aliado puede adjuntar o reemplazar comprobante.
  bool _puedeModificarComprobante(TransactionRequestModel r) {
    if (r.status != TransactionRequestStatus.enPreparacion) return false;
    if (!r.hasFacturaAliado) return false;
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
    final mostrar = r.status == TransactionRequestStatus.enPreparacion ||
        r.tieneDocumentacionFacturaPago;
    if (!mostrar) return const SizedBox.shrink();

    final pe = r.pagoEstadoRevisionEfectivo;
    final referenciaHistorica =
        r.status != TransactionRequestStatus.enPreparacion &&
            r.tieneDocumentacionFacturaPago;
    final puedeModificarComprobante = _puedeModificarComprobante(r);
    final puedeCambiarMetodo =
        puedeModificarComprobante && _puedeCambiarMetodo(r);
    final expSum = widget.openCreditExposureSum;
    final dispoCred = expSum != null && widget.profile != null
        ? widget.profile!.cupoDisponible(expSum)
        : null;
    final bloquearCreditoBtn =
        dispoCred != null && dispoCred <= _creditTol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          referenciaHistorica
              ? 'Factura y pago (referencia)'
              : 'Factura y pago',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
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
            'Factura MotoLink: ${r.facturaAliadoFileName ?? 'documento'}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
          Text(
            'Emitida: ${formatEsShortDateTime(r.facturaAliadoSubmittedAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _abrirFactura(context),
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Ver / descargar factura'),
          ),
        ] else if (!referenciaHistorica)
          Text(
            'Cuando MotoLink emita la factura oficial, podrá descargarla aquí y continuar con el pago.',
            style: TextStyle(
                fontSize: 12, color: Colors.grey.shade700, height: 1.25),
          ),
        if (r.hasFacturaAliado) ...[
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
          if (!referenciaHistorica && widget.profile != null) ...[
            if (widget.profile!.esAliadoEnFaseContado)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'En sus primeros pedidos en contado solo puede elegir transferencia o efectivo. '
                  'Después podrá usar la línea MotoLink si tiene KYC aprobado y cupo, u otros medios.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Colors.grey.shade700,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'La línea de crédito MotoLink requiere KYC aprobado y cupo asignado. '
                  'Transferencia y efectivo siguen disponibles para compras al contado.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
          ],
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
            if (_metodoSeleccionado == PagoMetodo.creditoSistema) ...[
              const SizedBox(height: 10),
              if (bloquearCreditoBtn) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    'No tiene cupo disponible con la línea actual (pedidos abiertos más crédito '
                    'ya utilizado en entregas). Elija Pago Móvil, Zelle, transferencia o efectivo.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber.shade900,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'El importe se imputará a su línea de crédito autorizada por MotoLink. '
                'El cupo se ajusta al confirmar la entrega del pedido.',
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
                  onPressed: (_busy || bloquearCreditoBtn)
                      ? null
                      : () => _declararCreditoSistema(context),
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
                          pe == PagoRevisionEstado.rechazado
                              ? 'Reintentar solicitud de crédito'
                              : 'Solicitar pago con línea de crédito MotoLink',
                        ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                pe == PagoRevisionEstado.enRevision
                    ? 'Si subió un archivo por error, puede reemplazarlo; el nuevo quedará otra vez en revisión por MotoLink.'
                    : _metodoSeleccionado == PagoMetodo.efectivo
                        ? 'Adjunte su comprobante/soporte del pago en efectivo. Este archivo lo registra el aliado.'
                        : 'Adjunte una foto clara del comprobante (Pago Móvil, Zelle o transferencia).',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade700, height: 1.25),
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
          ],
          if (!referenciaHistorica && pe == PagoRevisionEstado.enRevision)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                r.pagoMetodo?.trim() == PagoMetodo.creditoSistema
                    ? 'Solicitud de crédito en revisión. MotoLink le avisará al aprobarla.'
                    : r.pagoMetodo?.trim() == PagoMetodo.efectivo
                        ? 'Comprobante en revisión. MotoLink le avisará al aprobarlo. '
                            'Puede reemplazar el archivo con el botón de arriba si hubo un error.'
                        : 'Comprobante en revisión. MotoLink le avisará al aprobarlo. '
                            'Puede reemplazar el archivo con el botón de arriba si hubo un error.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ),
          if (!referenciaHistorica && pe == PagoRevisionEstado.aprobado)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                r.pagoMetodo?.trim() == PagoMetodo.creditoSistema
                    ? 'Pago con crédito del sistema confirmado. MotoLink marcará pronto el envío en tránsito.'
                    : r.pagoMetodo?.trim() == PagoMetodo.efectivo
                        ? 'Pago en efectivo confirmado. MotoLink marcará pronto el envío en tránsito.'
                        : 'Pago confirmado. MotoLink marcará pronto el envío en tránsito.',
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
                'MotoLink: ${r.pagoComprobanteRechazoNota}',
                style: TextStyle(
                    fontSize: 11, color: Colors.red.shade900, height: 1.3),
              ),
            ),
        ],
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
    if (r.pagoMetodo?.trim() == PagoMetodo.efectivo) {
      return 'Adjuntar comprobante de efectivo';
    }
    return 'Adjuntar comprobante de pago';
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
