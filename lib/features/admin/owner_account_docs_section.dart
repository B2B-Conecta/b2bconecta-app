import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'package:motolink_pro_app/features/kyc/aliado_doc_type.dart';
import 'package:motolink_pro_app/features/kyc/document_review_status.dart';
import 'package:motolink_pro_app/features/kyc/profile_document_model.dart';
import 'package:motolink_pro_app/features/kyc/profile_kyc_document_tile.dart';

/// Owner: sube documentos KYC en nombre de una tienda minorista.
class OwnerAccountDocsSection extends StatefulWidget {
  const OwnerAccountDocsSection({
    super.key,
    required this.profileId,
    this.markApproved = true,
  });

  final String profileId;
  final bool markApproved;

  @override
  State<OwnerAccountDocsSection> createState() =>
      _OwnerAccountDocsSectionState();
}

class _OwnerAccountDocsSectionState extends State<OwnerAccountDocsSection> {
  List<ProfileDocumentModel> _docs = const [];
  bool _loading = true;
  String? _busyType;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OwnerAccountDocsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await SupabaseService.fetchProfileDocumentsForProfile(
        widget.profileId,
      );
      if (!mounted) return;
      setState(() {
        _docs = list.where((d) => d.isCurrent).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _docs = const [];
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

  Future<void> _pick(String docType, DocumentPickChannel channel) async {
    final picked = await pickKycDocument(channel: channel);
    if (picked == null || !mounted) return;
    setState(() => _busyType = docType);
    try {
      await SupabaseService.ownerUploadProfileDocument(
        profileId: widget.profileId,
        docType: docType,
        bytes: picked.bytes,
        fileName: picked.fileName,
        markApproved: widget.markApproved,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documento cargado en el expediente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo subir: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyType = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = [
      ...AliadoDocType.kycRequiredAliado,
      ...AliadoDocType.kycSupplementaryAliado,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Documentos',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.markApproved
              ? 'Quedan marcados como aprobados en el expediente.'
              : 'Quedan pendientes para la revisión habitual.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
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
        else
          for (final type in types) ...[
            ProfileKycDocumentTile(
              title: AliadoDocType.labelEs(type),
              hasFile: _docFor(type) != null,
              statusLabel: _docFor(type) == null
                  ? 'Sin archivo'
                  : DocumentReviewStatus.labelEs(
                      _docFor(type)!.reviewStatus,
                    ),
              effectiveStatus: _docFor(type)?.reviewStatus,
              busy: _busyType == type,
              onPickCamera: () => _pick(type, DocumentPickChannel.camera),
              onPickGallery: () => _pick(type, DocumentPickChannel.gallery),
              onPickFile: () => _pick(type, DocumentPickChannel.file),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}
