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
import 'package:motolink_pro_app/features/onboarding/entrepreneur_retailer.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Expediente KYC: cada documento admite hasta 3 fotos con lightbox zoom.
class OwnerAccountKycDossierSection extends StatefulWidget {
  const OwnerAccountKycDossierSection({
    super.key,
    required this.profile,
    required this.viewerRole,
    this.onChanged,
    this.entrepreneurRequirements = false,
  });

  final ProfileModel profile;
  final String? viewerRole;
  final VoidCallback? onChanged;

  /// Escritorio: requeridos vs. complementarios para minorista y emprendedor.
  /// El panel estrecho no lo activa.
  final bool entrepreneurRequirements;

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

    final webLinear = widget.entrepreneurRequirements;
    final entrepreneur = widget.profile.isEntrepreneurRetailer;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: AdminUsersChrome.card(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminUsersChrome.sectionHeader(
            title: webLinear ? 'Documentos' : 'Expediente KYC / Documentos',
            subtitle: webLinear
                ? 'Requeridos para habilitar. La referencia bancaria es complementaria.'
                : 'Cada documento admite hasta 3 fotos. Toca una miniatura para zoom.',
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
          else if (webLinear)
            ..._webGroups(byType, entrepreneur: entrepreneur)
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

  List<Widget> _webGroups(
    Map<String, ProfileDocumentModel> byType, {
    required bool entrepreneur,
  }) {
    final theme = AdminUsersChrome.of(context);
    Widget heading(String title, String hint) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: theme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    Widget slot(
      String base, {
      required String emphasis,
      bool complementary = false,
      String? title,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: KycDocPhotoSlots(
          baseType: base,
          titleOverride: title,
          emphasisLabel: emphasis,
          complementary: complementary,
          docsByType: {
            for (final type in AliadoDocType.photoSlotsFor(base))
              if (byType[type] != null) type: byType[type]!,
          },
          busyType: _busyType,
          canUpload: true,
          canReview: _canReview,
          onUpload: _upload,
          onApprove: (t) => _review(t, DocumentReviewStatus.aprobado),
          onReject: (t) => _review(t, DocumentReviewStatus.rechazado),
        ),
      );
    }

    bool hasFile(String base) =>
        AliadoDocType.photoSlotsFor(base).any(byType.containsKey);

    final cedulaBase = !hasFile(AliadoDocType.cedulaPropietario) &&
            hasFile(AliadoDocType.cedulaRepresentante)
        ? AliadoDocType.cedulaRepresentante
        : AliadoDocType.cedulaPropietario;

    final extras = <String>[
      if (entrepreneur) AliadoDocType.cedulaPropietario,
      if (entrepreneur || cedulaBase != AliadoDocType.cedulaRepresentante)
        AliadoDocType.cedulaRepresentante,
      AliadoDocType.actaConstitutiva,
    ].where(hasFile).toList();

    return [
      heading(
        'Requeridos',
        entrepreneur
            ? 'Registro Mercantil, fotos del local y registro comercial o carta de crédito.'
            : 'Cédula del propietario, registro mercantil, fotos del local y registro comercial o carta de crédito.',
      ),
      if (!entrepreneur)
        slot(
          cedulaBase,
          emphasis: 'Requerido',
          title: cedulaBase == AliadoDocType.cedulaRepresentante
              ? 'Cédula del representante legal'
              : 'Cédula del propietario',
        ),
      slot(
        AliadoDocType.registroMercantil,
        emphasis: 'Requerido',
        title: 'Registro Mercantil',
      ),
      slot(
        AliadoDocType.fotoTienda,
        emphasis: 'Requerido',
        title: 'Fotos del local',
      ),
      slot(
        EntrepreneurDeferredKycDocs.toStorageDocType(
          EntrepreneurDeferredKycDocs.registroComercialCartaCredito,
        ),
        emphasis: 'Requerido',
        title: 'Registro Comercial / Carta de Crédito',
      ),
      const SizedBox(height: 6),
      heading(
        'Complementario',
        'Referencia bancaria 1 y 2. No hace falta para habilitar la cuenta.',
      ),
      for (final type in EntrepreneurDeferredKycDocs.complementary)
        slot(
          type,
          emphasis: 'Complementario',
          complementary: true,
          title: EntrepreneurDeferredKycDocs.labelEs(type),
        ),
      if (extras.isNotEmpty) ...[
        heading(
          'Otros documentos',
          'Archivos que ya estaban en el expediente.',
        ),
        for (final base in extras)
          slot(base, emphasis: 'En expediente', complementary: true),
      ],
    ];
  }
}
