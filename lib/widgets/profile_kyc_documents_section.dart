import 'package:flutter/material.dart';

import '../models/account_access_status.dart';
import '../models/aliado_doc_type.dart';
import '../models/profile_model.dart';
import '../models/document_review_status.dart';
import '../models/kyc_status.dart';
import '../models/profile_document_model.dart';
import '../services/supabase_service.dart';
import '../utils/document_pick_utils.dart';
import '../theme/app_theme.dart';
import 'aliado_profile_requirements_banner.dart';
import 'kyc_status_highlight_widgets.dart';
import 'profile_kyc_document_tile.dart';
import 'profile_section_helpers.dart';
import 'terms_acceptance_section.dart';

/// Ayudas (icono ℹ️) en verificación KYC del aliado.
abstract final class AliadoKycSectionHelp {
  static const verificacion =
      'B2B Conecta revisa su documentación para habilitar el uso completo de la '
      'plataforma. Complete los requisitos del perfil y suba los archivos iniciales.';
  static const requisitosPerfil =
      'Datos fiscales del formulario y documentos mínimos. Deben estar listos '
      'antes de enviar el registro inicial a revisión.';
  static const registroInicial =
      'Documentos obligatorios para el primer ingreso: foto del local, cédula '
      'del propietario y registro mercantil o cámara de comercio. Puede tomar '
      'una foto con la cámara o subir un archivo (PDF o imagen).';
  static const documentacionComplementaria =
      'Opcional. Referencias bancarias y comerciales para fortalecer su perfil; '
      'puede completarlas después de ingresar a la plataforma.';
  static const morosidad =
      'B2B Conecta suspendió nuevos pedidos por morosidad. Regularice pagos en '
      'pedidos entregados.';
}

/// Subida de documentos KYC y envío a revisión B2B Conecta (solo aliados).
class ProfileKycDocumentsSection extends StatefulWidget {
  const ProfileKycDocumentsSection({
    super.key,
    required this.kycStatus,
    required this.role,
    this.profile,
    this.onChanged,
    this.beforeUpload,
    this.beforeSubmitReview,
    this.registrationLocked = false,
    this.onTermsAccepted,
  });

  final String? kycStatus;
  final String role;
  final ProfileModel? profile;
  final VoidCallback? onChanged;

  /// Guarda borrador del perfil si hace falta antes de subir (onboarding aliado).
  final Future<bool> Function()? beforeUpload;

  /// Persiste datos del formulario antes de enviar registro inicial.
  final Future<bool> Function()? beforeSubmitReview;

  /// Tras enviar a revisión: ocultar envío y mostrar solo estado.
  final bool registrationLocked;

  /// Tras registrar aceptación legal en BD (p. ej. reevaluar gate de onboarding).
  final VoidCallback? onTermsAccepted;

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
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _termsAccepted = widget.profile?.hasAcceptedCurrentTerms ?? false;
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileKycDocumentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kycStatus != widget.kycStatus ||
        oldWidget.profile?.id != widget.profile?.id ||
        oldWidget.profile?.termsAcceptedAt != widget.profile?.termsAcceptedAt ||
        oldWidget.profile?.termsVersion != widget.profile?.termsVersion) {
      if (widget.profile?.hasAcceptedCurrentTerms == true) {
        _termsAccepted = true;
      }
      if (oldWidget.kycStatus != widget.kycStatus ||
          oldWidget.profile?.id != widget.profile?.id) {
        _load();
      }
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
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

  bool get _hasPersistedProfile => widget.profile?.id.isNotEmpty == true;

  Future<void> _guardUpload(Future<void> Function() action) async {
    if (widget.beforeUpload != null) {
      final ok = await widget.beforeUpload!();
      if (!ok) return;
    } else if (!_hasPersistedProfile) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Guarde el perfil antes de subir documentos.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await action();
  }

  Future<void> _pickAndUpload(
    String docType, {
    DocumentPickChannel channel = DocumentPickChannel.file,
  }) async {
    final picked = await pickKycDocument(channel: channel);
    if (picked == null || !mounted) return;

    setState(() => _busyDocType = docType);
    try {
      await SupabaseService.uploadMyProfileDocument(
        docType: docType,
        bytes: picked.bytes,
        fileName: picked.fileName,
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

  int _supplementaryUploaded(List<String> types) {
    var n = 0;
    for (final t in types) {
      if (_docFor(t) != null) n++;
    }
    return n;
  }

  Future<void> _submitReview() async {
    if (widget.beforeSubmitReview != null) {
      final saved = await widget.beforeSubmitReview!();
      if (!saved || !mounted) return;
    }
    setState(() => _submittingReview = true);
    try {
      await SupabaseService.profileSubmitKycForReview();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solicitud enviada. B2B Conecta revisará su registro y le avisará en la app.',
          ),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: ProfileKycDocumentTile(
        title: AliadoDocType.labelEs(type),
        hasFile: has,
        statusLabel: statusLine,
        effectiveStatus: effectiveStatus,
        busy: busy,
        reviewedHint: reviewedHint,
        reviewNote: note,
        onPickCamera: () => _guardUpload(
          () => _pickAndUpload(type, channel: DocumentPickChannel.camera),
        ),
        onPickGallery: () => _guardUpload(
          () => _pickAndUpload(type, channel: DocumentPickChannel.gallery),
        ),
        onPickFile: () => _guardUpload(
          () => _pickAndUpload(type, channel: DocumentPickChannel.file),
        ),
        actionsEnabled: widget.beforeUpload != null || _hasPersistedProfile,
      ),
    );
  }

  int _requiredDocsUploaded(List<String> types) {
    var n = 0;
    for (final t in types) {
      if (t == AliadoDocType.cedulaPropietario && widget._isAliado) {
        if (_cedulaAliadoDoc() != null) n++;
      } else if (_docFor(t) != null) {
        n++;
      }
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.kycStatus?.trim();
    final access = widget.profile?.accountAccessStatus?.trim();
    final accountAllowsSubmit = access == null ||
        access.isEmpty ||
        access == AccountAccessStatus.draft ||
        access == AccountAccessStatus.rejected;
    final canSendReview = widget._isAliado &&
        !widget.registrationLocked &&
        accountAllowsSubmit &&
        (st == null ||
            st.isEmpty ||
            st == KycStatus.pendiente ||
            st == KycStatus.rechazado);
    final termsOk = _termsAccepted;
    final requiredTypes = AliadoDocType.forRole(widget.role);
    final supplementaryTypes = widget._isAliado
        ? AliadoDocType.supplementaryForRole(widget.role)
        : const <String>[];
    final reqProgress = widget._isAliado && widget.profile != null
        ? AliadoProfileRequirementsProgress.compute(
            profile: widget.profile,
            documents: _docs,
          )
        : null;
    final requiredUploaded = _requiredDocsUploaded(requiredTypes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget._isAliado)
          Text(
            'Documentación (${widget.role})',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        if (widget._isAliado &&
            !_hasPersistedProfile &&
            widget.beforeUpload != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.brandBlueContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.brandAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Indique nombre del negocio y RIF. Al adjuntar un documento '
                    'guardamos esos datos automáticamente si aún no pulsó '
                    '«Guardar Perfil».',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (widget._isAliado &&
            widget.profile?.pedidosSuspendidosMorosidad == true) ...[
          Row(
            children: [
              Chip(
                avatar: Icon(Icons.block, size: 14, color: Colors.red.shade800),
                label: Text(
                  'Pedidos suspendidos (morosidad)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade800,
                  ),
                ),
                backgroundColor: Colors.red.shade50,
                side: BorderSide(color: Colors.red.shade200),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const ProfileInfoIcon(
                title: 'Morosidad',
                message: AliadoKycSectionHelp.morosidad,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (!widget._isAliado) const SizedBox(height: 8),
        KycAliadoGlobalStatusHighlight(kycStatus: st),
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
        else if (widget._isAliado) ...[
          if (reqProgress != null) ...[
            const SizedBox(height: 8),
            ProfileCollapsibleSection(
              title: 'Requisitos del perfil',
              subtitle: reqProgress.subtitle,
              infoMessage: AliadoKycSectionHelp.requisitosPerfil,
              initiallyExpanded: !reqProgress.allComplete,
              child: AliadoProfileRequirementsBanner(
                profile: widget.profile,
                documents: _docs,
                compact: true,
              ),
            ),
          ],
          const SizedBox(height: 8),
          ProfileCollapsibleSection(
            title: 'Registro inicial',
            subtitle: requiredTypes.isEmpty
                ? null
                : '$requiredUploaded de ${requiredTypes.length} documentos',
            infoMessage: AliadoKycSectionHelp.registroInicial,
            initiallyExpanded:
                requiredUploaded < requiredTypes.length || st == KycStatus.rechazado,
            child: Column(
              children: requiredTypes.map(_buildDocTile).toList(),
            ),
          ),
          if (supplementaryTypes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ProfileCollapsibleSection(
              title: 'Documentación complementaria',
              subtitle: 'Opcional · ${_supplementaryUploaded(supplementaryTypes)} de ${supplementaryTypes.length}',
              infoMessage: AliadoKycSectionHelp.documentacionComplementaria,
              initiallyExpanded: false,
              child: Column(
                children: supplementaryTypes.map(_buildDocTile).toList(),
              ),
            ),
          ],
        ] else ...[
          const SizedBox(height: 10),
          ...requiredTypes.map(_buildDocTile),
        ],
        if (widget._isAliado &&
            !(widget.profile?.hasAcceptedCurrentTerms ?? false)) ...[
          const SizedBox(height: 12),
          const ProfileSectionHeader(
            label: 'TÉRMINOS LEGALES',
            infoTitle: 'Términos y privacidad',
            infoMessage:
                'Debe aceptar los términos y la política de privacidad vigentes '
                'antes de enviar el registro inicial a revisión.',
          ),
          TermsAcceptanceSection(
            accepted: _termsAccepted,
            onAcceptedChanged: (v) {
              setState(() => _termsAccepted = v);
              if (v) widget.onTermsAccepted?.call();
            },
          ),
        ],
        if (canSendReview) ...[
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _submittingReview || (widget._isAliado && !termsOk)
                ? null
                : _submitReview,
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
                        : 'Enviar a revisión B2B Conecta',
                  ),
          ),
        ],
      ],
    );
  }
}
