import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/pago_metodo_instrucciones.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import '../utils/document_pick_utils.dart';
import 'importer_pago_transfer_details_card.dart';
import 'media_pick_action_chips.dart';
import 'moroso_order_visual.dart';

/// Aliado: factura del flete (pago separado) y comprobante de pago al transportista.
class AliadoFleteSeparadoSection extends StatefulWidget {
  const AliadoFleteSeparadoSection({
    super.key,
    required this.request,
    required this.onChanged,
    this.compact = false,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;
  final bool compact;

  @override
  State<AliadoFleteSeparadoSection> createState() =>
      _AliadoFleteSeparadoSectionState();
}

class _AliadoFleteSeparadoSectionState extends State<AliadoFleteSeparadoSection> {
  String? _metodoSeleccionado;
  bool _busy = false;
  bool _loadingPago = false;
  String? _carrierCompanyName;
  List<String> _metodosPermitidos = const [];
  Map<String, String> _instrucciones = const {};

  @override
  void initState() {
    super.initState();
    _applyCarrierPagoFromRequest();
    _syncMetodo();
    _loadCarrierPagoIfNeeded();
  }

  @override
  void didUpdateWidget(covariant AliadoFleteSeparadoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id ||
        oldWidget.request.fletePagoMetodo != widget.request.fletePagoMetodo ||
        oldWidget.request.importerCarrierId != widget.request.importerCarrierId ||
        oldWidget.request.carrierPagoInstruccionesSnapshot !=
            widget.request.carrierPagoInstruccionesSnapshot ||
        oldWidget.request.carrierAcceptedPagoMetodosSnapshot !=
            widget.request.carrierAcceptedPagoMetodosSnapshot) {
      _applyCarrierPagoFromRequest();
      _syncMetodo();
      _loadCarrierPagoIfNeeded();
    }
  }

  void _applyCarrierPagoFromRequest() {
    _carrierCompanyName = widget.request.carrierDisplayCompanyName;
    _metodosPermitidos = widget.request.metodosFletePagoPermitidos;
    _instrucciones = widget.request.carrierPagoInstruccionesEffective;
  }

  Future<void> _loadCarrierPagoIfNeeded() async {
    final r = widget.request;
    if (!r.hasImporterCarrierSelected) return;
    if (_instrucciones.isNotEmpty && _metodosPermitidos.isNotEmpty) return;

    setState(() => _loadingPago = true);
    try {
      final info =
          await SupabaseService.fetchAliadoPedidoCarrierPagoInfo(r.id);
      if (!mounted) return;
      setState(() {
        _carrierCompanyName = info.companyName ?? _carrierCompanyName;
        if (info.acceptedPagoMetodos.isNotEmpty) {
          _metodosPermitidos = PagoMetodo.filterByImporterAccepted(
            info.acceptedPagoMetodos,
          );
        }
        if (info.pagoInstrucciones.isNotEmpty) {
          _instrucciones = info.pagoInstrucciones;
        }
      });
      _syncMetodo();
    } catch (_) {
      // Mantiene datos del snapshot en request si el RPC falla.
    } finally {
      if (mounted) setState(() => _loadingPago = false);
    }
  }

  void _syncMetodo() {
    final permitidos = _metodosPermitidos;
    final m = widget.request.fletePagoMetodo?.trim();
    if (m != null && m.isNotEmpty && permitidos.contains(m)) {
      _metodoSeleccionado = m;
    } else if (permitidos.isNotEmpty) {
      _metodoSeleccionado = permitidos.first;
    } else {
      _metodoSeleccionado = null;
    }
  }

  String? _instruccionesFor(String? metodo) =>
      PagoMetodoInstrucciones.forMetodo(_instrucciones, metodo);

  Future<void> _abrirFactura(BuildContext context, String path) async {
    try {
      final url = await SupabaseService.createSignedUrlForOrderInvoice(path);
      final uri = Uri.parse(url);
      if (!context.mounted) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la factura: $e')),
      );
    }
  }

  Future<void> _abrirComprobante(BuildContext context, String path) async {
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
    final metodo = _metodoSeleccionado;
    final permitidos = _metodosPermitidos;
    if (metodo == null || !permitidos.contains(metodo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un método de pago del flete.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await SupabaseService.aliadoSubmitFleteComprobantePago(
        transactionRequestId: widget.request.id,
        metodo: metodo,
        bytes: picked.bytes,
        fileName: picked.fileName,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Comprobante del flete enviado. El importador lo revisará y confirmará el pago.',
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

  Future<void> _pickAndSubmit(
    BuildContext context,
    DocumentPickChannel channel,
  ) async {
    final picked = await pickKycDocument(channel: channel);
    if (picked == null) return;
    if (!context.mounted) return;
    await _subirComprobante(context, picked: picked);
  }

  bool _puedeModificarComprobanteFlete(TransactionRequestModel r) {
    if (!r.hasFleteFactura) return false;
    if (r.status == TransactionRequestStatus.rechazado) return false;
    final pe = r.fletePagoEstadoRevisionEfectivo;
    if (pe == PagoRevisionEstado.aprobado) return false;
    return true;
  }

  String _etiquetaEstadoFlete(String pe) {
    switch (pe) {
      case PagoRevisionEstado.pendiente:
        return 'Pendiente';
      case PagoRevisionEstado.enRevision:
        return 'En revisión por el importador';
      case PagoRevisionEstado.aprobado:
        return 'Confirmado por el importador';
      case PagoRevisionEstado.rechazado:
        return 'No aceptado · puede enviar otro';
      default:
        return pe;
    }
  }

  Widget _buildFacturaBlock(TransactionRequestModel r) {
    if (!r.hasFleteFactura) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          widget.compact ? 10 : 12,
          widget.compact ? 8 : 10,
          12,
          10,
        ),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 20, color: Colors.amber.shade900),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'El importador aún no adjunta la factura del transporte. Cuando la '
                'suba, podrá registrar aquí el pago del flete.',
                style: TextStyle(
                  fontSize: widget.compact ? 11 : 11.5,
                  height: 1.35,
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final path = r.fleteFacturaStoragePath!.trim();
    final name = r.fleteFacturaFileName?.trim();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        widget.compact ? 10 : 12,
        widget.compact ? 8 : 10,
        12,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping_outlined,
                  size: 20, color: Colors.teal.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Factura del transporte',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: widget.compact ? 12 : 13,
                    color: Colors.teal.shade900,
                  ),
                ),
              ),
              Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
            ],
          ),
          if (name != null && name.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(name, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800)),
          ],
          if (r.fleteFacturaSubmittedAt != null) ...[
            const SizedBox(height: 2),
            Text(
              'Recibida: ${formatEsShortDateTime(r.fleteFacturaSubmittedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
          if (r.carrierFeeUsdSnapshot != null) ...[
            const SizedBox(height: 4),
            Text(
              'Flete estimado: USD ${r.carrierFeeUsdSnapshot!.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _abrirFactura(context, path),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Ver factura del flete'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.brandBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildComprobanteBlock(TransactionRequestModel r) {
    if (!r.hasFleteFactura) return const SizedBox.shrink();

    final pe = r.fletePagoEstadoRevisionEfectivo;
    final puedeModificar = _puedeModificarComprobanteFlete(r);

    if (r.hasFleteComprobantePago && !puedeModificar) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined,
                    size: 20, color: Colors.green.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pago del flete confirmado',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
            if (r.fletePagoMetodo != null && r.fletePagoMetodo!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Método: ${PagoMetodo.labelEs(r.fletePagoMetodo!)}',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
              ),
            ],
            if (r.fleteComprobanteSubmittedAt != null) ...[
              const SizedBox(height: 2),
              Text(
                'Enviado: ${formatEsShortDateTime(r.fleteComprobanteSubmittedAt)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  _abrirComprobante(context, r.fleteComprobantePagoStoragePath!),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Ver comprobante del flete'),
            ),
          ],
        ),
      );
    }

    if (r.hasFleteComprobantePago) {
      final boxColor = pe == PagoRevisionEstado.rechazado
          ? Colors.red.shade50
          : Colors.blue.shade50;
      final borderColor = pe == PagoRevisionEstado.rechazado
          ? Colors.red.shade200
          : Colors.blue.shade200;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: boxColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _etiquetaEstadoFlete(pe),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: pe == PagoRevisionEstado.rechazado
                        ? Colors.red.shade900
                        : Colors.blue.shade900,
                  ),
                ),
                if (r.fletePagoMetodo != null &&
                    r.fletePagoMetodo!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Método: ${PagoMetodo.labelEs(r.fletePagoMetodo!)}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
                  ),
                ],
                if (pe == PagoRevisionEstado.rechazado &&
                    r.fleteComprobanteRechazoNota?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Motivo: ${r.fleteComprobanteRechazoNota}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.red.shade800,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _abrirComprobante(
                    context,
                    r.fleteComprobantePagoStoragePath!,
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Ver comprobante enviado'),
                ),
              ],
            ),
          ),
          if (puedeModificar) ...[
            const SizedBox(height: 12),
            _buildRegistroComprobanteForm(r),
          ],
        ],
      );
    }

    if (!puedeModificar) return const SizedBox.shrink();

    return _buildRegistroComprobanteForm(r);
  }

  Widget _buildRegistroComprobanteForm(TransactionRequestModel r) {
    final metodos = _metodosPermitidos;
    if (metodos.isEmpty && !_loadingPago) {
      return Text(
        'El transportista no tiene métodos de pago configurados. Acuerde el pago '
        'con el importador o el transportista.',
        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.35),
      );
    }

    final metodo = _metodoSeleccionado;
    final instrucciones = _instruccionesFor(metodo);
    final carrierName = _carrierCompanyName ?? r.carrierDisplayCompanyName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registrar pago del flete',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Pague al transportista según los datos indicados y adjunte el comprobante.',
          style: TextStyle(fontSize: 11.5, height: 1.35, color: Colors.grey.shade700),
        ),
        if (_loadingPago) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in metodos)
              ChoiceChip(
                label: Text(PagoMetodo.labelEs(m)),
                selected: metodo == m,
                onSelected: _busy || _loadingPago
                    ? null
                    : (v) {
                        if (!v) return;
                        setState(() => _metodoSeleccionado = m);
                      },
              ),
          ],
        ),
        if (metodo != null) ...[
          const SizedBox(height: 10),
          ImporterPagoTransferDetailsCard(
            metodo: metodo,
            instrucciones: instrucciones,
            importadorNombre: carrierName,
            sinDatosMensaje:
                'El transportista no publicó los datos de esta cuenta. '
                'Confirme con el importador o el transportista antes de pagar.',
          ),
        ],
        const SizedBox(height: 12),
        MediaPickActionChips(
          busy: _busy,
          maxWidth: double.infinity,
          onCamera: () => _pickAndSubmit(context, DocumentPickChannel.camera),
          onGallery: () => _pickAndSubmit(context, DocumentPickChannel.gallery),
          onFile: () => _pickAndSubmit(context, DocumentPickChannel.file),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    if (!r.aliadoMuestraSeccionFleteSeparado) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (r.esPedidoMoroso) ...[
          MorosoOrderDetailNotice(request: r, aliadoViewer: true, compact: true),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Icon(Icons.local_shipping_outlined, color: Colors.teal.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Flete (pago separado)',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: widget.compact ? 12.5 : 13.5,
                  color: Colors.teal.shade900,
                ),
              ),
            ),
          ],
        ),
        if (r.carrierDisplayCompanyName != null) ...[
          const SizedBox(height: 4),
          Text(
            r.carrierDisplayCompanyName!,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
          ),
        ],
        const SizedBox(height: 10),
        _buildFacturaBlock(r),
        if (r.hasFleteFactura) ...[
          const SizedBox(height: 12),
          _buildComprobanteBlock(r),
        ],
      ],
    );
  }
}
