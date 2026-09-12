import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_access_status.dart';
import 'aliado_doc_type.dart';
import 'document_review_status.dart';
import 'kyc_status.dart';
import 'profile_document_model.dart';
import 'package:motolink_pro_app/features/admin/owner_account_dossier.dart';
import 'package:motolink_pro_app/features/admin/owner_account_search.dart';
import 'package:motolink_pro_app/features/admin/owner_importer_catalog_screen.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/main_shell_tab.dart';

enum _KycQueueFilter { solicitudesIngreso, enRevision, conPendientes, todos }

enum _KycRoleFilter { todos, aliados, mayoristas }

/// Admin: cola de verificación (aliados KYC + mayoristas / importadores).
class AdminKycReviewPanel extends StatefulWidget {
  const AdminKycReviewPanel({
    super.key,
    this.viewerIsOwner = false,
  });

  /// El owner ve y busca el correo de Auth en cada expediente.
  final bool viewerIsOwner;

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
  _KycQueueFilter _filter = _KycQueueFilter.solicitudesIngreso;
  _KycRoleFilter _roleFilter = _KycRoleFilter.todos;
  final _searchCtrl = TextEditingController();

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
      if (widget.viewerIsOwner) {
        try {
          final emails = await SupabaseService.ownerAuthEmailsByProfileId();
          rows = rows.map((p) => p.withAuthEmail(emails[p.id])).toList();
        } catch (_) {
          // KYC sigue útil sin correo si el RPC owner falla.
        }
      }
      if (!mounted) return;
      setState(() {
        _profiles = rows;
        _loading = false;
        _docsByProfile.clear();
      });
      _onKycNotificationDeepLink();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _ensureDocsLoaded(String profileId) async {
    if (_docsByProfile.containsKey(profileId)) return;
    try {
      final docs =
          await SupabaseService.fetchProfileDocumentsForProfile(profileId);
      if (!mounted) return;
      setState(() => _docsByProfile[profileId] = docs);
    } catch (_) {
      if (!mounted) return;
      setState(() => _docsByProfile[profileId] = []);
    }
  }

  bool _profileNeedsAttention(ProfileModel p) {
    final ks = p.kycStatus?.trim();
    if (ks == KycStatus.enRevision) return true;
    final docs = _docsByProfile[p.id];
    if (docs == null) return ks == KycStatus.pendiente || ks == KycStatus.rechazado;
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

  List<ProfileModel> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _profiles.where((p) {
      final role = p.role?.trim().toLowerCase();
      if (role != 'aliado' && role != 'importador') return false;
      switch (_roleFilter) {
        case _KycRoleFilter.aliados:
          if (role != 'aliado') return false;
        case _KycRoleFilter.mayoristas:
          if (role != 'importador') return false;
        case _KycRoleFilter.todos:
          break;
      }
      if (q.isNotEmpty && !ownerAccountMatchesQuery(p, q)) return false;
      switch (_filter) {
        case _KycQueueFilter.todos:
          return true;
        case _KycQueueFilter.solicitudesIngreso:
          return p.accountAccessStatus?.trim() ==
              AccountAccessStatus.pendingReview;
        case _KycQueueFilter.enRevision:
          if (_isImportador(p)) {
            return p.accountAccessStatus?.trim() ==
                AccountAccessStatus.pendingReview;
          }
          return p.kycStatus?.trim() == KycStatus.enRevision;
        case _KycQueueFilter.conPendientes:
          if (_isImportador(p)) {
            return p.accountAccessStatus?.trim() ==
                    AccountAccessStatus.pendingReview ||
                p.accountAccessStatus?.trim() == AccountAccessStatus.rejected;
          }
          return _profileNeedsAttention(p);
      }
    }).toList();
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

  Future<void> _reviewDoc({
    required ProfileModel profile,
    required String docType,
    required String status,
  }) async {
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

  void _toggleExpand(ProfileModel p) {
    final next = _expandedProfileId == p.id ? null : p.id;
    setState(() => _expandedProfileId = next);
    if (next != null && _isAliado(p)) _ensureDocsLoaded(next);
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

  Widget _importadorProfileSummary(ProfileModel p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _referralAttributionBox(p),
        OwnerAccountDossier(
          profile: p,
          title: 'Perfil del mayorista',
          showAuthEmail: widget.viewerIsOwner,
        ),
      ],
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

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.formMaxWidth,
        ),
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: widget.viewerIsOwner
                  ? 'Buscar por empresa, RIF, correo o teléfono…'
                  : 'Buscar por empresa, RIF o teléfono…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _KycRoleFilter.values)
                ChoiceChip(
                  label: Text(_roleFilterLabel(f)),
                  selected: _roleFilter == f,
                  onSelected: (_) => setState(() => _roleFilter = f),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _KycQueueFilter.values)
                ChoiceChip(
                  label: Text(_queueFilterLabel(f)),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.brand,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
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
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final p = filtered[i];
                            final expanded = _expandedProfileId == p.id;
                            final role = p.role?.trim() ?? '';
                            final docs = _docsByProfile[p.id] ?? [];
                            final currentByType = <String, ProfileDocumentModel>{};
                            for (final d in docs) {
                              if (d.isCurrent) {
                                currentByType[d.docType] = d;
                              }
                            }
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  InkWell(
                                    onTap: () => _toggleExpand(p),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        12,
                                        8,
                                        12,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  p.businessName
                                                              ?.trim()
                                                              .isNotEmpty ==
                                                          true
                                                      ? p.businessName!.trim()
                                                      : 'Sin nombre',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                if (!expanded) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    [
                                                      ProfileRoleLabels
                                                          .labelEs(role),
                                                      if (p.email != null)
                                                        p.email,
                                                      if (p.rif != null &&
                                                          p.rif!
                                                              .trim()
                                                              .isNotEmpty)
                                                        p.rif,
                                                      if (p.phone != null &&
                                                          p.phone!
                                                              .trim()
                                                              .isNotEmpty)
                                                        p.phone,
                                                      if (p
                                                          .hasReferralAttribution)
                                                        'Referido',
                                                    ].join(' · '),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (p.hasReferralAttribution)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                right: 6,
                                                top: 2,
                                              ),
                                              child: Icon(
                                                Icons.handshake_outlined,
                                                size: 18,
                                                color: AppColors.brand,
                                              ),
                                            ),
                                          _KycStatusChip(
                                            status: p.accountAccessStatus,
                                          ),
                                          Icon(
                                            expanded
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (expanded) ...[
                                    const Divider(height: 1),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        8,
                                        12,
                                        12,
                                      ),
                                      child: _isImportador(p)
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _importadorProfileSummary(p),
                                                if (widget.viewerIsOwner) ...[
                                                  const SizedBox(height: 12),
                                                  OutlinedButton.icon(
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      minimumSize:
                                                          const Size.fromHeight(
                                                        44,
                                                      ),
                                                    ),
                                                    onPressed: () =>
                                                        OwnerImporterCatalogScreen
                                                            .open(
                                                      context,
                                                      importerId: p.id,
                                                      importerName: p
                                                                  .businessName
                                                                  ?.trim()
                                                                  .isNotEmpty ==
                                                              true
                                                          ? p.businessName!
                                                              .trim()
                                                          : (p.email ??
                                                              'Mayorista'),
                                                    ),
                                                    icon: const Icon(
                                                      Icons
                                                          .inventory_2_outlined,
                                                      size: 18,
                                                    ),
                                                    label: const Text(
                                                      'Ver catálogo',
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 12),
                                                FilledButton(
                                                  style: FilledButton.styleFrom(
                                                    minimumSize:
                                                        const Size.fromHeight(
                                                      44,
                                                    ),
                                                  ),
                                                  onPressed: p.hasActiveAccountAccess ||
                                                          _busyProfileId ==
                                                              p.id
                                                      ? null
                                                      : () =>
                                                          _setImportadorAccess(
                                                            p,
                                                            KycStatus.aprobado,
                                                          ),
                                                  child: Text(
                                                    p.hasActiveAccountAccess
                                                        ? 'Acceso habilitado'
                                                        : 'Aprobar mayorista',
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                OutlinedButton(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    minimumSize:
                                                        const Size.fromHeight(
                                                      44,
                                                    ),
                                                    foregroundColor:
                                                        Colors.red.shade800,
                                                  ),
                                                  onPressed:
                                                      _busyProfileId == p.id
                                                          ? null
                                                          : () =>
                                                              _setImportadorAccess(
                                                                p,
                                                                KycStatus
                                                                    .rechazado,
                                                              ),
                                                  child: const Text('Rechazar'),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _referralAttributionBox(p),
                                                OwnerAccountDossier(
                                                  profile: p,
                                                  title: 'Datos de la tienda',
                                                  showAuthEmail:
                                                      widget.viewerIsOwner,
                                                ),
                                                const SizedBox(height: 12),
                                                OutlinedButton(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    minimumSize:
                                                        const Size.fromHeight(
                                                      44,
                                                    ),
                                                  ),
                                                  onPressed:
                                                      _busyProfileId == p.id
                                                          ? null
                                                          : () =>
                                                              _pickGlobalStatus(
                                                                p,
                                                              ),
                                                  child: const Text(
                                                    'Cambiar KYC global',
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                FilledButton(
                                                  style: FilledButton.styleFrom(
                                                    minimumSize:
                                                        const Size.fromHeight(
                                                      44,
                                                    ),
                                                  ),
                                                  onPressed: p.hasActiveAccountAccess ||
                                                          _busyProfileId ==
                                                              p.id
                                                      ? null
                                                      : () => _setGlobalKyc(
                                                            p,
                                                            KycStatus.aprobado,
                                                          ),
                                                  child: Text(
                                                    p.hasActiveAccountAccess
                                                        ? 'Acceso habilitado'
                                                        : 'Habilitar acceso',
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                ...AliadoDocType.forAdminReview(
                                                  role: role,
                                                  uploadedTypes:
                                                      currentByType.keys,
                                                ).map((type) {
                                                  final doc =
                                                      currentByType[type];
                                                  final has = doc != null;
                                                  final st =
                                                      doc?.reviewStatus?.trim();
                                                  final busy = _busyDocKey ==
                                                      '${p.id}:$type';
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      bottom: 8,
                                                    ),
                                                    child: DecoratedBox(
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                          color: AppColors
                                                              .borderSubtle,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(10),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .stretch,
                                                          children: [
                                                            Text(
                                                              AliadoDocType
                                                                  .labelEs(
                                                                type,
                                                              ),
                                                              style:
                                                                  const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Text(
                                                              has
                                                                  ? DocumentReviewStatus
                                                                      .labelEs(
                                                                      st ??
                                                                          DocumentReviewStatus
                                                                              .pendiente,
                                                                    )
                                                                  : 'Sin archivo',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .grey
                                                                    .shade700,
                                                              ),
                                                            ),
                                                            if (has) ...[
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                              OutlinedButton(
                                                                style: OutlinedButton.styleFrom(
                                                                  minimumSize:
                                                                      const Size
                                                                          .fromHeight(
                                                                    40,
                                                                  ),
                                                                ),
                                                                onPressed: busy
                                                                    ? null
                                                                    : () =>
                                                                        _openDocument(
                                                                          doc,
                                                                        ),
                                                                child:
                                                                    const Text(
                                                                  'Ver archivo',
                                                                ),
                                                              ),
                                                              if (st !=
                                                                      DocumentReviewStatus
                                                                          .aprobado ||
                                                                  st !=
                                                                      DocumentReviewStatus
                                                                          .rechazado) ...[
                                                                const SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    if (st !=
                                                                        DocumentReviewStatus
                                                                            .aprobado)
                                                                      Expanded(
                                                                        child:
                                                                            FilledButton(
                                                                          style:
                                                                              FilledButton.styleFrom(
                                                                            minimumSize:
                                                                                const Size.fromHeight(
                                                                              40,
                                                                            ),
                                                                          ),
                                                                          onPressed: busy
                                                                              ? null
                                                                              : () => _reviewDoc(
                                                                                    profile:
                                                                                        p,
                                                                                    docType:
                                                                                        type,
                                                                                    status:
                                                                                        DocumentReviewStatus.aprobado,
                                                                                  ),
                                                                          child:
                                                                              const Text(
                                                                            'Aprobar',
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    if (st !=
                                                                            DocumentReviewStatus
                                                                                .aprobado &&
                                                                        st !=
                                                                            DocumentReviewStatus
                                                                                .rechazado)
                                                                      const SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                    if (st !=
                                                                        DocumentReviewStatus
                                                                            .rechazado)
                                                                      Expanded(
                                                                        child:
                                                                            OutlinedButton(
                                                                          style:
                                                                              OutlinedButton.styleFrom(
                                                                            minimumSize:
                                                                                const Size.fromHeight(
                                                                              40,
                                                                            ),
                                                                            foregroundColor:
                                                                                Colors.red.shade800,
                                                                          ),
                                                                          onPressed: busy
                                                                              ? null
                                                                              : () => _reviewDoc(
                                                                                    profile:
                                                                                        p,
                                                                                    docType:
                                                                                        type,
                                                                                    status:
                                                                                        DocumentReviewStatus.rechazado,
                                                                                  ),
                                                                          child:
                                                                              const Text(
                                                                            'Rechazar',
                                                                          ),
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              ],
                                                              if (busy)
                                                                const Padding(
                                                                  padding: EdgeInsets.only(
                                                                    top: 8,
                                                                  ),
                                                                  child:
                                                                      LinearProgressIndicator(
                                                                    minHeight:
                                                                        2,
                                                                    color: AppColors
                                                                        .brand,
                                                                  ),
                                                                ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    ),
      ),
    );
  }

  static String _roleFilterLabel(_KycRoleFilter f) {
    return switch (f) {
      _KycRoleFilter.todos => 'Todos',
      _KycRoleFilter.aliados => 'Tiendas minoristas',
      _KycRoleFilter.mayoristas => 'Mayoristas',
    };
  }

  static String _queueFilterLabel(_KycQueueFilter f) {
    return switch (f) {
      _KycQueueFilter.solicitudesIngreso => 'Solicitudes',
      _KycQueueFilter.enRevision => 'En revisión',
      _KycQueueFilter.conPendientes => 'Con pendientes',
      _KycQueueFilter.todos => 'Todos los estados',
    };
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
