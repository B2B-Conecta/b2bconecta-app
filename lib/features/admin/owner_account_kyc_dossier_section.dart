import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_action_rules.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/kyc/aliado_doc_type.dart';
import 'package:motolink_pro_app/features/kyc/document_review_status.dart';
import 'package:motolink_pro_app/features/kyc/kyc_doc_photo_slots.dart';
import 'package:motolink_pro_app/features/kyc/kyc_rejection_note_dialog.dart';
import 'package:motolink_pro_app/features/kyc/profile_document_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Expediente KYC: cada documento admite hasta 3 fotos con lightbox zoom.
class OwnerAccountKycDossierSection extends StatefulWidget {
  const OwnerAccountKycDossierSection({
    super.key,
    required this.profile,
    required this.viewerRole,
    this.onChanged,
  });

  final ProfileModel profile;
  final String? viewerRole;
  final VoidCallback? onChanged;

  @override
  State<OwnerAccountKycDossierSection> createState() =>
      _OwnerAccountKycDossierSectionState();
}

class _OwnerAccountKycDossierSectionState
    extends State<OwnerAccountKycDossierSection> {
  List<ProfileDocumentModel> _docs = const [];
  bool _loading = true;
  String? _busyType;

  bool get _canReview =>
      AdminActionRules.canReviewKyc(viewerRole: widget.viewerRole);

  bool get _isAdminTarget =>
      widget.profile.role?.trim().toLowerCase() == 'administrador';

  /// Solo minoristas (aliado) requieren expediente documental KYC.
  bool get _isMinorista =>
      widget.profile.role?.trim().toLowerCase() == 'aliado';

  @override
  void initState() {
    super.initState();
    if (_isMinorista) _load();
  }

  @override
  void didUpdateWidget(covariant OwnerAccountKycDossierSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.role != widget.profile.role) {
      if (_isMinorista) {
        _load();
      } else if (mounted) {
        setState(() {
          _docs = const [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    if (!_isMinorista) return;
    setState(() => _loading = true);
    try {
      final list = await SupabaseService.fetchProfileDocumentsForProfile(
        widget.profile.id,
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

  Map<String, ProfileDocumentModel> get _byType {
    final map = <String, ProfileDocumentModel>{};
    for (final d in _docs) {
      map[d.docType] = d;
    }
    return map;
  }

  Future<void> _upload(String docType, DocumentPickChannel channel) async {
    final picked = await pickKycDocument(channel: channel);
    if (picked == null || !mounted) return;
    setState(() => _busyType = docType);
    try {
      await SupabaseService.ownerUploadProfileDocument(
        profileId: widget.profile.id,
        docType: docType,
        bytes: picked.bytes,
        fileName: picked.fileName,
        markApproved: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto / archivo adjunto al expediente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo subir: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyType = null);
    }
  }

  Future<void> _review(String docType, String status) async {
    if (!_canReview) return;
    String? note;
    if (status == DocumentReviewStatus.rechazado) {
      note = await promptKycRejectionNote(context);
      if (note == null) return;
    }
    setState(() => _busyType = docType);
    try {
      await SupabaseService.adminSetProfileDocumentReviewStatus(
        profileId: widget.profile.id,
        docType: docType,
        status: status,
        note: note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AliadoDocType.labelEs(docType)}: '
            '${DocumentReviewStatus.labelEs(status)}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyType = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdminTarget || !_isMinorista) return const SizedBox.shrink();

    final byType = _byType;
    final groups = AliadoDocType.docGroupsForAdmin(
      role: widget.profile.role,
      uploadedTypes: byType.keys,
    );

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: AdminUsersChrome.card(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminUsersChrome.sectionHeader(
            title: 'Expediente KYC / Documentos',
            subtitle:
                'Cada documento admite hasta 3 fotos. Toca una miniatura para zoom.',
            glyph: LucideGlyph.clipboardCheck,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            )
          else
            for (final group in groups) ...[
              KycDocPhotoSlots(
                baseType: group,
                docsByType: {
                  for (final slot in AliadoDocType.photoSlotsFor(group))
                    if (byType[slot] != null) slot: byType[slot]!,
                },
                busyType: _busyType,
                canUpload: true,
                canReview: _canReview,
                onUpload: _upload,
                onApprove: (t) => _review(t, DocumentReviewStatus.aprobado),
                onReject: (t) => _review(t, DocumentReviewStatus.rechazado),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
