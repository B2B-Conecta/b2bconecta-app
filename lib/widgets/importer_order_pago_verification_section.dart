import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pago_metodo.dart';
import '../models/pago_revision_estado.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';
import 'b2b_order_panel_widgets.dart';

/// Verificación del comprobante declarado por el aliado (Zelle, Pago Móvil, Binance, transferencia, efectivo).
class ImporterOrderPagoVerificationSection extends StatefulWidget {
  const ImporterOrderPagoVerificationSection({
    super.key,
    required this.request,
    required this.onChanged,
    /// En el mismo panel, varias líneas: el padre muestra el producto; oculta el título repetido.
    this.hideMajorTitle = false,
    /// Mismo carrito e importador: un comprobante y una revisión para todas las líneas.
    this.bundleLines,
  });

  final TransactionRequestModel request;
  final VoidCallback onChanged;
  final bool hideMajorTitle;

  /// Si se informa con 2+ filas, la UI y la acción de aprobar/rechazar aplican a todas.
  final List<TransactionRequestModel>? bundleLines;

  @override
  State<ImporterOrderPagoVerificationSection> createState() =>
      _ImporterOrderPagoVerificationSectionState();
}

class _ImporterOrderPagoVerificationSectionState
    extends State<ImporterOrderPagoVerificationSection> {
  bool _busy = false;

  bool get _usaBundle =>
      widget.bundleLines != null && widget.bundleLines!.length > 1;

  List<TransactionRequestModel> get _lines =>
      _usaBundle ? widget.bundleLines! : [widget.request];

  Future<void> _abrirComprobante(BuildContext context) async {
    final ref = _comprobanteRefParaAbrir();
    final path = ref.comprobantePagoStoragePath?.trim();
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

  /// Línea de referencia para método, archivo y fechas (tras comprobante unificado debería alinearse).
  TransactionRequestModel _comprobanteRefParaAbrir() {
    if (!_usaBundle) return widget.request;
    final withFile = _lines.where((r) => r.hasComprobantePago).toList();
    return withFile.isNotEmpty ? withFile.first : widget.request;
  }

  Future<void> _setEstado(BuildContext context, String estado) async {
    String? nota;
    if (estado == PagoRevisionEstado.rechazado) {
      final ctrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rechazar comprobante'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motivo (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rechazar'),
            ),
          ],
        ),
      );
      nota = ctrl.text.trim();
      ctrl.dispose();
      if (confirmed != true || !context.mounted) return;
    }

    setState(() => _busy = true);
    try {
      final ids = _lines.map((e) => e.id).toList();
      if (_usaBundle) {
        await SupabaseService.importadorSetPagoRevisionEstadoBundle(
          transactionRequestIds: ids,
          nuevoEstado: estado,
          rechazoNota: nota,
        );
      } else {
        await SupabaseService.importadorSetPagoRevisionEstado(
          transactionRequestId: ids.single,
          nuevoEstado: estado,
          rechazoNota: nota,
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            estado == PagoRevisionEstado.aprobado
                ? 'Pago acreditado.'
                : 'Comprobante rechazado.',
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

  static bool _puedeConfirmarPago(TransactionRequestModel r) {
    if (r.status == TransactionRequestStatus.rechazado) return false;

    final pe = r.pagoEstadoRevisionEfectivo;
    if (pe == PagoRevisionEstado.aprobado || pe == PagoRevisionEstado.rechazado) {
      return false;
    }

    final enRevision = pe == PagoRevisionEstado.enRevision;
    final morosoConComprobante = r.status == TransactionRequestStatus.entregado &&
        r.esPedidoMoroso &&
        pe == PagoRevisionEstado.pendiente &&
        (r.hasComprobantePago || r.pagoMetodo?.trim() == PagoMetodo.efectivo);

    if (!enRevision && !morosoConComprobante) return false;
    if (r.hasComprobantePago) return true;
    return r.pagoMetodo?.trim() == PagoMetodo.efectivo;
  }

  static String _labelConfirmarPago(TransactionRequestModel r) {
    if (r.pagoMetodo?.trim() == PagoMetodo.efectivo && !r.hasComprobantePago) {
      return 'Confirmar efectivo recibido';
    }
    return 'Confirmar pago recibido';
  }

  static String _etiquetaEstado(String pe) {
    switch (pe) {
      case PagoRevisionEstado.pendiente:
        return 'Pendiente';
      case PagoRevisionEstado.enRevision:
        return 'Por revisar';
      case PagoRevisionEstado.aprobado:
        return 'Acreditado';
      case PagoRevisionEstado.rechazado:
        return 'Rechazado';
      default:
        return pe;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_usaBundle) {
      return _buildBundle(context);
    }
    return _buildSingle(context);
  }

  Widget _buildBundle(BuildContext context) {
    final ref = _comprobanteRefParaAbrir();

    final pathsDistintos = _lines
        .map((e) => e.comprobantePagoStoragePath?.trim() ?? '')
        .where((p) => p.isNotEmpty)
        .toSet()
        .length;

    final estadosDistintos =
        _lines.map((e) => e.pagoEstadoRevisionEfectivo).toSet();
    final pe = estadosDistintos.length == 1
        ? estadosDistintos.first
        : ref.pagoEstadoRevisionEfectivo;

    final algunoRechazado =
        _lines.any((r) => r.status == TransactionRequestStatus.rechazado);
    final todosConfirmables = _lines.every(_puedeConfirmarPago);
    final mostrarAcciones =
        !algunoRechazado && todosConfirmables && pathsDistintos <= 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comprobante de pago del aliado',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          if (pathsDistintos > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Hay comprobantes distintos entre líneas (datos anteriores). Use «Ver comprobante»; si no coincide, contacte a B2B Conecta.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          if (estadosDistintos.length > 1) ...[
            const SizedBox(height: 4),
            Text(
              'Estado de revisión distinto entre líneas —detalle: '
              '${_lines.map((r) => _etiquetaEstado(r.pagoEstadoRevisionEfectivo)).join(", ")}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.brandBlue,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            ref.pagoMetodo != null && ref.pagoMetodo!.trim().isNotEmpty
                ? 'Método declarado: ${PagoMetodo.labelEs(ref.pagoMetodo!)}'
                : 'Método declarado: —',
            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
          if (ref.comprobantePagoSubmittedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Registrado: ${formatEsShortDateTime(ref.comprobantePagoSubmittedAt)}',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            estadosDistintos.length == 1
                ? 'Estado: ${_etiquetaEstado(pe)}'
                : 'Estado (referencia): ${_etiquetaEstado(pe)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade900,
            ),
          ),
          if (pe == PagoRevisionEstado.rechazado &&
              ref.pagoComprobanteRechazoNota != null &&
              ref.pagoComprobanteRechazoNota!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Motivo del rechazo: ${ref.pagoComprobanteRechazoNota}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade800,
                height: 1.3,
              ),
            ),
          ],
          if (ref.hasComprobantePago) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _abrirComprobante(context),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(pathsDistintos > 1
                  ? 'Ver comprobante (referencia)'
                  : 'Ver comprobante'),
            ),
          ],
          if (mostrarAcciones) ...[
            const SizedBox(height: 10),
            B2bActionButtonRow(
              secondary: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _setEstado(context, PagoRevisionEstado.rechazado),
                child: const Text('Rechazar'),
              ),
              primary: FilledButton(
                onPressed: _busy
                    ? null
                    : () => _setEstado(context, PagoRevisionEstado.aprobado),
                child: Text(_labelConfirmarPago(ref)),
              ),
            ),
          ],
          if (!_lines.any(_puedeConfirmarPago))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                ref.pagoMetodo?.trim() == PagoMetodo.efectivo
                    ? 'El aliado puede declarar pago en efectivo desde su ficha del pedido.'
                    : 'El aliado declara método y comprobante en su ficha del pedido.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingle(BuildContext context) {
    final r = widget.request;
    final pe = r.pagoEstadoRevisionEfectivo;
    final mostrarAcciones = _puedeConfirmarPago(r);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.hideMajorTitle) ...[
            Text(
              'Pago del aliado',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            r.pagoMetodo != null && r.pagoMetodo!.trim().isNotEmpty
                ? 'Método declarado: ${PagoMetodo.labelEs(r.pagoMetodo!)}'
                : 'Método declarado: —',
            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
          if (r.comprobantePagoSubmittedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Registrado: ${formatEsShortDateTime(r.comprobantePagoSubmittedAt)}',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Estado: ${_etiquetaEstado(pe)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey.shade900,
            ),
          ),
          if (pe == PagoRevisionEstado.rechazado &&
              r.pagoComprobanteRechazoNota != null &&
              r.pagoComprobanteRechazoNota!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Motivo del rechazo: ${r.pagoComprobanteRechazoNota}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade800,
                height: 1.3,
              ),
            ),
          ],
          if (r.hasComprobantePago) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _abrirComprobante(context),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('Ver comprobante'),
            ),
          ],
          if (r.esPedidoMoroso &&
              r.status == TransactionRequestStatus.entregado &&
              mostrarAcciones) ...[
            const SizedBox(height: 6),
            Text(
              'El aliado recibió el pedido con pago pendiente. Revise el comprobante y confirme el pago.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppColors.brandBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (mostrarAcciones) ...[
            const SizedBox(height: 10),
            B2bActionButtonRow(
              secondary: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _setEstado(context, PagoRevisionEstado.rechazado),
                child: const Text('Rechazar'),
              ),
              primary: FilledButton(
                onPressed: _busy
                    ? null
                    : () => _setEstado(context, PagoRevisionEstado.aprobado),
                child: Text(_labelConfirmarPago(r)),
              ),
            ),
          ],
          if (!_puedeConfirmarPago(r) &&
              pe != PagoRevisionEstado.aprobado &&
              pe != PagoRevisionEstado.rechazado)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                r.pagoMetodo?.trim() == PagoMetodo.efectivo
                    ? 'El aliado puede declarar pago en efectivo desde su ficha del pedido.'
                    : 'El aliado puede declarar método y adjuntar comprobante desde su ficha del pedido.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
