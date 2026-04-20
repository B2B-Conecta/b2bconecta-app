import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/aliado_doc_type.dart';
import '../models/cash_phase_policy.dart';
import '../models/document_review_status.dart';
import '../models/kyc_status.dart';
import '../models/profile_document_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'kyc_status_highlight_widgets.dart';

/// Subida de documentos legales/comerciales y envío a revisión MotoLink.
class AliadoKycDocumentsSection extends StatefulWidget {
  const AliadoKycDocumentsSection({
    super.key,
    required this.kycStatus,
    this.onChanged,
    this.esAliadoEnFaseContado = false,
    this.primerosPedidosContadoEntregados,
  });

  final String? kycStatus;
  final VoidCallback? onChanged;

  /// Mientras no se completen las entregas iniciales en contado, no se envía expediente a MotoLink.
  final bool esAliadoEnFaseContado;

  /// Para mensajes X / N en la advertencia.
  final int? primerosPedidosContadoEntregados;

  @override
  State<AliadoKycDocumentsSection> createState() =>
      _AliadoKycDocumentsSectionState();
}

class _AliadoKycDocumentsSectionState extends State<AliadoKycDocumentsSection> {
  List<ProfileDocumentModel> _docs = [];
  bool _loading = true;
  String? _busyDocType;
  bool _submittingReview = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AliadoKycDocumentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kycStatus != widget.kycStatus) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await SupabaseService.fetchMyProfileDocuments();
      if (!mounted) return;
      setState(() {
        _docs = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _docs = [];
        _loading = false;
      });
    }
  }

  ProfileDocumentModel? _docFor(String type) {
    for (final d in _docs) {
      if (d.docType == type) return d;
    }
    return null;
  }

  String _formatReviewedAt(DateTime? utc) {
    if (utc == null) return '';
    final l = utc.toLocal();
    final mm = l.month.toString().padLeft(2, '0');
    final dd = l.day.toString().padLeft(2, '0');
    final hh = l.hour.toString().padLeft(2, '0');
    final min = l.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${l.year} $hh:$min';
  }

  Future<void> _pickAndUpload(String docType) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final bytes = f.bytes;
    final name = f.name;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el archivo.')),
      );
      return;
    }
    setState(() => _busyDocType = docType);
    try {
      await SupabaseService.uploadAliadoProfileDocument(
        docType: docType,
        bytes: bytes,
        fileName: name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documento guardado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyDocType = null);
    }
  }

  Future<void> _submitReview() async {
    if (widget.esAliadoEnFaseContado) {
      final pce = widget.primerosPedidosContadoEntregados ?? 0;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Fase inicial pendiente'),
          content: SingleChildScrollView(
            child: Text(
              'Aún está en la fase de contado (primeros '
              '${CashPhasePolicy.entregasRequeridas} pedidos). '
              'Lleva $pce de ${CashPhasePolicy.entregasRequeridas} entregas registradas.\n\n'
              'Complete esa fase antes de enviar la documentación a revisión MotoLink. '
              'Puede seguir subiendo archivos aquí como borrador; el envío oficial quedará '
              'habilitado al completar los requisitos iniciales.',
              style: const TextStyle(height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _submittingReview = true);
    try {
      await SupabaseService.aliadoSubmitKycForReview();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada. MotoLink revisará su documentación.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.kycStatus?.trim();
    final canSendReview = st == KycStatus.pendiente ||
        st == KycStatus.rechazado ||
        st == KycStatus.enRevision;
    final pce = widget.primerosPedidosContadoEntregados ?? 0;
    final bloqueoFaseInicial = widget.esAliadoEnFaseContado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Documentación para verificación',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        KycAliadoGlobalStatusHighlight(kycStatus: st),
        if (bloqueoFaseInicial) ...[
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Fase inicial: $pce / ${CashPhasePolicy.entregasRequeridas} entregas en contado. '
                      'El botón «Enviar a revisión MotoLink» se habilita al completar esa fase. '
                      'Puede subir archivos mientras tanto.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.grey.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brand,
              ),
            ),
          )
        else
          ...AliadoDocType.all.map((type) {
            final doc = _docFor(type);
            final has = doc != null;
            final rs = doc?.reviewStatus?.trim();
            final busy = _busyDocType == type;
            final statusLine = !has
                ? 'Sin archivo'
                : DocumentReviewStatus.labelEs(
                    (rs == null || rs.isEmpty)
                        ? DocumentReviewStatus.pendiente
                        : rs,
                  );
            final effectiveStatus = !has
                ? null
                : ((rs == null || rs.isEmpty)
                    ? DocumentReviewStatus.pendiente
                    : rs);
            final esAprobado = effectiveStatus == DocumentReviewStatus.aprobado;
            final note = doc?.reviewNote?.trim();
            final reviewer = doc?.reviewerBusinessName?.trim();
            final reviewedHint = (doc != null && doc.reviewedAt != null)
                ? 'Revisión MotoLink: ${_formatReviewedAt(doc.reviewedAt)}'
                    '${reviewer != null && reviewer.isNotEmpty ? ' · $reviewer' : ''}'
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: AppDecorations.radius12,
                  side: BorderSide(
                    color: kycDocumentReviewTileBorderColor(
                      has: has,
                      status: effectiveStatus,
                    ),
                    width: 1.4,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  AliadoDocType.labelEs(type),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                KycDocumentReviewStatusHighlight(
                                  statusLabel: statusLine,
                                  hasFile: has,
                                  effectiveStatus: effectiveStatus,
                                ),
                                if (reviewedHint != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    reviewedHint,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                if (note != null && note.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.orange.shade200,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.feedback_outlined,
                                            size: 18,
                                            color: Colors.orange.shade900,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              note,
                                              style: TextStyle(
                                                fontSize: 12,
                                                height: 1.4,
                                                color: Colors.grey.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (busy)
                            const Padding(
                              padding: EdgeInsets.only(left: 4, top: 4),
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else
                            TextButton(
                              onPressed: () => _pickAndUpload(type),
                              child: Text(
                                !has
                                    ? 'Subir'
                                    : esAprobado
                                        ? 'Actualizar documento'
                                        : 'Cambiar',
                              ),
                            ),
                        ],
                      ),
                      if (has && esAprobado) ...[
                        const SizedBox(height: 6),
                        Text(
                          'La versión aprobada no se borra: se archiva una copia y la nueva '
                          'queda pendiente de revisión MotoLink.',
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.3,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        if (canSendReview) ...[
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submittingReview ? null : _submitReview,
            child: _submittingReview
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Enviar documentación a revisión MotoLink'),
          ),
        ],
      ],
    );
  }
}
