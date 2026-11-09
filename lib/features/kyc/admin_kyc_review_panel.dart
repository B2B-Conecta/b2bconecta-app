import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_access_status.dart';
import 'aliado_doc_type.dart';
import 'document_review_status.dart';
import 'kyc_status.dart';
import 'profile_document_model.dart';
import 'profile_kyc_document_tile.dart';
import 'package:motolink_pro_app/features/admin/admin_action_rules.dart';
import 'package:motolink_pro_app/features/admin/owner_account_dossier.dart';
import 'package:motolink_pro_app/features/admin/owner_account_dossier_form.dart';
import 'package:motolink_pro_app/features/admin/owner_account_rules.dart';
import 'package:motolink_pro_app/features/admin/owner_importer_catalog_screen.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'package:motolink_pro_app/core/widgets/admin_list_skeleton.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/features/admin/admin_users_filter_bar.dart';
import 'package:motolink_pro_app/features/admin/admin_users_filter_models.dart';
import 'package:motolink_pro_app/features/admin/owner_account_search.dart';

/// Admin: cola de verificación (aliados KYC + mayoristas / importadores).
class AdminKycReviewPanel extends StatefulWidget {
  const AdminKycReviewPanel({
    super.key,
    required this.viewerRole,
    this.viewerId = '',
    this.viewerIsOwner = false,
    this.embeddedInHub = false,
  });

  /// Rol de la sesión: decide si se muestran aprobar/rechazar.
  final String? viewerRole;

  /// Id del admin en sesión (cambio de rol / alcance).
  final String viewerId;

  /// El owner gestiona rol y correos de Auth.
  final bool viewerIsOwner;

  /// Embebido en [AdminUsersHubPanel]: omite padding duplicado del hub.
  final bool embeddedInHub;

  @override
  State<AdminKycReviewPanel> createState() => _AdminKycReviewPanelState();
}

class _AdminKycReviewPanelState extends State<AdminKycReviewPanel> {
  List<ProfileModel> _profiles = [];
  final Map<String, List<ProfileDocumentModel>> _docsByProfile = {};
  bool _loading = true;
  String? _error;
  String? _expandedProfileId;
  String? _busyProfileId;
  String? _busyDocKey;
  AdminUserEstadoFilter _estado = AdminUserEstadoFilter.todos;
  AdminUserRolFilter _rol = AdminUserRolFilter.todos;
  OwnerAccountSort _sort = OwnerAccountSort.newest;
  final _searchCtrl = TextEditingController();
  final _listScroll = ScrollController();
  int _pageIndex = 0;
  int _pageSize = listPageSizeOptions.first;

  bool get _canReviewKyc =>
      AdminActionRules.canReviewKyc(viewerRole: widget.viewerRole);

  bool get _canSetAccess =>
      AdminActionRules.canSetAccountAccess(viewerRole: widget.viewerRole);

  @override
  void initState() {
    super.initState();
    MainShellTabController.registerAdminKycNotificationDeepLink(
      _onKycNotificationDeepLink,
    );
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerAdminKycNotificationDeepLink(null);
    _searchCtrl.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  void _onKycNotificationDeepLink() {
    final pending = MainShellTabController.peekPendingKycProfileId();
    if (pending == null) return;
    if (_profiles.any((p) => p.id == pending)) {
      MainShellTabController.consumePendingKycProfileId();
      setState(() => _expandedProfileId = pending);
      _ensureDocsLoaded(pending);
    } else if (!_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var rows = await SupabaseService.fetchB2BProfilesForAdminKycReview();
      try {
        final emails = await SupabaseService.ownerAuthEmailsByProfileId();
        rows = rows.map((p) => p.withAuthEmail(emails[p.id])).toList();
      } catch (_) {
        // La cola sigue útil sin correo si el RPC no está disponible.
      }
      if (!mounted) return;
      final expanded = _expandedProfileId;
      setState(() {
        _profiles = rows;
        _loading = false;
        _docsByProfile.clear();
      });
      if (expanded != null) await _reloadDocs(expanded);
      _onKycNotificationDeepLink();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _ensureDocsLoaded(String profileId) => _reloadDocs(profileId);

  /// Siempre vuelve a leer el servidor. Si no, un documento que ya estaba
  /// aprobado sigue ocultando Aprobar después de un rechazo y un reenvío.
  Future<void> _reloadDocs(String profileId) async {
    try {
      final docs =
          await SupabaseService.fetchProfileDocumentsForProfile(profileId);
      if (!mounted) return;
      setState(() => _docsByProfile[profileId] = docs);
    } catch (_) {
      if (!mounted) return;
      if (!_docsByProfile.containsKey(profileId)) {
        setState(() => _docsByProfile[profileId] = []);
      }
    }
  }

  bool _profileNeedsAttention(ProfileModel p) {
    final access = p.accountAccessStatus?.trim();
    if (access == AccountAccessStatus.draft ||
        access == AccountAccessStatus.pendingReview) {
      return true;
    }
    final ks = p.kycStatus?.trim();
    if (ks == KycStatus.enRevision ||
        ks == KycStatus.pendiente ||
        ks == KycStatus.rechazado) {
      return true;
    }
    final docs = _docsByProfile[p.id];
    if (docs == null) return false;
    return docs.any((d) {
      if (!d.isCurrent) return false;
      final st = d.reviewStatus?.trim();
      return st == DocumentReviewStatus.pendiente ||
          st == DocumentReviewStatus.enRevision;
    });
  }

  bool _isImportador(ProfileModel p) =>
      p.role?.trim().toLowerCase() == 'importador';

  bool _isAliado(ProfileModel p) => p.role?.trim().toLowerCase() == 'aliado';

  bool _matchesEstado(ProfileModel p) {
    final access = p.accountAccessStatus?.trim();
    final ks = p.kycStatus?.trim();
    switch (_estado) {
      case AdminUserEstadoFilter.todos:
        return true;
      case AdminUserEstadoFilter.pendiente:
        return access == AccountAccessStatus.pendingReview ||
            access == AccountAccessStatus.draft ||
            ks == KycStatus.enRevision ||
            ks == KycStatus.pendiente ||
            _profileNeedsAttention(p);
      case AdminUserEstadoFilter.verificado:
        return !p.isDeactivated &&
            (ks == KycStatus.aprobado ||
                (_isImportador(p) && access == AccountAccessStatus.active));
      case AdminUserEstadoFilter.activo:
        return access == AccountAccessStatus.active && !p.isDeactivated;
      case AdminUserEstadoFilter.bloqueado:
        return p.isDeactivated ||
            access == AccountAccessStatus.rejected ||
            ks == KycStatus.rechazado;
    }
  }

  List<ProfileModel> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    final rows = _profiles.where((p) {
      final role = p.role?.trim().toLowerCase();
      if (role != 'aliado' && role != 'importador') return false;
      switch (_rol) {
        case AdminUserRolFilter.minorista:
          if (role != 'aliado') return false;
        case AdminUserRolFilter.mayorista:
          if (role != 'importador') return false;
        case AdminUserRolFilter.administracion:
          return false;
        case AdminUserRolFilter.todos:
          break;
      }
      if (q.isNotEmpty && !ownerAccountMatchesQuery(p, q)) return false;
      if (_matchesEstado(p)) return true;
      return p.id == _expandedProfileId;
    });
    return sortOwnerAccounts(rows, sort: _sort);
  }

  Future<void> _openDocument(ProfileDocumentModel doc) async {
    try {
      final url = await SupabaseService.createSignedUrlForProfileDocument(
        doc.storagePath,
      );
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('No se pudo abrir el archivo.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir: $e')),
      );
    }
  }

  Future<void> _uploadDoc({
    required ProfileModel profile,
    required String docType,
    required DocumentPickChannel channel,
  }) async {
    final picked = await pickKycDocument(channel: channel);
    if (picked == null || !mounted) return;
    final key = '${profile.id}:$docType';
    setState(() => _busyDocKey = key);
    try {
      await SupabaseService.ownerUploadProfileDocument(
        profileId: profile.id,
        docType: docType,
        bytes: picked.bytes,
        fileName: picked.fileName,
        markApproved: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documento cargado. Puede aprobarlo o rechazarlo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _reloadDocs(profile.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo subir: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyDocKey = null);
    }
  }

  Future<void> _reviewDoc({
    required ProfileModel profile,
    required String docType,
    required String status,
  }) async {
    if (!_canReviewKyc) return;
    String? note;
    if (status == DocumentReviewStatus.rechazado) {
      note = await _promptRejectionNote();
      if (note == null) return;
    }
    final key = '${profile.id}:$docType';
    setState(() => _busyDocKey = key);
    try {
      await SupabaseService.adminSetProfileDocumentReviewStatus(
        profileId: profile.id,
        docType: docType,
        status: status,
        note: note,
      );
      if (!mounted) return;
      await _ensureDocsLoaded(profile.id);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AliadoDocType.labelEs(docType)}: ${DocumentReviewStatus.labelEs(status)}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyDocKey = null);
    }
  }

  Future<String?> _promptRejectionNote() async {
    final ctrl = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo del rechazo'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Indique qué debe corregir el usuario…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (res == null || res.length < 3) return null;
    return res;
  }

  Future<void> _setGlobalKyc(ProfileModel profile, String status) async {
    if (!_canReviewKyc || !_canSetAccess) return;
    String? note;
    if (status == KycStatus.rechazado) {
      note = await _promptRejectionNote();
      if (note == null) return;
    }
    setState(() => _busyProfileId = profile.id);
    try {
      await SupabaseService.adminSetProfileKycStatus(
        profileId: profile.id,
        status: status,
        note: note,
      );
      if (!mounted) return;
      final accessLabel = status == KycStatus.aprobado
          ? 'Acceso habilitado. La tienda minorista recibirá una notificación en la app.'
          : 'KYC global: ${KycStatus.labelEs(status)}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accessLabel),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<void> _setImportadorAccess(
    ProfileModel profile,
    String status,
  ) async {
    if (!_canSetAccess) return;
    String? note;
    if (status == KycStatus.rechazado) {
      note = await _promptRejectionNote();
      if (note == null) return;
    }
    setState(() => _busyProfileId = profile.id);
    try {
      await SupabaseService.adminSetImportadorAccountAccess(
        profileId: profile.id,
        status: status,
        note: note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == KycStatus.aprobado
                ? 'Mayorista aprobado. Recibirá una notificación en la app.'
                : 'Solicitud de mayorista rechazada.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Future<void> _pickGlobalStatus(ProfileModel profile) async {
    if (!_canReviewKyc) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Estado KYC global',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            for (final st in [
              KycStatus.enRevision,
              KycStatus.aprobado,
              KycStatus.rechazado,
              KycStatus.pendiente,
            ])
              ListTile(
                title: Text(KycStatus.labelEs(st)),
                onTap: () => Navigator.of(ctx).pop(st),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await _setGlobalKyc(profile, picked);
  }

  void _selectProfile(ProfileModel p) {
    setState(() => _expandedProfileId = p.id);
    if (_isAliado(p)) _ensureDocsLoaded(p.id);
  }

  Map<String, ProfileDocumentModel> _currentDocsByType(ProfileModel p) {
    final docs = _docsByProfile[p.id] ?? [];
    final currentByType = <String, ProfileDocumentModel>{};
    for (final d in docs) {
      if (!d.isCurrent) continue;
      final prev = currentByType[d.docType];
      if (prev == null ||
          (d.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).isAfter(
            prev.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          )) {
        currentByType[d.docType] = d;
      }
    }
    return currentByType;
  }

  Future<void> _openMobileDetail(ProfileModel p) async {
    _selectProfile(p);
    if (!mounted) return;
    await showAdaptiveAdminSheet<void>(
      context: context,
      draggable: true,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (ctx, scroll) {
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              p.businessName?.trim().isNotEmpty == true
                  ? p.businessName!.trim()
                  : 'Sin nombre',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailBody(
              p,
              afterTerms: _profileOptionActions(
                p,
                buttonHeight: 48,
                onEditFiscal: () async {
                  Navigator.of(ctx).pop();
                  await _openDossier(p);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  bool _canChangeRole(ProfileModel p) => OwnerAccountRules.canChangeB2bRole(
        viewerIsOwner: widget.viewerIsOwner,
        viewerRole: widget.viewerRole,
        viewerId: widget.viewerId,
        targetId: p.id,
        targetIsOwner: p.isOwner,
        targetRole: p.role,
      );

  Future<void> _openDossier(ProfileModel p) async {
    final changed = await OwnerAccountDossierForm.open(
      context,
      existing: p,
      allowAdminRole: widget.viewerIsOwner,
      canDeleteAccount: _canSetAccess,
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _changeRole(ProfileModel p) async {
    // Solo B2B aquí: corregir registro equivocado. Admin→admin es otra acción.
    const roles = <String>['aliado', 'importador'];
    final current = p.role?.trim().toLowerCase();
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Corregir rol de la cuenta'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Si se registró como mayorista por error (o al revés), '
                'elija el rol correcto. No borra el expediente ni el correo.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              for (final role in roles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ProfileRoleLabels.labelEs(role)),
                  subtitle: Text(
                    role == 'aliado'
                        ? 'Tienda minorista'
                        : 'Importador / mayorista',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  selected: current == role,
                  trailing: current == role
                      ? Icon(Icons.check, color: AppColors.brand)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(role),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (picked == null || picked == p.role?.trim().toLowerCase()) return;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar cambio de rol'),
        content: Text(
          '¿Asignar «${ProfileRoleLabels.labelEs(picked)}» a '
          '${p.businessName ?? p.email ?? 'esta cuenta'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyProfileId = p.id);
    try {
      await SupabaseService.ownerSetProfileRole(
        profileId: p.id,
        role: picked,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Rol actualizado a ${ProfileRoleLabels.labelEs(picked)}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
      if (mounted) setState(() => _expandedProfileId = p.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cambiar el rol: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyProfileId = null);
    }
  }

  Widget _referralAttributionBox(ProfileModel p) {
    if (!p.hasReferralAttribution) {
      return const SizedBox.shrink();
    }
    final name = p.referredByExternalName?.trim();
    final code = p.referredByExternalCode?.trim();
    final phone = p.referredByExternalPhone?.trim();
    final email = p.referredByExternalEmail?.trim();
    final detailLines = <String>[
      if (name != null && name.isNotEmpty) 'Vendedor: $name',
      if (code != null && code.isNotEmpty) 'Código: $code',
      if (phone != null && phone.isNotEmpty) 'Tel: $phone',
      if (email != null && email.isNotEmpty) 'Email: $email',
      if (p.referredAt != null)
        'Registrado: ${p.referredAt!.toLocal().toString().split('.').first}',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(8),
          color: AppColors.brandBlueContainer,
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Llegó por referido',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              if (detailLines.isEmpty)
                Text(
                  'Cuenta atribuida a un vendedor externo.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                )
              else
                for (final line in detailLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _profileOptionActions(
    ProfileModel p, {
    required double buttonHeight,
    required VoidCallback onEditFiscal,
  }) {
    return [
      const SizedBox(height: 12),
      Text(
        'Acciones',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 8),
      if (_canChangeRole(p)) ...[
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(buttonHeight),
          ),
          onPressed: _busyProfileId == p.id ? null : () => _changeRole(p),
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: const Text('Corregir rol (minorista / mayorista)'),
        ),
        const SizedBox(height: 8),
      ],
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(buttonHeight),
        ),
        onPressed: onEditFiscal,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('Editar expediente'),
      ),
    ];
  }

  Widget _importadorProfileSummary(ProfileModel p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _referralAttributionBox(p),
        OwnerAccountDossier(
          profile: p,
          title: 'Perfil del mayorista',
          showAuthEmail: true,
        ),
      ],
    );
  }

  Widget _buildDetailBody(
    ProfileModel p, {
    List<Widget> afterTerms = const [],
  }) {
    final role = p.role?.trim() ?? '';
    final currentByType = _currentDocsByType(p);
    if (_isImportador(p)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _importadorProfileSummary(p),
          ...afterTerms,
          if (widget.viewerIsOwner) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: () => OwnerImporterCatalogScreen.open(
                context,
                importerId: p.id,
                importerName: p.businessName?.trim().isNotEmpty == true
                    ? p.businessName!.trim()
                    : (p.email ?? 'Mayorista'),
              ),
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text('Ver catálogo'),
            ),
          ],
          if (_canSetAccess) ...[
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              onPressed: p.hasActiveAccountAccess || _busyProfileId == p.id
                  ? null
                  : () => _setImportadorAccess(p, KycStatus.aprobado),
              child: Text(
                p.hasActiveAccountAccess
                    ? 'Acceso habilitado'
                    : 'Aprobar mayorista',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: Colors.red.shade800,
              ),
              onPressed: _busyProfileId == p.id
                  ? null
                  : () => _setImportadorAccess(p, KycStatus.rechazado),
              child: const Text('Rechazar'),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _referralAttributionBox(p),
        OwnerAccountDossier(
          profile: p,
          title: 'Datos de la tienda',
          showAuthEmail: true,
        ),
        ...afterTerms,
        if (_canReviewKyc) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed:
                _busyProfileId == p.id ? null : () => _pickGlobalStatus(p),
            child: const Text('Cambiar KYC global'),
          ),
        ],
        if (_canSetAccess) ...[
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: p.hasActiveAccountAccess || _busyProfileId == p.id
                ? null
                : () => _setGlobalKyc(p, KycStatus.aprobado),
            child: Text(
              p.hasActiveAccountAccess
                  ? 'Acceso habilitado'
                  : 'Habilitar acceso',
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Documentos',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Aquí puede ver, adjuntar, aprobar o rechazar cada documento.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        ...AliadoDocType.forAdminReview(
          role: role,
          uploadedTypes: currentByType.keys,
        ).map((type) {
          final doc = currentByType[type];
          final has = doc != null;
          final st = doc?.reviewStatus?.trim();
          final busy = _busyDocKey == '${p.id}:$type';
          final canApprove =
              _canReviewKyc && has && st != DocumentReviewStatus.aprobado;
          final canReject =
              _canReviewKyc && has && st != DocumentReviewStatus.rechazado;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileKycDocumentTile(
                  title: AliadoDocType.labelEs(type),
                  hasFile: has,
                  statusLabel: has
                      ? DocumentReviewStatus.labelEs(
                          st ?? DocumentReviewStatus.pendiente,
                        )
                      : 'Sin archivo',
                  effectiveStatus: st,
                  busy: busy,
                  compactActions: true,
                  showPickActions: true,
                  reviewNote: doc?.reviewNote,
                  onView: has ? () => _openDocument(doc) : null,
                  onPickCamera: () => _uploadDoc(
                    profile: p,
                    docType: type,
                    channel: DocumentPickChannel.camera,
                  ),
                  onPickGallery: () => _uploadDoc(
                    profile: p,
                    docType: type,
                    channel: DocumentPickChannel.gallery,
                  ),
                  onPickFile: () => _uploadDoc(
                    profile: p,
                    docType: type,
                    channel: DocumentPickChannel.file,
                  ),
                ),
                if (canApprove || canReject) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (canApprove)
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: busy
                                ? null
                                : () => _reviewDoc(
                                      profile: p,
                                      docType: type,
                                      status: DocumentReviewStatus.aprobado,
                                    ),
                            child: const Text('Aprobar'),
                          ),
                        ),
                      if (canApprove && canReject) const SizedBox(width: 8),
                      if (canReject)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              foregroundColor: Colors.red.shade800,
                            ),
                            onPressed: busy
                                ? null
                                : () => _reviewDoc(
                                      profile: p,
                                      docType: type,
                                      status: DocumentReviewStatus.rechazado,
                                    ),
                            child: const Text('Rechazar'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildListPane({
    required List<ProfileModel> page,
    required List<ProfileModel> filtered,
    required bool desktop,
  }) {
    if (_loading) {
      return const AdminListSkeleton(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.brand,
      child: filtered.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                Center(
                  child: Text(
                    'No hay perfiles en esta cola.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : ListView(
              controller: _listScroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (desktop)
                  _KycDesktopTable(
                    rows: page,
                    selectedId: _expandedProfileId,
                    onSelect: _selectProfile,
                    onOpenDossier: _openDossier,
                  )
                else
                  for (final p in page)
                    Padding(
                      key: ValueKey<String>('kyc-${p.id}'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _KycListCard(
                        profile: p,
                        onTap: () => _openMobileDetail(p),
                      ),
                    ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final filtered = _filtered;
    final page = sliceListPage(
      items: filtered,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );

    final desktop = isAdminDesktopLayout(context);
    final maxWidth = desktop
        ? AppBreakpoints.adminContentMaxWidth
        : AppBreakpoints.formMaxWidth;
    final preview = _expandedProfileId == null
        ? null
        : () {
      for (final p in _profiles) {
        if (p.id == _expandedProfileId) return p;
      }
      return null;
    }();

    final listColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminUsersFilterBar(
          searchController: _searchCtrl,
          searchHint: 'Buscar por empresa, RIF, correo o teléfono…',
          estado: _estado,
          rol: _rol,
          sort: _sort,
          onSearchChanged: (_) => setState(() => _pageIndex = 0),
          onEstado: (v) => setState(() {
            _estado = v;
            _expandedProfileId = null;
            _pageIndex = 0;
          }),
          onRol: (v) => setState(() {
            _rol = v;
            _expandedProfileId = null;
            _pageIndex = 0;
          }),
          onSort: (v) => setState(() {
            _sort = v;
            _pageIndex = 0;
          }),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListPageBar(
            total: filtered.length,
            pageIndex: _pageIndex,
            pageSize: _pageSize,
            onPageIndex: (index) {
              setState(() => _pageIndex = index);
              if (_listScroll.hasClients) _listScroll.jumpTo(0);
            },
            onPageSize: (size) {
              setState(() {
                _pageSize = size;
                _pageIndex = 0;
              });
              if (_listScroll.hasClients) _listScroll.jumpTo(0);
            },
          ),
        ),
        Expanded(
          child: _buildListPane(
            page: page,
            filtered: filtered,
            desktop: desktop,
          ),
        ),
      ],
    );

    if (!desktop || preview == null) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: listColumn,
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.adminContentMaxWidth,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: listColumn),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 420,
              child: Material(
                color: AppColors.card,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            preview.businessName?.trim().isNotEmpty == true
                                ? preview.businessName!.trim()
                                : 'Sin nombre',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          onPressed: () =>
                              setState(() => _expandedProfileId = null),
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailBody(
                      preview,
                      afterTerms: _profileOptionActions(
                        preview,
                        buttonHeight: 44,
                        onEditFiscal: () => _openDossier(preview),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


}

class _KycDesktopTable extends StatelessWidget {
  const _KycDesktopTable({
    required this.rows,
    required this.selectedId,
    required this.onSelect,
    required this.onOpenDossier,
  });

  final List<ProfileModel> rows;
  final String? selectedId;
  final ValueChanged<ProfileModel> onSelect;
  final ValueChanged<ProfileModel> onOpenDossier;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Material(
              color: selectedId == rows[i].id
                  ? AppColors.brandBlueContainer
                  : Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(rows[i]),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rows[i].businessName?.trim().isNotEmpty == true
                                  ? rows[i].businessName!.trim()
                                  : 'Sin nombre',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (rows[i].email?.trim().isNotEmpty == true)
                              Text(
                                rows[i].email!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          ProfileRoleLabels.labelEs(rows[i].role),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          OwnerAccountRules.statusLabelEs(
                            role: rows[i].role,
                            accountAccessStatus: rows[i].accountAccessStatus,
                            deactivatedAt: rows[i].deactivatedAt,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar datos',
                        onPressed: () => onOpenDossier(rows[i]),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KycListCard extends StatelessWidget {
  const _KycListCard({
    required this.profile,
    required this.onTap,
  });

  final ProfileModel profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.businessName?.trim().isNotEmpty == true
                          ? profile.businessName!.trim()
                          : 'Sin nombre',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        ProfileRoleLabels.labelEs(profile.role),
                        if (profile.email?.trim().isNotEmpty == true)
                          profile.email!.trim(),
                        if (profile.rif?.trim().isNotEmpty == true)
                          profile.rif!.trim(),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _KycStatusChip(status: profile.accountAccessStatus),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycStatusChip extends StatelessWidget {
  const _KycStatusChip({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final label = AccountAccessStatus.labelEsCompact(status);
    final color = switch (status?.trim()) {
      AccountAccessStatus.active => AppColors.successGreen,
      AccountAccessStatus.rejected => Colors.red.shade700,
      AccountAccessStatus.pendingReview => AppColors.brand,
      _ => AppColors.textSecondary,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}
