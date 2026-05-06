import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/motolink_ally_invoice_constants.dart';
import '../models/document_type_preference.dart';
import '../models/pago_revision_estado.dart';
import 'admin_pago_revision_section.dart';
import 'efectivo_respaldo_registrar.dart';
import '../models/transaction_request_model.dart';
import '../models/transaction_request_status.dart';
import '../services/motolink_ally_invoice_pdf_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

/// En preparación: factura proveedor, factura MotoLink al aliado, pago y paso a tránsito.
class AdminOrderPreTransitSection extends StatefulWidget {
  const AdminOrderPreTransitSection({
    super.key,
    required this.request,
    required this.onRefresh,
    required this.onMarcarEnTransito,
  });

  final TransactionRequestModel request;
  final VoidCallback onRefresh;
  final VoidCallback onMarcarEnTransito;

  @override
  State<AdminOrderPreTransitSection> createState() =>
      _AdminOrderPreTransitSectionState();
}

class _AdminOrderPreTransitSectionState extends State<AdminOrderPreTransitSection> {
  bool _busyFacturaAliado = false;
  bool _busyGeneratePdf = false;

  Future<void> _openUrl(BuildContext context, Future<String> Function() signed) async {
    try {
      final url = await signed();
      final uri = Uri.parse(url);
      if (!context.mounted) return;
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _pickFacturaAliado(BuildContext context) async {
    final r = widget.request;
    final st = r.status;
    if (st != TransactionRequestStatus.enPreparacion &&
        st != TransactionRequestStatus.pedidoListo) return;

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

    setState(() => _busyFacturaAliado = true);
    try {
      await SupabaseService.adminSubmitFacturaAliadoOrder(
        transactionRequestId: r.id,
        bytes: bytes,
        fileName: name,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Factura oficial al aliado registrada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyFacturaAliado = false);
    }
  }

  Future<String?> _pedirMotivoReemision(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo de reemision'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Indique el motivo (obligatorio).',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    final m = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || !context.mounted) return null;
    if (m.isEmpty) return null;
    return m;
  }

  Future<void> _generateMotoLinkPdf(BuildContext context) async {
    final r = widget.request;
    final hasProv = r.isMasterOrder
        ? (r.subOrders.isNotEmpty &&
            r.subOrders.every(
              (s) =>
                  s.proveedorFacturaStoragePath != null &&
                  s.proveedorFacturaStoragePath!.trim().isNotEmpty,
            ))
        : r.hasProveedorFactura;
    if (!hasProv) return;
    final pref = r.documentTypePreference?.trim();
    if (pref == null || !DocumentTypePreference.values.contains(pref)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El aliado debe haber elegido nota de entrega o factura fiscal al aceptar el pedido.',
          ),
        ),
      );
      return;
    }

    final lines = MotolinkAllyInvoicePdfService.linesFromRequest(r);
    final totalChunks = lines.isEmpty
        ? 1
        : (lines.length / MotolinkAllyInvoiceConstants.maxItemsPerDocument)
            .ceil();
    final existingDone = r.motolinkAllyDocumentEmissions
        .where((e) => e.documentType == pref && e.isFinalized)
        .length;
    final needsResume = existingDone > 0 && existingDone < totalChunks;

    String? motivo;
    if (r.hasFacturaAliado && !needsResume) {
      if (r.hasMultiFragmentMotolinkAllyDocs) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se puede reemitir el PDF en pedidos con varias hojas fiscales.',
              ),
            ),
          );
        }
        return;
      }
      if (r.motolinkAllyInvoicesDescargables.isEmpty && totalChunks > 1) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Este pedido legacy tiene demasiados ítems para reemisión automática; contacte soporte.',
              ),
            ),
          );
        }
        return;
      }
      motivo = await _pedirMotivoReemision(context);
      if (motivo == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La reemisión requiere un motivo.')),
          );
        }
        return;
      }
    }

    setState(() => _busyGeneratePdf = true);
    try {
      await SupabaseService.adminGenerateMotolinkAllyDocumentPdf(
        transactionRequestId: r.id,
        reissueMotivo: motivo,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
                motivo != null
                ? 'Documento re-emitido y registrado.'
                : 'Documento PDF generado y registrado.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onRefresh();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busyGeneratePdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final st = r.status;
    if (st != TransactionRequestStatus.aprobadoAdmin &&
        st != TransactionRequestStatus.enPreparacion &&
        st != TransactionRequestStatus.pedidoListo) {
      return const SizedBox.shrink();
    }

    final pe = r.pagoEstadoRevisionEfectivo;
    final prefDoc = r.documentTypePreference?.trim();
    final linesMoto = MotolinkAllyInvoicePdfService.linesFromRequest(r);
    final motoTotalChunks = linesMoto.isEmpty
        ? 1
        : (linesMoto.length / MotolinkAllyInvoiceConstants.maxItemsPerDocument)
            .ceil();
    final motoExistingDone = prefDoc != null &&
            DocumentTypePreference.values.contains(prefDoc)
        ? r.motolinkAllyDocumentEmissions
            .where((e) => e.documentType == prefDoc && e.isFinalized)
            .length
        : 0;
    final motoNeedsResume =
        motoExistingDone > 0 && motoExistingDone < motoTotalChunks;
    final blockMotoPdfReissue = r.hasFacturaAliado &&
        !motoNeedsResume &&
        (r.hasMultiFragmentMotolinkAllyDocs ||
            (r.motolinkAllyInvoicesDescargables.isEmpty &&
                motoTotalChunks > 1));
    final allSubOrdersListo = r.isMasterOrder &&
        r.subOrders.isNotEmpty &&
        r.subOrders.every((s) => s.status == 'listo');
    final hasProveedorFacturaOperativa = r.isMasterOrder
        ? (r.subOrders.isNotEmpty &&
            r.subOrders.every(
              (s) =>
                  s.proveedorFacturaStoragePath != null &&
                  s.proveedorFacturaStoragePath!.trim().isNotEmpty,
            ))
        : r.hasProveedorFactura;
    final missingSubInvoiceNames = r.isMasterOrder
        ? r.subOrders
            .where(
              (s) =>
                  s.proveedorFacturaStoragePath == null ||
                  s.proveedorFacturaStoragePath!.trim().isEmpty,
            )
            .map((s) => s.importadorBusinessName?.trim())
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];
    final masterReadyToTransit = r.isMasterOrder &&
        hasProveedorFacturaOperativa &&
        allSubOrdersListo;
    final puedeTransito =
        (st == TransactionRequestStatus.pedidoListo || masterReadyToTransit) &&
        hasProveedorFacturaOperativa &&
        r.hasFacturaAliado;

    String? bloqueoTransito;
    if (r.isMasterOrder && !allSubOrdersListo) {
      bloqueoTransito =
          'Todos los sub-pedidos deben estar en «Listo para despacho».';
    } else if (st == TransactionRequestStatus.enPreparacion) {
      bloqueoTransito =
          'El importador debe marcar «Pedido listo» cuando la mercancía esté lista en despacho.';
    } else if (st == TransactionRequestStatus.aprobadoAdmin) {
      bloqueoTransito =
          'Falta que los importadores avancen a preparación/listo para habilitar el tránsito.';
    } else if (!hasProveedorFacturaOperativa) {
      if (r.isMasterOrder && missingSubInvoiceNames.isNotEmpty) {
        final shown = missingSubInvoiceNames.take(2).join(', ');
        final tail = missingSubInvoiceNames.length > 2
            ? ' +${missingSubInvoiceNames.length - 2}'
            : '';
        bloqueoTransito =
            'Falta factura del proveedor en sub-pedidos: $shown$tail.';
      } else {
        bloqueoTransito = 'Falta factura del proveedor (importador).';
      }
    } else if (!r.hasFacturaAliado) {
      bloqueoTransito = 'Adjunte la factura oficial al aliado.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 20),
        const Text(
          'Facturación y pago',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'El aliado solo puede enviar comprobante o declarar pago en la app tras la factura MotoLink al aliado; '
          'puede hacerlo en cualquier fase activa del pedido. En el cronograma de envío no figura como paso del ciclo. '
          'Marcar en tránsito solo cuando el pedido está «listo» y con facturas cargadas; el ETA lo consultan '
          'aliado e importador en el enlace de Google Maps que MotoLink publica en la ficha. El pago puede regularizarse antes o después.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.25),
        ),
        const SizedBox(height: 12),
        if (st == TransactionRequestStatus.enPreparacion) ...[
          Material(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.inventory_2_outlined, color: Colors.amber.shade900),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Espere a que el importador marque «Pedido listo»: confirma que la carga está '
                      'sellada y lista para que MotoLink la retire del almacén.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Factura del proveedor (referencia interna)',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        if (hasProveedorFacturaOperativa)
          (r.isMasterOrder
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: r.subOrders
                      .where((s) {
                        final p = s.proveedorFacturaStoragePath?.trim();
                        return p != null && p.isNotEmpty;
                      })
                      .map(
                        (s) => OutlinedButton.icon(
                          onPressed: () => _openUrl(
                            context,
                            () => SupabaseService.createSignedUrlForOrderInvoice(
                              s.proveedorFacturaStoragePath!.trim(),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: Text(
                            s.importadorBusinessName?.trim().isNotEmpty == true
                                ? 'Factura · ${s.importadorBusinessName}'
                                : 'Factura · Importador',
                          ),
                        ),
                      )
                      .toList(),
                )
              : OutlinedButton.icon(
                  onPressed: () => _openUrl(
                    context,
                    () => SupabaseService.createSignedUrlForOrderInvoice(
                      r.proveedorFacturaStoragePath!.trim(),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(r.proveedorFacturaFileName ?? 'Abrir factura'),
                ))
        else
          Text(
            'Pendiente: el importador debe adjuntar la factura en su pestaña Pedidos.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        const SizedBox(height: 14),
        Text(
          'Factura oficial al aliado',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Referencia fiscal para el aliado; habilita en la app la sección de pago y comprobante.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 6),
        if (hasProveedorFacturaOperativa &&
            r.documentTypePreference != null &&
            DocumentTypePreference.values
                .contains(r.documentTypePreference!.trim())) ...[
          Text(
            'Tipo elegido por el aliado: '
            '${DocumentTypePreference.labelEs(r.documentTypePreference) ?? r.documentTypePreference}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.brandBlue,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: (pe == PagoRevisionEstado.enRevision ||
                      pe == PagoRevisionEstado.aprobado ||
                      _busyGeneratePdf ||
                      _busyFacturaAliado ||
                      blockMotoPdfReissue)
                  ? null
                  : () => _generateMotoLinkPdf(context),
              icon: _busyGeneratePdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 20),
              label: Text(
                motoNeedsResume
                    ? 'Completar PDF MotoLink ($motoExistingDone/$motoTotalChunks)'
                    : r.hasFacturaAliado
                        ? 'Re-emitir PDF MotoLink (con motivo)'
                        : 'Generar PDF MotoLink (plantilla)',
              ),
            ),
          ),
          if (blockMotoPdfReissue) ...[
            const SizedBox(height: 4),
            Text(
              r.hasMultiFragmentMotolinkAllyDocs
                  ? 'La reemisión no aplica a pedidos ya fragmentados en varias hojas.'
                  : 'Reemisión no disponible: pedido con muchos ítems sin emisiones registradas.',
              style: TextStyle(fontSize: 10, color: Colors.orange.shade800),
            ),
          ],
          Text(
            'Usa la tasa BCV del día y los porcentajes IVA/IGTF configurados en administración. '
            'Sustituye adjuntar archivo manual si lo desea.',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600, height: 1.2),
          ),
          const SizedBox(height: 8),
        ],
        if (r.hasFacturaAliado) ...[
          if (r.motolinkAllyInvoicesDescargables.isNotEmpty) ...[
            Text(
              r.motolinkAllyInvoicesDescargables.length > 1
                  ? '${r.motolinkAllyInvoicesDescargables.length} documentos fiscales MotoLink'
                  : (r.facturaAliadoFileName?.trim().isNotEmpty == true
                      ? r.facturaAliadoFileName!.trim()
                      : r.motolinkAllyInvoicesDescargables.single
                          .downloadButtonLabel),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
            if (r.facturaAliadoSubmittedAt != null)
              Text(
                'Última emisión: ${formatEsShortDateTime(r.facturaAliadoSubmittedAt)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in r.motolinkAllyInvoicesDescargables)
                  OutlinedButton.icon(
                    onPressed: e.storagePath == null ||
                            e.storagePath!.trim().isEmpty
                        ? null
                        : () => _openUrl(
                              context,
                              () => SupabaseService.createSignedUrlForFacturaAliado(
                                    e.storagePath!.trim(),
                                  ),
                            ),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(
                      e.downloadButtonLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (!r.hasMultiFragmentMotolinkAllyDocs &&
                    pe != PagoRevisionEstado.aprobado &&
                    pe != PagoRevisionEstado.enRevision)
                  OutlinedButton(
                    onPressed: _busyFacturaAliado
                        ? null
                        : () => _pickFacturaAliado(context),
                    child: _busyFacturaAliado
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reemplazar factura'),
                  ),
              ],
            ),
          ] else if (r.facturaAliadoStoragePath != null &&
              r.facturaAliadoStoragePath!.trim().isNotEmpty) ...[
            Text(
              r.facturaAliadoFileName ?? 'Archivo',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
            Text(
              'Subida: ${formatEsShortDateTime(r.facturaAliadoSubmittedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openUrl(
                    context,
                    () => SupabaseService.createSignedUrlForFacturaAliado(
                      r.facturaAliadoStoragePath!.trim(),
                    ),
                  ),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Abrir / descargar'),
                ),
                if (pe != PagoRevisionEstado.aprobado &&
                    pe != PagoRevisionEstado.enRevision)
                  OutlinedButton(
                    onPressed: _busyFacturaAliado
                        ? null
                        : () => _pickFacturaAliado(context),
                    child: _busyFacturaAliado
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reemplazar factura'),
                  ),
              ],
            ),
          ],
        ] else
          OutlinedButton(
            onPressed: !hasProveedorFacturaOperativa || _busyFacturaAliado
                ? null
                : () => _pickFacturaAliado(context),
            child: _busyFacturaAliado
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Adjuntar factura oficial al aliado'),
          ),
        const SizedBox(height: 14),
        Text(
          'Pago del aliado',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 4),
        if (!r.hasFacturaAliado)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Sin factura MotoLink al aliado: el aliado aún no puede enviar comprobante desde la app.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.25),
            ),
          ),
        if (!r.hasFacturaAliado)
          Text(
            'Estado: ${AdminPagoRevisionSection.estadoPagoLabelEs(r)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brandBlue,
            ),
          ),
        if (r.hasFacturaAliado)
          AdminPagoRevisionSection(
            request: r,
            onRefresh: widget.onRefresh,
            includeSectionTitle: false,
          ),
        EfectivoRespaldoRegistrar(
          request: r,
          onRegistered: widget.onRefresh,
        ),
        const SizedBox(height: 14),
        if (puedeTransito &&
            (r.assignedTransportistaId == null ||
                r.assignedTransportistaId!.trim().isEmpty)) ...[
          Material(
            color: Colors.deepOrange.shade50,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.deepOrange.shade900),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sin transportista asignado: el perfil Despacho no verá este pedido hasta que MotoLink lo asigne '
                      '(sección «Transportista (despacho)» arriba en la ficha).',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepOrange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Envío en tránsito',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 6),
        if (st == TransactionRequestStatus.pedidoListo &&
            puedeTransito)
          FilledButton.icon(
            onPressed: widget.onMarcarEnTransito,
            icon: const Icon(Icons.local_shipping_outlined, size: 18),
            label: const Text('Marcar en tránsito'),
          )
        else
          Text(
            bloqueoTransito ?? 'Complete los pasos anteriores.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.25),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
