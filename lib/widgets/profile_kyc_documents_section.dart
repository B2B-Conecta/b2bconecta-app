import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/aliado_doc_type.dart';
import '../models/profile_model.dart';
import '../models/document_review_status.dart';
import '../models/kyc_status.dart';
import '../models/profile_document_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'aliado_profile_requirements_banner.dart';
import 'kyc_status_highlight_widgets.dart';
import 'profile_kyc_document_tile.dart';

/// Subida de documentos KYC y envío a revisión MotoLink (solo aliados).
class ProfileKycDocumentsSection extends StatefulWidget {
  const ProfileKycDocumentsSection({
    super.key,
    required this.kycStatus,
    required this.role,
    this.profile,
    this.onChanged,
  });

  final String? kycStatus;
  final String role;
  final ProfileModel? profile;
  final VoidCallback? onChanged;

  bool get _isAliado => role.trim().toLowerCase() == 'aliado';

  @override
  State<ProfileKycDocumentsSection> createState() =>
      _ProfileKycDocumentsSectionState();
}

class _ProfileKycDocumentsSectionState extends State<ProfileKycDocumentsSection> {
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
  void didUpdateWidget(covariant ProfileKycDocumentsSection oldWidget) {
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

  ProfileDocumentModel? _cedulaAliadoDoc() {
    for (final d in _docs) {
      if (AliadoDocType.isCedulaAliadoDoc(d.docType)) return d;
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
      await SupabaseService.uploadMyProfileDocument(
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
    setState(() => _submittingReview = true);
    try {
      await SupabaseService.profileSubmitKycForReview();
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

  Widget _buildDocTile(String type) {
    final doc = type == AliadoDocType.cedulaPropietario && widget._isAliado
        ? _cedulaAliadoDoc()
        : _docFor(type);
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
    final reviewer = doc?.reviewerBusinessName?.trim();
    final reviewedHint = (doc != null && doc.reviewedAt != null)
        ? 'Revisión: ${_formatReviewedAt(doc.reviewedAt)}'
            '${reviewer != null && reviewer.isNotEmpty ? ' · $reviewer' : ''}'
        : null;
    final note = doc?.reviewNote?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ProfileKycDocumentTile(
        title: AliadoDocType.labelEs(type),
        hasFile: has,
        statusLabel: statusLine,
        effectiveStatus: effectiveStatus,
        busy: busy,
        reviewedHint: reviewedHint,
        reviewNote: note,
        onUpload: () => _pickAndUpload(type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.kycStatus?.trim();
    final canSendReview = st == KycStatus.pendiente ||
        st == KycStatus.rechazado ||
        st == KycStatus.enRevision;
    final requiredTypes = AliadoDocType.forRole(widget.role);
    final supplementaryTypes = widget._isAliado
        ? AliadoDocType.supplementaryForRole(widget.role)
        : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget._isAliado)
          Text(
            'Documentación (${widget.role})',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        if (widget._isAliado &&
            widget.profile?.pedidosSuspendidosMorosidad == true) ...[
          Material(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.block, color: Colors.red.shade800, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MotoLink suspendió nuevos pedidos por morosidad. Regularice pagos en pedidos entregados.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (!widget._isAliado) const SizedBox(height: 8),
        KycAliadoGlobalStatusHighlight(kycStatus: st),
        if (widget._isAliado && widget.profile != null) ...[
          const SizedBox(height: 8),
          AliadoProfileRequirementsBanner(
            profile: widget.profile,
            documents: _docs,
          ),
        ],
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.brand,
                ),
              ),
            ),
          )
        else ...[
          if (widget._isAliado) ...[
            const Text(
              'Registro inicial',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
          ],
          ...requiredTypes.map(_buildDocTile),
          if (supplementaryTypes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Documentación complementaria',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Opcional. Puede completarla después de ingresar a la plataforma.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            ...supplementaryTypes.map(_buildDocTile),
          ],
        ],
        if (canSendReview) ...[
          const SizedBox(height: 6),
          FilledButton(
            onPressed: _submittingReview ? null : _submitReview,
            child: _submittingReview
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget._isAliado
                        ? 'Enviar registro inicial a revisión'
                        : 'Enviar a revisión MotoLink',
                  ),
          ),
        ],
      ],
    );
  }
}
