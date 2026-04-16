import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/aliado_doc_type.dart';
import '../models/cash_phase_policy.dart';
import '../models/document_review_status.dart';
import '../models/kyc_status.dart';
import '../models/profile_document_model.dart';
import '../models/profile_model.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'kyc_status_highlight_widgets.dart';
import 'main_shell_tab.dart';

/// Admin: lista de aliados con edición de `credit_limit`.
/// Mensaje legible cuando falla el RPC de KYC global (evita mostrar `PostgresException` crudo).
String _kycGlobalStatusRpcUserMessage(Object error) {
  final raw = switch (error) {
    PostgrestException e => e.message,
    _ => _extractMessageFromRpcExceptionString(error.toString()),
  };
  final t = raw.trim();
  if (t.isEmpty) {
    return 'No se pudo actualizar el estado KYC. Inténtelo de nuevo.';
  }
  if (t.contains('deben estar registrados los 6 documentos obligatorios') ||
      t.contains('archivo cargado por tipo')) {
    return 'No puede aprobar el KYC todavía: el aliado debe tener cargados los 6 '
        'documentos obligatorios (un archivo por tipo). Pulse «Revisar documentación '
        '(por documento)» para ver qué falta.';
  }
  if (t.contains('cada documento obligatorio debe tener') ||
      (t.contains('documento obligatorio') && t.contains('aprobado'))) {
    return 'No puede aprobar el KYC global hasta que los 6 documentos estén aprobados '
        'uno a uno. Use «Revisar documentación (por documento)».';
  }
  if (t.startsWith('No se puede marcar KYC')) return t;
  return t.length > 280 ? '${t.substring(0, 277)}…' : t;
}

String _extractMessageFromRpcExceptionString(String s) {
  const needle = 'message: ';
  final i = s.indexOf(needle);
  if (i < 0) return s;
  final from = i + needle.length;
  final codeAt = s.indexOf(', code:', from);
  if (codeAt > from) return s.substring(from, codeAt).trim();
  return s;
}

class AdminAliadosCreditPanel extends StatefulWidget {
  const AdminAliadosCreditPanel({super.key});

  @override
  State<AdminAliadosCreditPanel> createState() =>
      _AdminAliadosCreditPanelState();
}

class _AdminAliadosCreditPanelState extends State<AdminAliadosCreditPanel> {
  List<ProfileModel> _rows = [];
  bool _loading = true;
  String? _error;
  final Map<String, ExpansionTileController> _expansionControllers = {};
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    MainShellTabController.registerAdminCreditoKycNotificationDeepLink(
      _onNotificationCreditoKycDeepLink,
    );
    _load();
  }

  @override
  void dispose() {
    MainShellTabController.registerAdminCreditoKycNotificationDeepLink(null);
    super.dispose();
  }

  void _onNotificationCreditoKycDeepLink() {
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    if (_rows.any((r) => r.id == pending)) {
      MainShellTabController.consumePendingNotificationRelatedId();
      _expandAliadoAndScroll(pending);
    } else if (!_loading) {
      unawaited(_load());
    }
  }

  void _tryExpandFromPendingKycNotification() {
    final pending = MainShellTabController.peekPendingNotificationRelatedId();
    if (pending == null) return;
    if (_rows.any((r) => r.id == pending)) {
      MainShellTabController.consumePendingNotificationRelatedId();
      _expandAliadoAndScroll(pending);
    } else if (!_loading) {
      MainShellTabController.consumePendingNotificationRelatedId();
    }
  }

  void _expandAliadoAndScroll(String profileId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _cardKeys[profileId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.12,
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _expansionControllers[profileId]?.expand();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final ctx2 = _cardKeys[profileId]?.currentContext;
          if (ctx2 != null) {
            Scrollable.ensureVisible(
              ctx2,
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              alignment: 0.06,
            );
          }
        });
      });
    });
  }

  Widget _buildAliadoCard(ProfileModel p) {
    final c = _expansionControllers.putIfAbsent(
      p.id,
      () => ExpansionTileController(),
    );
    final gk = _cardKeys.putIfAbsent(p.id, GlobalKey.new);
    return _AliadoCreditCard(
      key: ValueKey<String>(p.id),
      profile: p,
      onSaved: _load,
      expansionController: c,
      cardKey: gk,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SupabaseService.fetchAliadoProfilesForAdmin();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
      _tryExpandFromPendingKycNotification();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            Center(
              child: Text(
                'No hay aliados registrados.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (var i = 0; i < _rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _buildAliadoCard(_rows[i]),
          ],
        ],
      ),
    );
  }
}

class _AliadoCreditCard extends StatefulWidget {
  const _AliadoCreditCard({
    super.key,
    required this.profile,
    required this.onSaved,
    required this.expansionController,
    required this.cardKey,
  });

  final ProfileModel profile;
  final Future<void> Function() onSaved;
  final ExpansionTileController expansionController;
  final GlobalKey cardKey;

  @override
  State<_AliadoCreditCard> createState() => _AliadoCreditCardState();
}

class _AliadoCreditCardState extends State<_AliadoCreditCard> {
  late final TextEditingController _limitCtrl;
  bool _saving = false;
  bool _savingKyc = false;
  double? _openExposure;
  bool _loadingExposure = false;

  @override
  void initState() {
    super.initState();
    final lim = widget.profile.creditLimit;
    _limitCtrl = TextEditingController(
      text: lim != null ? lim.toStringAsFixed(2) : '',
    );
    _loadExposure();
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExposure() async {
    setState(() => _loadingExposure = true);
    try {
      final v =
          await SupabaseService.fetchOpenCreditExposureForAliado(widget.profile.id);
      if (!mounted) return;
      setState(() {
        _openExposure = v;
        _loadingExposure = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _openExposure = null;
        _loadingExposure = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _AliadoCreditCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      final lim = widget.profile.creditLimit;
      _limitCtrl.text = lim != null ? lim.toStringAsFixed(2) : '';
      _loadExposure();
    } else if (oldWidget.profile.creditLimit != widget.profile.creditLimit) {
      final lim = widget.profile.creditLimit;
      _limitCtrl.text = lim != null ? lim.toStringAsFixed(2) : '';
    }
    if (oldWidget.profile.id == widget.profile.id &&
        oldWidget.profile.creditoConsumidoAcumulado !=
            widget.profile.creditoConsumidoAcumulado) {
      _loadExposure();
    }
  }

  String _kycDropdownValue() {
    final s = widget.profile.kycStatus?.trim();
    if (s == null || s.isEmpty) return KycStatus.pendiente;
    switch (s) {
      case KycStatus.pendiente:
      case KycStatus.enRevision:
      case KycStatus.aprobado:
      case KycStatus.rechazado:
        return s;
      default:
        return KycStatus.pendiente;
    }
  }

  Future<void> _setAliadoKycGlobal(String status) async {
    setState(() => _savingKyc = true);
    try {
      await SupabaseService.adminSetAliadoKycStatus(
        aliadoId: widget.profile.id,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('KYC global actualizado a «${KycStatus.labelEs(status)}».'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_kycGlobalStatusRpcUserMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingKyc = false);
    }
  }

  Future<void> _save() async {
    final raw = _limitCtrl.text.trim().replaceAll(',', '.');
    final v = double.tryParse(raw);
    if (v == null || v < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Introduce un monto numérico válido (≥ 0).'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.adminSetAliadoCreditLimit(
        aliadoId: widget.profile.id,
        creditLimit: v,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Límite de crédito actualizado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openDocReviewSheet() async {
    try {
      final brokerProfile = await SupabaseService.fetchMyProfile();
      final sessionEmail =
          Supabase.instance.client.auth.currentUser?.email?.trim();
      var docs = await SupabaseService.fetchProfileDocumentsForAliado(
        widget.profile.id,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setModalState) {
                  ProfileDocumentModel? currentDocFor(String t) {
                    for (final d in docs) {
                      if (d.docType == t && d.isCurrent) return d;
                    }
                    return null;
                  }

                  List<ProfileDocumentModel> historyDocsFor(String t) {
                    final list = <ProfileDocumentModel>[];
                    for (final d in docs) {
                      if (d.docType == t && !d.isCurrent) list.add(d);
                    }
                    list.sort((a, b) {
                      final ca =
                          a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final cb =
                          b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return cb.compareTo(ca);
                    });
                    return list;
                  }

                  String? busyType;

                  Future<void> refreshDocs() async {
                    final fresh =
                        await SupabaseService.fetchProfileDocumentsForAliado(
                      widget.profile.id,
                    );
                    if (ctx.mounted) {
                      setModalState(() => docs = fresh);
                    }
                  }

                  Future<void> setReview(
                    String docType,
                    String status, {
                    String? note,
                  }) async {
                    setModalState(() => busyType = docType);
                    try {
                      await SupabaseService.adminSetProfileDocumentReviewStatus(
                        aliadoId: widget.profile.id,
                        docType: docType,
                        status: status,
                        note: note,
                      );
                      if (!ctx.mounted) return;
                      await refreshDocs();
                      await widget.onSaved();
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Estado del documento actualizado.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      if (!ctx.mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    } finally {
                      if (ctx.mounted) {
                        setModalState(() => busyType = null);
                      }
                    }
                  }

                  Future<void> promptReject(String type) async {
                    final d = currentDocFor(type);
                    final note = await _promptRejectionNoteForDoc(
                      ctx,
                      docLabel: AliadoDocType.labelEs(type),
                      initialNote: d?.reviewNote,
                    );
                    if (note == null) return;
                    await setReview(
                      type,
                      DocumentReviewStatus.rechazado,
                      note: note,
                    );
                  }

                  return SafeArea(
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Revisión documental KYC',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              children: [
                                _KycReviewContextCard(
                                  title: 'Solicitud · Aliado',
                                  accent: AppColors.brandBlue,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.profile.businessName ?? '—',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _KycMetaLine(
                                        'RIF',
                                        widget.profile.rif ?? '—',
                                      ),
                                      _KycMetaLine(
                                        'Teléfono',
                                        widget.profile.phone ?? '—',
                                      ),
                                      _KycMetaLine(
                                        'ID perfil',
                                        widget.profile.id,
                                        monospace: true,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'KYC global: ${KycStatus.labelEs(widget.profile.kycStatus)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _KycReviewContextCard(
                                  title: 'Quién revisa (MotoLink)',
                                  accent: AppColors.brandOrange,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        brokerProfile?.businessName ??
                                            'Administrador MotoLink',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Su sesión: ${sessionEmail ?? '—'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Cada decisión queda registrada con su usuario. '
                                        'Use una nota clara al rechazar para que el aliado corrija el archivo.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Documentos',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey.shade900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                for (final type in AliadoDocType.all)
                                  _DocReviewTile(
                                    docType: type,
                                    doc: currentDocFor(type),
                                    olderVersions: historyDocsFor(type),
                                    busy: busyType == type,
                                    onOpen: () async {
                                      final d = currentDocFor(type);
                                      if (d == null) return;
                                      final url = await SupabaseService
                                          .createSignedUrlForProfileDocument(
                                        d.storagePath,
                                      );
                                      final uri = Uri.parse(url);
                                      if (ctx.mounted &&
                                          await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    onOpenVersion: (d) async {
                                      final url = await SupabaseService
                                          .createSignedUrlForProfileDocument(
                                        d.storagePath,
                                      );
                                      final uri = Uri.parse(url);
                                      if (ctx.mounted &&
                                          await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    onApprove: currentDocFor(type) == null
                                        ? null
                                        : () => setReview(
                                              type,
                                              DocumentReviewStatus.aprobado,
                                            ),
                                    onReject: currentDocFor(type) == null
                                        ? null
                                        : () => unawaited(promptReject(type)),
                                    onEnRevision: currentDocFor(type) == null
                                        ? null
                                        : () => setReview(
                                              type,
                                              DocumentReviewStatus.enRevision,
                                            ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.profile.businessName ?? '—').trim();
    final rif = (widget.profile.rif ?? '—').trim();
    final lim = widget.profile.creditLimit;
    final cons = widget.profile.creditoConsumidoAcumulado ?? 0;
    final exp = _openExposure ?? 0;
    final disp = lim != null
        ? (lim - cons - exp).clamp(0.0, double.infinity)
        : null;
    final cupoResumen = lim == null
        ? 'Sin cupo asignado'
        : _loadingExposure
            ? '\$${lim.toStringAsFixed(2)} USD asignado'
            : '\$${lim.toStringAsFixed(2)} asignado · \$${disp!.toStringAsFixed(2)} disp.';

    return KeyedSubtree(
      key: widget.cardKey,
      child: Material(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.radius12,
          side: BorderSide(color: Colors.grey.shade300),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            controller: widget.expansionController,
            tilePadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RIF: $rif',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _AdminKycSummaryChip(kycStatus: widget.profile.kycStatus),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.fieldFill,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 14,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cupoResumen,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pulse la fila para cupo, KYC y acciones',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            children: [
              Text(
                'Score: ${widget.profile.creditScore ?? '—'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 6),
              Text(
                'Fase contado: ${widget.profile.primerosPedidosContadoEntregados ?? 0}/'
                '${CashPhasePolicy.entregasRequeridas} entregas completadas',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                'KYC global: ${KycStatus.labelEs(widget.profile.kycStatus)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Puede corregir el estado global o el de cada archivo en cualquier momento. '
                'Para marcar «Aprobado» global, el servidor exige los 6 documentos cargados y aprobados uno a uno.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _kycDropdownValue(),
                decoration: InputDecoration(
                  labelText: 'Estado KYC global (admin)',
                  filled: true,
                  fillColor: AppColors.fieldFill,
                  border: OutlineInputBorder(
                    borderRadius: AppDecorations.radius12,
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: KycStatus.pendiente,
                    child: Text('Pendiente de envío'),
                  ),
                  DropdownMenuItem(
                    value: KycStatus.enRevision,
                    child: Text('En revisión MotoLink'),
                  ),
                  DropdownMenuItem(
                    value: KycStatus.aprobado,
                    child: Text('Aprobado'),
                  ),
                  DropdownMenuItem(
                    value: KycStatus.rechazado,
                    child: Text('Rechazado'),
                  ),
                ],
                onChanged: _savingKyc
                    ? null
                    : (v) {
                        if (v == null) return;
                        unawaited(_setAliadoKycGlobal(v));
                      },
              ),
              if (_savingKyc)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _openDocReviewSheet,
                icon: const Icon(Icons.fact_check_outlined, size: 20),
                label: const Text('Revisar documentación (por documento)'),
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: AppDecorations.radius12,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Uso del cupo (referencia)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_loadingExposure)
                        const LinearProgressIndicator(minHeight: 3)
                      else ...[
                        Text(
                          'Límite definido: ${lim != null ? '\$${lim.toStringAsFixed(2)}' : '—'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Compromiso en pedidos abiertos: \$${exp.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Imputado en entregas (crédito MotoLink): \$${cons.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          lim != null
                              ? 'Disponible estimado: \$${disp!.toStringAsFixed(2)}'
                              : 'Disponible estimado: —',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandBlue,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _limitCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Límite de crédito (USD)',
                  hintText: 'Ej: 50000.00',
                  filled: true,
                  fillColor: AppColors.fieldFill,
                  border: OutlineInputBorder(
                    borderRadius: AppDecorations.radius12,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar límite'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminKycSummaryChip extends StatelessWidget {
  const _AdminKycSummaryChip({required this.kycStatus});

  final String? kycStatus;

  @override
  Widget build(BuildContext context) {
    final label = KycStatus.labelEs(kycStatus);
    final Color bg;
    final Color fg;
    switch (kycStatus?.trim()) {
      case KycStatus.aprobado:
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF1B5E20);
        break;
      case KycStatus.rechazado:
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFB71C1C);
        break;
      case KycStatus.enRevision:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'KYC: $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.2,
        ),
      ),
    );
  }
}

String _formatReviewInstant(DateTime? utc) {
  if (utc == null) return '';
  final l = utc.toLocal();
  final mm = l.month.toString().padLeft(2, '0');
  final dd = l.day.toString().padLeft(2, '0');
  final hh = l.hour.toString().padLeft(2, '0');
  final min = l.minute.toString().padLeft(2, '0');
  return '$dd/$mm/${l.year} $hh:$min';
}

Future<String?> _promptRejectionNoteForDoc(
  BuildContext context, {
  required String docLabel,
  String? initialNote,
}) async {
  final c = TextEditingController(text: initialNote ?? '');
  final r = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dCtx) {
      return AlertDialog(
        title: Text('Rechazar: $docLabel'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'El aliado verá esta nota en su perfil para corregir el documento.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                maxLines: 6,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nota para el aliado',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final t = c.text.trim();
              if (t.length < 3) return;
              Navigator.pop(dCtx, t);
            },
            child: const Text('Registrar rechazo'),
          ),
        ],
      );
    },
  );
  return r;
}

class _KycReviewContextCard extends StatelessWidget {
  const _KycReviewContextCard({
    required this.title,
    required this.accent,
    required this.child,
  });

  final String title;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.4,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _KycMetaLine extends StatelessWidget {
  const _KycMetaLine(this.label, this.value, {this.monospace = false});

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontFamily: monospace ? 'monospace' : null,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocReviewTile extends StatelessWidget {
  const _DocReviewTile({
    required this.docType,
    required this.doc,
    this.olderVersions = const [],
    required this.busy,
    required this.onOpen,
    required this.onOpenVersion,
    required this.onApprove,
    required this.onReject,
    this.onEnRevision,
  });

  final String docType;
  final ProfileDocumentModel? doc;
  final List<ProfileDocumentModel> olderVersions;
  final bool busy;
  final VoidCallback onOpen;
  final Future<void> Function(ProfileDocumentModel d) onOpenVersion;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onEnRevision;

  @override
  Widget build(BuildContext context) {
    final has = doc != null;
    final rs = doc?.reviewStatus?.trim();
    final statusLabel = !has
        ? 'Sin archivo'
        : DocumentReviewStatus.labelEs(
            (rs == null || rs.isEmpty) ? DocumentReviewStatus.pendiente : rs,
          );
    final note = doc?.reviewNote?.trim();
    final reviewer = doc?.reviewerBusinessName?.trim();
    final reviewedLine = (doc?.reviewedAt != null)
        ? 'Última revisión: ${_formatReviewInstant(doc!.reviewedAt)}'
            '${reviewer != null && reviewer.isNotEmpty ? ' · $reviewer (MotoLink)' : ' · MotoLink'}'
        : null;

    final effectiveStatus = !has
        ? null
        : ((rs == null || rs.isEmpty) ? DocumentReviewStatus.pendiente : rs);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: kycDocumentReviewTileBorderColor(
                has: has, status: effectiveStatus),
            width: 1.4,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AliadoDocType.labelEs(docType),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              KycDocumentReviewStatusHighlight(
                statusLabel: statusLabel,
                hasFile: has,
                effectiveStatus: effectiveStatus,
              ),
              if (reviewedLine != null) ...[
                const SizedBox(height: 4),
                Text(
                  reviewedLine,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              if (has && doc!.fileName != null && doc!.fileName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Archivo: ${doc!.fileName!}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (olderVersions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Historial (comparar con la versión en revisión)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                ...olderVersions.map(
                  (h) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: busy
                            ? null
                            : () => unawaited(onOpenVersion(h)),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history,
                                size: 16,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      h.fileName ?? 'Archivo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${DocumentReviewStatus.labelEs(h.reviewStatus ?? DocumentReviewStatus.pendiente)} · '
                                      '${_formatReviewInstant(h.createdAt)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.open_in_new,
                                size: 16,
                                color: Colors.grey.shade700,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.sticky_note_2_outlined,
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (has)
                    OutlinedButton.icon(
                      onPressed: busy ? null : onOpen,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Abrir'),
                    ),
                  if (onApprove != null)
                    FilledButton.tonal(
                      onPressed: busy ? null : onApprove,
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Aprobar'),
                    ),
                  if (onReject != null)
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        foregroundColor: Colors.red.shade800,
                      ),
                      onPressed: busy ? null : onReject,
                      child: const Text('Rechazar…'),
                    ),
                  if (onEnRevision != null)
                    TextButton(
                      onPressed: busy ? null : onEnRevision,
                      child: const Text('Marcar en revisión'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
