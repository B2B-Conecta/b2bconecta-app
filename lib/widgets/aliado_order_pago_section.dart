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
import 'aliado_order_experience_section.dart';
import 'moroso_order_visual.dart';

/// Método de pago y comprobante. El importador verifica la acreditación (negociación por chat).
class AliadoOrderPagoSection extends StatefulWidget {
  const AliadoOrderPagoSection({
    super.key,
    required this.request,
    required this.onChanged,
    this.profile,
    this.suppressExperience = false,
    this.suppressPrimaryTitle = false,
    this.suppressNegotiationIntro = false,
    /// Si hay varias líneas del mismo importador en el carrito: un solo comprobante
    /// replica el archivo en todas (vía [SupabaseService.aliadoSubmitComprobantePagoBundle]).
    this.pagoBundleLines,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;
  final ProfileModel? profile;

  /// Líneas del mismo proveedor a actualizar con el mismo comprobante.
  final List<TransactionRequestModel>? pagoBundleLines;

  /// Si es true, no muestra [AliadoOrderExperienceSection] (el padre muestra una valoración por proveedor).
  final bool suppressExperience;

  /// El padre muestra un título grupal («Pago al importador») cuando hay varias líneas del mismo almacén.
  final bool suppressPrimaryTitle;

  /// Junto a [suppressPrimaryTitle]: evita repetir el párrafo de negociación/chat en cada línea.
  final bool suppressNegotiationIntro;

  @override
  State<AliadoOrderPagoSection> createState() => _AliadoOrderPagoSectionState();
}

class _AliadoOrderPagoSectionState extends State<AliadoOrderPagoSection> {
  String? _metodoSeleccionado;
  bool _busy = false;

  /// MotoConecta: Zelle, Pago Móvil, Binance, transferencia y efectivo (verificación por el importador).
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
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.profile?.primerosPedidosContadoEntregados !=
            widget.profile?.primerosPedidosContadoEntregados) {
      _syncMetodoSeleccionado();
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
      final bundle = widget.pagoBundleLines;
      if (bundle != null && bundle.length > 1) {
        await SupabaseService.aliadoSubmitComprobantePagoBundle(
          lines: bundle,
          metodo: metodo,
          bytes: bytes,
          fileName: name,
        );
      } else {
        await SupabaseService.aliadoSubmitComprobantePago(
          transactionRequestId: r.id,
          metodo: metodo,
          bytes: bytes,
          fileName: name,
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bundle != null && bundle.length > 1
                ? 'Comprobante enviado. El importador lo revisará.'
                : 'Comprobante enviado. El importador verificará la acreditación.',
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
        if (r.esPedidoMoroso) ...[
          MorosoOrderDetailNotice(request: r, aliadoViewer: true, compact: true),
          const SizedBox(height: 8),
        ],
        if (!widget.suppressPrimaryTitle) ...[
          Text(
            referenciaHistorica ? 'Pago (referencia)' : 'Pago al importador',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (!referenciaHistorica && !widget.suppressNegotiationIntro)
          Text(
            'Condiciones en el chat del pedido; aquí método y comprobante.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.35,
              color: Colors.grey.shade700,
            ),
          ),
        if (!referenciaHistorica && !widget.suppressNegotiationIntro)
          const SizedBox(height: 6),
        if (referenciaHistorica)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Documentación archivada · solo consulta.',
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
        ],
        if (referenciaHistorica && r.hasComprobantePago) ...[
          const SizedBox(height: 10),
          if (r.pagoMetodo != null && r.pagoMetodo!.trim().isNotEmpty) ...[
            Text(
              'Método: ${PagoMetodo.labelEs(r.pagoMetodo!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: () => _abrirComprobante(context),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Ver comprobante de pago'),
          ),
        ],
        if (!r.hasFacturaAliado && !referenciaHistorica && !mostrarGestionPago)
          Text(
            'Aquí podrá registrar método de pago y comprobante cuando el pedido lo permita.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.25,
            ),
          ),
        if (mostrarGestionPago && !referenciaHistorica) ...[
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
                'Zelle, Pago Móvil, Binance, transferencia o efectivo; el importador verifica.',
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
                  ? 'Puede reemplazar el archivo si hubo error.'
                  : 'Imagen o PDF legible según el método.',
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
                'En revisión; puede reemplazar el archivo con el botón de arriba.',
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
        if (!widget.suppressExperience)
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
