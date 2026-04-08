import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/aliado_doc_type.dart';
import '../models/kyc_status.dart';
import '../models/profile_document_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Subida de documentos legales/comerciales y envío a revisión MotoLink.
class AliadoKycDocumentsSection extends StatefulWidget {
  const AliadoKycDocumentsSection({
    super.key,
    required this.kycStatus,
    this.onChanged,
  });

  final String? kycStatus;
  final VoidCallback? onChanged;

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
    final canSendReview = st == KycStatus.pendiente || st == KycStatus.rechazado;

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
        const SizedBox(height: 6),
        Text(
          'Estado: ${KycStatus.labelEs(st)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: st == KycStatus.aprobado
                ? AppColors.successGreen
                : AppColors.textSecondary,
          ),
        ),
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
            final has = _docFor(type) != null;
            final busy = _busyDocType == type;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white,
                borderRadius: AppDecorations.radius12,
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppDecorations.radius12,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  title: Text(
                    AliadoDocType.labelEs(type),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    has ? 'Archivo cargado' : 'Sin archivo',
                    style: TextStyle(
                      fontSize: 12,
                      color: has ? AppColors.successGreen : Colors.grey.shade600,
                    ),
                  ),
                  trailing: busy
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: () => _pickAndUpload(type),
                          child: Text(has ? 'Cambiar' : 'Subir'),
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
