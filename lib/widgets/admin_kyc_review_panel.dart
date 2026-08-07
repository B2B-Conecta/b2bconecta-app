import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/account_access_status.dart';
import '../models/aliado_doc_type.dart';
import '../models/document_review_status.dart';
import '../models/kyc_status.dart';
import '../models/profile_document_model.dart';
import '../models/profile_model.dart';
import '../models/profile_role_labels.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'main_shell_tab.dart';

enum _KycQueueFilter { solicitudesIngreso, enRevision, conPendientes, todos }

enum _KycRoleFilter { todos, aliados, mayoristas }

/// Admin: cola de verificación (aliados KYC + mayoristas / importadores).
class AdminKycReviewPanel extends StatefulWidget {
  const AdminKycReviewPanel({super.key});

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
      final rows = await SupabaseService.fetchB2BProfilesForAdminKycReview();
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
      if (q.isNotEmpty) {
        final name = (p.businessName ?? '').toLowerCase();
        final rif = (p.rif ?? '').toLowerCase();
        if (!name.contains(q) && !rif.contains(q)) return false;
      }
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
          ? 'Acceso habilitado. El aliado recibirá una notificación en la app.'
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

  Widget _importadorProfileSummary(ProfileModel p) {
    final lines = <String>[
      if (p.rif?.trim().isNotEmpty == true) 'RIF: ${p.rif!.trim()}',
      if (p.phone?.trim().isNotEmpty == true) 'Tel: ${p.phone!.trim()}',
      [
        p.estado?.trim(),
        p.ciudad?.trim(),
      ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
      if (p.direccion?.trim().isNotEmpty == true) p.direccion!.trim(),
    ].where((s) => s.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Perfil del mayorista',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        if (p.fiscalMapsUrl?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(p.fiscalMapsUrl!.trim());
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Ver en Google Maps'),
            ),
          ),
        ],
        if (p.accountReviewNote?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            'Nota previa: ${p.accountReviewNote!.trim()}',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.red.shade800,
            ),
          ),
        ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar por empresa o RIF…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _roleFilter == _KycRoleFilter.todos,
                onSelected: (_) =>
                    setState(() => _roleFilter = _KycRoleFilter.todos),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Aliados'),
                selected: _roleFilter == _KycRoleFilter.aliados,
                onSelected: (_) =>
                    setState(() => _roleFilter = _KycRoleFilter.aliados),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Mayoristas'),
                selected: _roleFilter == _KycRoleFilter.mayoristas,
                onSelected: (_) =>
                    setState(() => _roleFilter = _KycRoleFilter.mayoristas),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Solicitudes ingreso'),
                selected: _filter == _KycQueueFilter.solicitudesIngreso,
                onSelected: (_) => setState(
                  () => _filter = _KycQueueFilter.solicitudesIngreso,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('En revisión'),
                selected: _filter == _KycQueueFilter.enRevision,
                onSelected: (_) =>
                    setState(() => _filter = _KycQueueFilter.enRevision),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Con pendientes'),
                selected: _filter == _KycQueueFilter.conPendientes,
                onSelected: (_) =>
                    setState(() => _filter = _KycQueueFilter.conPendientes),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Todos los estados'),
                selected: _filter == _KycQueueFilter.todos,
                onSelected: (_) =>
                    setState(() => _filter = _KycQueueFilter.todos),
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
                                  ListTile(
                                    onTap: () => _toggleExpand(p),
                                    title: Text(
                                      p.businessName?.trim().isNotEmpty == true
                                          ? p.businessName!.trim()
                                          : 'Sin nombre',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${ProfileRoleLabels.labelEs(role)}'
                                      '${p.rif != null && p.rif!.trim().isNotEmpty ? ' · ${p.rif}' : ''}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 4,
                                          ),
                                          child: Text(
                                            AccountAccessStatus.labelEs(
                                              p.accountAccessStatus,
                                            ),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          expanded
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                        ),
                                      ],
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
                                                const SizedBox(height: 12),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    FilledButton.tonalIcon(
                                                      onPressed:
                                                          _busyProfileId == p.id
                                                              ? null
                                                              : () =>
                                                                  _setImportadorAccess(
                                                                    p,
                                                                    KycStatus
                                                                        .aprobado,
                                                                  ),
                                                      icon: const Icon(
                                                        Icons
                                                            .check_circle_outline,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        'Aprobar mayorista',
                                                      ),
                                                    ),
                                                    OutlinedButton.icon(
                                                      onPressed:
                                                          _busyProfileId == p.id
                                                              ? null
                                                              : () =>
                                                                  _setImportadorAccess(
                                                                    p,
                                                                    KycStatus
                                                                        .rechazado,
                                                                  ),
                                                      icon: Icon(
                                                        Icons.cancel_outlined,
                                                        size: 18,
                                                        color:
                                                            Colors.red.shade800,
                                                      ),
                                                      label: Text(
                                                        'Rechazar',
                                                        style: TextStyle(
                                                          color: Colors
                                                              .red.shade800,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    OutlinedButton.icon(
                                                      onPressed:
                                                          _busyProfileId == p.id
                                                              ? null
                                                              : () =>
                                                                  _pickGlobalStatus(
                                                                    p,
                                                                  ),
                                                      icon: const Icon(
                                                        Icons
                                                            .verified_user_outlined,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        'Cambiar KYC global',
                                                      ),
                                                    ),
                                                    FilledButton.tonalIcon(
                                                      onPressed:
                                                          _busyProfileId == p.id
                                                              ? null
                                                              : () =>
                                                                  _setGlobalKyc(
                                                                    p,
                                                                    KycStatus
                                                                        .aprobado,
                                                                  ),
                                                      icon: const Icon(
                                                        Icons
                                                            .check_circle_outline,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        'Habilitar acceso',
                                                      ),
                                                    ),
                                                  ],
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
                                                              Wrap(
                                                                spacing: 6,
                                                                children: [
                                                                  TextButton(
                                                                    onPressed:
                                                                        busy
                                                                            ? null
                                                                            : () => _openDocument(
                                                                                  doc,
                                                                                ),
                                                                    child:
                                                                        const Text(
                                                                      'Ver archivo',
                                                                    ),
                                                                  ),
                                                                  if (st !=
                                                                      DocumentReviewStatus
                                                                          .aprobado)
                                                                    TextButton(
                                                                      onPressed: busy
                                                                          ? null
                                                                          : () =>
                                                                              _reviewDoc(
                                                                                profile: p,
                                                                                docType: type,
                                                                                status: DocumentReviewStatus.aprobado,
                                                                              ),
                                                                      child:
                                                                          const Text(
                                                                        'Aprobar',
                                                                      ),
                                                                    ),
                                                                  if (st !=
                                                                      DocumentReviewStatus
                                                                          .rechazado)
                                                                    TextButton(
                                                                      onPressed: busy
                                                                          ? null
                                                                          : () =>
                                                                              _reviewDoc(
                                                                                profile: p,
                                                                                docType: type,
                                                                                status: DocumentReviewStatus.rechazado,
                                                                              ),
                                                                      child:
                                                                          Text(
                                                                        'Rechazar',
                                                                        style:
                                                                            TextStyle(
                                                                          color: Colors
                                                                              .red
                                                                              .shade800,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                ],
                                                              ),
                                                              if (busy)
                                                                const LinearProgressIndicator(
                                                                  minHeight: 2,
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
    );
  }
}
