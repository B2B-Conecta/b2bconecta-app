import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_entrepreneur_badge.dart';
import 'package:motolink_pro_app/features/kyc/document_review_status.dart';
import 'package:motolink_pro_app/features/kyc/profile_document_model.dart';
import 'package:motolink_pro_app/features/onboarding/entrepreneur_retailer.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Panel de prórrogas / docs diferidos / estado en el expediente admin.
class OwnerEntrepreneurControlPanel extends StatefulWidget {
  const OwnerEntrepreneurControlPanel({
    super.key,
    required this.profile,
    this.onChanged,
    this.onDeactivate,
    this.onHardDelete,
  });

  final ProfileModel profile;
  final VoidCallback? onChanged;
  final VoidCallback? onDeactivate;
  final VoidCallback? onHardDelete;

  @override
  State<OwnerEntrepreneurControlPanel> createState() =>
      _OwnerEntrepreneurControlPanelState();
}

class _OwnerEntrepreneurControlPanelState
    extends State<OwnerEntrepreneurControlPanel> {
  List<ProfileDocumentModel> _docs = const [];
  bool _loading = true;
  bool _busy = false;
  String? _busyDoc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OwnerEntrepreneurControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.entrepreneurStatus !=
            widget.profile.entrepreneurStatus) {
      _load();
    }
  }

  Future<void> _load() async {
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
      setState(() => _loading = false);
    }
  }

  ProfileDocumentModel? _docFor(String logicalType) {
    final storage = EntrepreneurDeferredKycDocs.toStorageDocType(logicalType);
    for (final d in _docs) {
      if (d.docType == storage || d.docType == logicalType) return d;
    }
    return null;
  }

  String _statusLabelEs() {
    final s = widget.profile.entrepreneurStatus?.trim().toLowerCase();
    final day = widget.profile.entrepreneurFirstPurchaseDayOfEight;
    return switch (s) {
      EntrepreneurStatus.activeTrial =>
        EntrepreneurFirstPurchaseProgress.adminProgressLabel(
          status: s,
          rpcDay: widget.profile.firstPurchaseBusinessDay,
          registeredAt: widget.profile.entrepreneurRegisteredAt,
          createdAt: widget.profile.createdAt,
        ),
      EntrepreneurStatus.pendingWarningPeriod ||
      EntrepreneurStatus.pendingFirstPurchaseAlert =>
        'En cuenta regresiva de 3 días (día $day de 8 hábiles)',
      EntrepreneurStatus.kycInProgress => 'KYC en progreso (8 semanas)',
      EntrepreneurStatus.expiredLocked =>
        widget.profile.isEntrepreneurFirstPurchaseLock
            ? 'Bloqueado · sin primera compra (8 días hábiles)'
            : 'Plazo 8 semanas caducado',
      EntrepreneurStatus.reactivationRequested => 'Solicitud de reactivación',
      EntrepreneurStatus.verifiedStandard => 'Verificado → estándar',
      _ => s ?? '—',
    };
  }

  Future<void> _extend(int weeks) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SupabaseService.adminExtendEntrepreneurKyc(
        aliadoId: widget.profile.id,
        extraDays: weeks * 7,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prórroga de $weeks semana(s) aplicada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo prorrogar: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickExtend() async {
    final theme = B2BThemeExtension.of(context);
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: theme.dialogSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        Widget tile(int weeks, String label) {
          return ListTile(
            title: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            subtitle: Text(
              '${weeks * 7} días · vuelve a kyc_in_progress',
              style: TextStyle(color: theme.textSecondary, fontSize: 12.5),
            ),
            onTap: () => Navigator.pop(ctx, weeks),
          );
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    'Otorgar prórroga de KYC',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                ),
                tile(2, '2 semanas'),
                tile(4, '4 semanas'),
                tile(8, '8 semanas'),
                if (!mobile) const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (choice != null) await _extend(choice);
  }

  Future<void> _approveDoc(String logicalType) async {
    final storage = EntrepreneurDeferredKycDocs.toStorageDocType(logicalType);
    setState(() => _busyDoc = logicalType);
    try {
      await SupabaseService.adminSetProfileDocumentReviewStatus(
        profileId: widget.profile.id,
        docType: storage,
        status: DocumentReviewStatus.aprobado,
      );
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _busyDoc = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.profile.isEntrepreneurRetailer &&
        widget.profile.entrepreneurStatus?.trim().isNotEmpty != true) {
      return const SizedBox.shrink();
    }

    final theme = B2BThemeExtension.of(context);
    final status = widget.profile.entrepreneurStatus?.trim().toLowerCase();
    final canExtend = status == EntrepreneurStatus.expiredLocked ||
        status == EntrepreneurStatus.reactivationRequested ||
        status == EntrepreneurStatus.kycInProgress;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LucideIcon(LucideGlyph.rocket, size: 18, color: theme.warningFg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Control Minorista-Emprendedor',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                  ),
                ),
              ),
              const AdminEntrepreneurBadge(compact: true),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Estado: ${_statusLabelEs()}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary,
            ),
          ),
          if (widget.profile.kycCompletionDeadline != null) ...[
            const SizedBox(height: 4),
            Text(
              'Plazo docs: ${widget.profile.kycCompletionDeadline!.toLocal()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: theme.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          if (canExtend)
            FilledButton.icon(
              onPressed: _busy ? null : _pickExtend,
              style: FilledButton.styleFrom(
                backgroundColor: theme.brand,
                foregroundColor: theme.surfaceCard,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _busy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.surfaceCard,
                      ),
                    )
                  : LucideIcon(
                      LucideGlyph.rotateCcw,
                      size: 16,
                      color: theme.surfaceCard,
                    ),
              label: const Text(
                'Otorgar prórroga de KYC',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            'Documentos comerciales (8 semanas)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: theme.brand,
                  ),
                ),
              ),
            )
          else
            for (final t in EntrepreneurDeferredKycDocs.requiredDeferred)
              _DocRow(
                title: EntrepreneurDeferredKycDocs.labelEs(t),
                doc: _docFor(t),
                busy: _busyDoc == t,
                onApprove: () => _approveDoc(t),
              ),
          if (widget.onDeactivate != null || widget.onHardDelete != null) ...[
            const SizedBox(height: 12),
            Text(
              'Cuenta',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.onDeactivate != null)
                  OutlinedButton.icon(
                    onPressed: widget.onDeactivate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textPrimary,
                      side: BorderSide(color: theme.borderStrong),
                    ),
                    icon: LucideIcon(
                      LucideGlyph.userMinus,
                      size: 16,
                      color: theme.textSecondary,
                    ),
                    label: const Text('Desactivar'),
                  ),
                if (widget.onHardDelete != null)
                  OutlinedButton.icon(
                    onPressed: widget.onHardDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .error
                            .withOpacity(0.45),
                      ),
                    ),
                    icon: LucideIcon(
                      LucideGlyph.trash2,
                      size: 16,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    label: const Text('Purgar cuenta'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.title,
    required this.doc,
    required this.busy,
    required this.onApprove,
  });

  final String title;
  final ProfileDocumentModel? doc;
  final bool busy;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final st = doc?.reviewStatus?.trim().toLowerCase();
    final label = switch (st) {
      DocumentReviewStatus.aprobado => 'Aprobado',
      DocumentReviewStatus.rechazado => 'Rechazado',
      DocumentReviewStatus.enRevision => 'En revisión',
      _ => doc == null ? 'Sin archivo' : 'Pendiente',
    };
    final approved = st == DocumentReviewStatus.aprobado;
    final canApprove = doc != null && !approved;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: approved ? theme.successFg : theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (canApprove)
                TextButton(
                  onPressed: busy ? null : onApprove,
                  child: busy
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.brand,
                          ),
                        )
                      : Text(
                          'Aprobar',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: theme.brand,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
