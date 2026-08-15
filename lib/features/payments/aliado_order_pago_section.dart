import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pago_metodo.dart';
import 'pago_revision_estado.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_status.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/orders/shared/order_card_collapsible_layout.dart';
import 'package:motolink_pro_app/features/profile/profile_section_helpers.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'package:motolink_pro_app/features/orders/shared/order_payment_pricing.dart';
import 'aliado_usd_payment_discount_ficha.dart';
import 'importer_pago_transfer_details_card.dart';
import 'package:motolink_pro_app/core/widgets/media_pick_action_chips.dart';
import 'package:motolink_pro_app/features/orders/shared/moroso_order_visual.dart';

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

  void _syncMetodoSeleccionado({bool notifyParent = true}) {
    final permitidos = _metodosPermitidos;
    final m = widget.request.pagoMetodo?.trim();
    if (m != null && m.isNotEmpty && permitidos.contains(m)) {
      _metodoSeleccionado = m;
    } else if (permitidos.isNotEmpty) {
      _metodoSeleccionado = permitidos.first;
    } else {
      _metodoSeleccionado = null;
    }
    if (notifyParent) {
      _notifyMetodoPreview();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncMetodoSeleccionado(notifyParent: false);
  }

  @override
  void didUpdateWidget(covariant AliadoOrderPagoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.request.ownerId != widget.request.ownerId ||
        oldWidget.request.ownerAcceptedPagoMetodos !=
            widget.request.ownerAcceptedPagoMetodos) {
      _syncMetodoSeleccionado();
    }
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

  Future<void> _subirComprobante(
    BuildContext context, {
    required PickedDocumentBytes picked,
  }) async {
    final r = widget.request;
    final metodo = _metodoSeleccionado;
    if (metodo == null || !_metodosPermitidos.contains(metodo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un método de pago.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final bundle = widget.pagoBundleLines;
      if (bundle != null && bundle.length > 1) {
        await SupabaseService.aliadoSubmitComprobantePagoBundle(
          lines: bundle,
          metodo: metodo,
          bytes: picked.bytes,
          fileName: picked.fileName,
        );
      } else {
        await SupabaseService.aliadoSubmitComprobantePago(
          transactionRequestId: r.id,
          metodo: metodo,
          bytes: picked.bytes,
          fileName: picked.fileName,
        );
      }
      if (!context.mounted) return;
      final esEfectivo = metodo == PagoMetodo.efectivo;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bundle != null && bundle.length > 1
                ? esEfectivo
                    ? 'Foto enviada. El importador confirmará la recepción del efectivo.'
                    : 'Comprobante enviado. El importador lo revisará.'
                : esEfectivo
                    ? 'Foto enviada. El importador confirmará la recepción del efectivo.'
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

  Future<void> _pickAndSubmitComprobante(
    BuildContext context,
    DocumentPickChannel channel,
  ) async {
    final picked = await pickKycDocument(channel: channel);
    if (picked == null) return;
    if (!context.mounted) return;
    await _subirComprobante(context, picked: picked);
  }

  Future<void> _declararPagoEfectivo(BuildContext context) async {
    if (_metodoSeleccionado != PagoMetodo.efectivo) return;

    setState(() => _busy = true);
    try {
      final bundle = widget.pagoBundleLines;
      if (bundle != null && bundle.length > 1) {
        await SupabaseService.aliadoDeclaraPagoEfectivoBundle(lines: bundle);
      } else {
        await SupabaseService.aliadoDeclaraPagoEfectivo(
          transactionRequestId: widget.request.id,
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pago en efectivo declarado. El importador confirmará cuando reciba el dinero.',
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
          const Align(
            alignment: Alignment.centerRight,
            child: ProfileInfoIcon(
              title: 'Pago al importador',
              message: OrderSectionHelp.pagoAliadoMetodo,
            ),
          ),
        ] else if (referenciaHistorica) ...[
          const Align(
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
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (referenciaHistorica && r.hasComprobantePago) ...[
          const SizedBox(height: 10),
          if (r.pagoMetodo != null && r.pagoMetodo!.trim().isNotEmpty) ...[
            Text(
              'Método: ${PagoMetodo.labelEs(r.pagoMetodo!)}',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
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
              color: AppColors.textSecondary,
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
          Text(
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
                  color: AppColors.textSecondary,
                ),
              ),
            ),
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
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
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
            if (_metodoSeleccionado == PagoMetodo.efectivo) ...[
              if (pe == PagoRevisionEstado.pendiente ||
                  pe == PagoRevisionEstado.rechazado) ...[
                Text(
                  pe == PagoRevisionEstado.rechazado
                      ? 'Declare de nuevo el pago en efectivo. Puede adjuntar una foto opcional.'
                      : 'Declare el pago en efectivo. Una foto con la cámara es opcional.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _declararPagoEfectivo(context),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: Text(
                      pe == PagoRevisionEstado.rechazado
                          ? 'Declarar pago en efectivo de nuevo'
                          : 'Declarar pago en efectivo',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Foto opcional',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
              ] else ...[
                Text(
                  r.hasComprobantePago
                      ? 'Puede reemplazar la foto si hubo error.'
                      : 'Esperando confirmación del importador. Puede adjuntar una foto opcional.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              MediaPickActionChips(
                busy: _busy,
                maxWidth: double.infinity,
                onCamera: () => _pickAndSubmitComprobante(
                  context,
                  DocumentPickChannel.camera,
                ),
                onGallery: () => _pickAndSubmitComprobante(
                  context,
                  DocumentPickChannel.gallery,
                ),
                onFile: () => _pickAndSubmitComprobante(
                  context,
                  DocumentPickChannel.file,
                ),
              ),
            ] else ...[
              Text(
                pe == PagoRevisionEstado.enRevision
                    ? 'Puede reemplazar el archivo si hubo error.'
                    : 'Use cámara, galería o suba imagen/PDF legible.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              MediaPickActionChips(
                busy: _busy,
                maxWidth: double.infinity,
                onCamera: () => _pickAndSubmitComprobante(
                  context,
                  DocumentPickChannel.camera,
                ),
                onGallery: () => _pickAndSubmitComprobante(
                  context,
                  DocumentPickChannel.gallery,
                ),
                onFile: () => _pickAndSubmitComprobante(
                  context,
                  DocumentPickChannel.file,
                ),
              ),
            ],
          ],
        if (!referenciaHistorica && pe == PagoRevisionEstado.enRevision)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _metodoSeleccionado == PagoMetodo.efectivo
                    ? 'En revisión; el importador confirmará la recepción del efectivo.'
                    : 'En revisión; puede reemplazar el archivo con las opciones de arriba.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
