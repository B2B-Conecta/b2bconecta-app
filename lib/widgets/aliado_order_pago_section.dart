import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/aliado_pago_frecuente_model.dart';
import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/profile_model.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'order_card_collapsible_layout.dart';
import 'profile_section_helpers.dart';
import '../utils/order_payment_pricing.dart';
import 'aliado_usd_payment_discount_ficha.dart';
import 'importer_pago_transfer_details_card.dart';
import 'moroso_order_visual.dart';

/// Método de pago y comprobante. El importador verifica la acreditación (negociación por chat).
class AliadoOrderPagoSection extends StatefulWidget {
  const AliadoOrderPagoSection({
    super.key,
    required this.request,
    required this.onChanged,
    this.profile,
    this.suppressPrimaryTitle = false,
    this.suppressNegotiationIntro = false,
    /// Si hay varias líneas del mismo importador en el carrito: un solo comprobante
    /// replica el archivo en todas (vía [SupabaseService.aliadoSubmitComprobantePagoBundle]).
    this.pagoBundleLines,
    this.onPagoMetodoPreviewChanged,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;
  final ProfileModel? profile;

  /// Líneas del mismo proveedor a actualizar con el mismo comprobante.
  final List<TransactionRequestModel>? pagoBundleLines;

  /// Notifica al contenedor de la ficha (pasarela) el método elegido para el banner.
  final ValueChanged<String?>? onPagoMetodoPreviewChanged;

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
  List<AliadoPagoFrecuenteModel> _pagosFrecuentes = [];

  List<String> get _metodosPermitidos =>
      widget.request.metodosPagoPermitidos;

  void _notifyMetodoPreview({bool immediate = false}) {
    final cb = widget.onPagoMetodoPreviewChanged;
    if (cb == null) return;
    final metodo = _metodoSeleccionado;
    void fire() {
      if (!mounted) return;
      cb(metodo);
    }
    // Evita setState en el padre durante build (!_dirty is not true).
    if (immediate) {
      fire();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => fire());
    }
  }

  void _syncMetodoSeleccionado({
    bool notifyParent = true,
    bool preferFrecuente = false,
  }) {
    final permitidos = _metodosPermitidos;
    final m = widget.request.pagoMetodo?.trim();
    if (m != null && m.isNotEmpty && permitidos.contains(m)) {
      _metodoSeleccionado = m;
    } else if (permitidos.isNotEmpty) {
      String? picked;
      if (preferFrecuente) {
        for (final f in _pagosFrecuentes) {
          if (permitidos.contains(f.pagoMetodo)) {
            picked = f.pagoMetodo;
            break;
          }
        }
      }
      _metodoSeleccionado = picked ?? permitidos.first;
    } else {
      _metodoSeleccionado = null;
    }
    if (notifyParent) {
      _notifyMetodoPreview();
    }
  }

  Future<void> _loadPagosFrecuentes() async {
    try {
      final list = await SupabaseService.fetchAliadoPagoFrecuenteImportador(
        widget.request.ownerId,
      );
      if (!mounted) return;
      setState(() => _pagosFrecuentes = list);
      _syncMetodoSeleccionado(preferFrecuente: true);
    } catch (_) {
      if (!mounted) return;
      _syncMetodoSeleccionado();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncMetodoSeleccionado(notifyParent: false);
    _loadPagosFrecuentes();
  }

  @override
  void didUpdateWidget(covariant AliadoOrderPagoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.request.ownerId != widget.request.ownerId ||
        oldWidget.request.ownerAcceptedPagoMetodos !=
            widget.request.ownerAcceptedPagoMetodos) {
      _loadPagosFrecuentes();
    }
  }

  List<AliadoPagoFrecuenteModel> get _frecuentesVisibles {
    final permitidos = _metodosPermitidos.toSet();
    return _pagosFrecuentes
        .where((f) => permitidos.contains(f.pagoMetodo))
        .toList();
  }

  void _seleccionarMetodo(String metodo) {
    setState(() => _metodoSeleccionado = metodo);
    _notifyMetodoPreview(immediate: true);
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
    final metodosPermitidos = _metodosPermitidos;
    final metodoPreview = r.hasComprobantePago && !puedeCambiarMetodo
        ? r.pagoMetodo
        : _metodoSeleccionado;
    final bundle = widget.pagoBundleLines;
    final discountPreview = bundle != null && bundle.length > 1
        ? OrderPaymentPricing.previewForLines(
            lines: bundle,
            pagoMetodo: metodoPreview,
          )
        : OrderPaymentPricing.previewForRequest(
            request: r,
            pagoMetodo: metodoPreview,
          );
    final mostrarGestionPago = !referenciaHistorica
        ? (_estadoPermiteDeclaracionPago(r) ||
            r.hasComprobantePago ||
            r.hasProveedorFactura)
        : r.tieneDocumentacionFacturaPago;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.esPedidoMoroso) ...[
          MorosoOrderDetailNotice(request: r, aliadoViewer: true, compact: true),
          const SizedBox(height: 8),
        ],
        if (!widget.suppressPrimaryTitle) ...[
          ProfileSectionHeader(
            label: referenciaHistorica
                ? 'PAGO (REFERENCIA)'
                : 'PAGO AL IMPORTADOR',
            infoMessage: referenciaHistorica
                ? OrderSectionHelp.pagoAliadoArchivo
                : OrderSectionHelp.pagoAliadoMetodo,
            infoTitle:
                referenciaHistorica ? 'Pago (referencia)' : 'Pago al importador',
            padding: const EdgeInsets.only(bottom: 8, top: 0),
          ),
        ] else if (!widget.suppressNegotiationIntro && !referenciaHistorica) ...[
          Align(
            alignment: Alignment.centerRight,
            child: ProfileInfoIcon(
              title: 'Pago al importador',
              message: OrderSectionHelp.pagoAliadoMetodo,
            ),
          ),
        ] else if (referenciaHistorica) ...[
          Align(
            alignment: Alignment.centerRight,
            child: ProfileInfoIcon(
              title: 'Pago (referencia)',
              message: OrderSectionHelp.pagoAliadoArchivo,
            ),
          ),
        ],
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
        if (referenciaHistorica && r.hasComprobantePago) ...[
          const SizedBox(height: 10),
          if (r.pagoMetodo != null && r.pagoMetodo!.trim().isNotEmpty) ...[
            Text(
              'Método: ${PagoMetodo.labelEs(r.pagoMetodo!)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 8),
          ],
          if (discountPreview.applies) ...[
            AliadoUsdPaymentDiscountFichaBanner(preview: discountPreview),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: () => _abrirComprobante(context),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Ver comprobante de pago'),
          ),
        ],
        if (!r.hasProveedorFactura && !referenciaHistorica && !mostrarGestionPago)
          Text(
            'Aquí podrá registrar método de pago y comprobante cuando el pedido lo permita.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.25,
            ),
          ),
        if (mostrarGestionPago && !referenciaHistorica) ...[
          if (discountPreview.applies) ...[
            const SizedBox(height: 10),
            AliadoUsdPaymentDiscountFichaBanner(preview: discountPreview),
            const SizedBox(height: 12),
          ],
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
                metodosPermitidos.isEmpty
                    ? 'Este importador no tiene métodos de pago configurados. Acuerde con él por chat.'
                    : 'Métodos habilitados por el importador; Zelle, Binance, USDT y efectivo pueden aplicar descuento en divisas.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          if (!referenciaHistorica &&
              puedeCambiarMetodo &&
              _frecuentesVisibles.isNotEmpty) ...[
            Text(
              'Pagos frecuentes con este importador',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in _frecuentesVisibles)
                  FilterChip(
                    label: Text(
                      '${PagoMetodo.labelEs(f.pagoMetodo)} · ${f.useCount}×',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    selected: _metodoSeleccionado == f.pagoMetodo,
                    onSelected: (_) => _seleccionarMetodo(f.pagoMetodo),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (metodosPermitidos.isEmpty)
            Text(
              'Sin métodos disponibles.',
              style: TextStyle(fontSize: 12, color: Colors.red.shade800),
            )
          else if (puedeCambiarMetodo)
            DropdownButtonFormField<String>(
              value: _metodoSeleccionado,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: metodosPermitidos
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(PagoMetodo.labelEs(c)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) _seleccionarMetodo(v);
              },
            )
          else
            Text(
              r.pagoMetodo != null && r.pagoMetodo!.trim().isNotEmpty
                  ? PagoMetodo.labelEs(r.pagoMetodo!)
                  : '—',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          if (metodoPreview != null) ...[
            if (metodoPreview.trim().isNotEmpty &&
                metodosPermitidos.contains(metodoPreview)) ...[
              const SizedBox(height: 10),
              ImporterPagoTransferDetailsCard(
                metodo: metodoPreview,
                instrucciones: r.pagoInstruccionesImportadorFor(metodoPreview),
                importadorNombre: r.ownerBusinessName,
              ),
            ],
          ],
          if (r.hasComprobantePago) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _abrirComprobante(context),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Ver comprobante de pago'),
            ),
          ],
          if (puedeModificarComprobante &&
              _metodoSeleccionado != null &&
              metodosPermitidos.isNotEmpty) ...[
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
