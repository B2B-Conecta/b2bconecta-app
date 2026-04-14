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

/// Admin: lista de aliados con edición de `credit_limit`.
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

  @override
  void initState() {
    super.initState();
    _load();
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
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final p = _rows[i];
          return _AliadoCreditCard(
            key: ValueKey<String>(p.id),
            profile: p,
            onSaved: _load,
          );
        },
      ),
    );
  }
}

class _AliadoCreditCard extends StatefulWidget {
  const _AliadoCreditCard({
    super.key,
    required this.profile,
    required this.onSaved,
  });

  final ProfileModel profile;
  final Future<void> Function() onSaved;

  @override
  State<_AliadoCreditCard> createState() => _AliadoCreditCardState();
}

class _AliadoCreditCardState extends State<_AliadoCreditCard> {
  late final TextEditingController _limitCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final lim = widget.profile.creditLimit;
    _limitCtrl = TextEditingController(
      text: lim != null ? lim.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AliadoCreditCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.creditLimit != widget.profile.creditLimit) {
      final lim = widget.profile.creditLimit;
      _limitCtrl.text = lim != null ? lim.toStringAsFixed(2) : '';
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
                  ProfileDocumentModel? docFor(String t) {
                    for (final d in docs) {
                      if (d.docType == t) return d;
                    }
                    return null;
                  }

                  String? busyType;

                  Future<void> refreshDocs() async {
                    final fresh = await SupabaseService.fetchProfileDocumentsForAliado(
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
                    final d = docFor(type);
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
                                    doc: docFor(type),
                                    busy: busyType == type,
                                    onOpen: () async {
                                      final d = docFor(type);
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
                                    onApprove: docFor(type) == null
                                        ? null
                                        : () => setReview(
                                              type,
                                              DocumentReviewStatus.aprobado,
                                            ),
                                    onReject: docFor(type) == null
                                        ? null
                                        : () => unawaited(promptReject(type)),
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
    final cupoResumen = lim != null
        ? '\$${lim.toStringAsFixed(2)} USD'
        : 'Sin cupo asignado';

    return Material(
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openDocReviewSheet,
              icon: const Icon(Icons.fact_check_outlined, size: 20),
              label: const Text('Revisar documentación (por documento)'),
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
    required this.busy,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
  });

  final String docType;
  final ProfileDocumentModel? doc;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final has = doc != null;
    final rs = doc?.reviewStatus?.trim();
    final statusLabel = !has
        ? 'Sin archivo'
        : DocumentReviewStatus.labelEs(
            (rs == null || rs.isEmpty)
                ? DocumentReviewStatus.pendiente
                : rs,
          );
    final note = doc?.reviewNote?.trim();
    final reviewer = doc?.reviewerBusinessName?.trim();
    final reviewedLine = (doc?.reviewedAt != null)
        ? 'Última revisión: ${_formatReviewInstant(doc!.reviewedAt)}'
            '${reviewer != null && reviewer.isNotEmpty ? ' · $reviewer (MotoLink)' : ' · MotoLink'}'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 4),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
