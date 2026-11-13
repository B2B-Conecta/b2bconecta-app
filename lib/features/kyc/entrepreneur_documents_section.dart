import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/kyc/document_review_status.dart';
import 'package:motolink_pro_app/features/kyc/profile_document_model.dart';
import 'package:motolink_pro_app/features/kyc/profile_kyc_document_tile.dart';
import 'package:motolink_pro_app/features/onboarding/entrepreneur_retailer.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Grid de los 4 documentos comerciales diferidos (8 semanas).
class EntrepreneurDocumentsSection extends StatefulWidget {
  const EntrepreneurDocumentsSection({
    super.key,
    required this.profile,
    this.onChanged,
  });

  final ProfileModel profile;
  final VoidCallback? onChanged;

  @override
  State<EntrepreneurDocumentsSection> createState() =>
      _EntrepreneurDocumentsSectionState();
}

class _EntrepreneurDocumentsSectionState
    extends State<EntrepreneurDocumentsSection> {
  List<ProfileDocumentModel> _docs = const [];
  bool _loading = true;
  String? _busyType;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EntrepreneurDocumentsSection oldWidget) {
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
      final docs = await SupabaseService.fetchMyProfileDocuments();
      if (!mounted) return;
      setState(() {
        _docs = docs;
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
      if (!d.isCurrent) continue;
      if (d.docType == storage || d.docType == logicalType) return d;
    }
    return null;
  }

  String _statusLabel(ProfileDocumentModel? doc) {
    if (doc == null) return 'Pendiente de envío';
    final st = doc.reviewStatus?.trim().toLowerCase();
    if (st == null || st.isEmpty || st == DocumentReviewStatus.pendiente) {
      return 'Pendiente de envío';
    }
    if (st == DocumentReviewStatus.enRevision) return 'En revisión';
    if (st == DocumentReviewStatus.aprobado) return 'Aprobado';
    if (st == DocumentReviewStatus.rechazado) return 'Rechazado';
    return DocumentReviewStatus.labelEs(st);
  }

  Color _badgeColor(B2BThemeExtension theme, String? status, bool hasFile) {
    final st = status?.trim().toLowerCase();
    if (st == DocumentReviewStatus.aprobado) return theme.successFg;
    if (st == DocumentReviewStatus.rechazado) {
      return Theme.of(context).colorScheme.error;
    }
    if (st == DocumentReviewStatus.enRevision) return theme.brand;
    return theme.textMuted;
  }

  Future<void> _upload(String logicalType) async {
    final picked = await pickKycDocument(channel: DocumentPickChannel.file);
    if (picked == null || !mounted) return;
    final storage = EntrepreneurDeferredKycDocs.toStorageDocType(logicalType);
    setState(() => _busyType = logicalType);
    try {
      await SupabaseService.uploadMyProfileDocument(
        docType: storage,
        bytes: picked.bytes,
        fileName: picked.fileName,
      );
      if (!mounted) return;
      final theme = B2BThemeExtension.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Documento subido.',
            style: TextStyle(color: theme.surfaceCard),
          ),
          backgroundColor: theme.brand,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyType = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
    final deadline = widget.profile.kycCompletionDeadline;
    final daysLeft =
        deadline?.difference(DateTime.now()).inDays.clamp(0, 9999);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                LucideIcon(
                  LucideGlyph.clipboardCheck,
                  size: 20,
                  color: theme.brand,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Documentación comercial (8 semanas)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              daysLeft == null
                  ? 'Sube los 4 documentos requeridos. Disponible también si tu cuenta está en pausa o reactivación.'
                  : 'Quedan $daysLeft días del plazo. Disponible también en pausa o reactivación.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.brand,
                    ),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = mobile || constraints.maxWidth < 560 ? 1 : 2;
                  const types = EntrepreneurDeferredKycDocs.requiredDeferred;
                  final rows = <Widget>[];
                  for (var i = 0; i < types.length; i += cols) {
                    final cells = <Widget>[];
                    for (var c = 0; c < cols; c++) {
                      if (c > 0) cells.add(const SizedBox(width: 10));
                      if (i + c < types.length) {
                        cells.add(
                          Expanded(child: _tile(types[i + c], theme)),
                        );
                      } else {
                        cells.add(const Expanded(child: SizedBox.shrink()));
                      }
                    }
                    rows.add(
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i + cols < types.length ? 10 : 0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: cells,
                        ),
                      ),
                    );
                  }
                  return Column(children: rows);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String logicalType, B2BThemeExtension theme) {
    final doc = _docFor(logicalType);
    final has = doc != null;
    final st = has
        ? ((doc.reviewStatus?.trim().isEmpty ?? true)
            ? DocumentReviewStatus.pendiente
            : doc.reviewStatus)
        : null;
    final canReplace = DocumentReviewStatus.ownerCanReplace(st) ||
        st == DocumentReviewStatus.rechazado ||
        !has;
    final badge = _statusLabel(doc);
    final badgeColor = _badgeColor(theme, st, has);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badgeColor.withOpacity(0.35)),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: badgeColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        ProfileKycDocumentTile(
          title: EntrepreneurDeferredKycDocs.labelEs(logicalType),
          hasFile: has,
          statusLabel: has ? 'Archivo cargado' : 'Sin archivo',
          effectiveStatus: st,
          reviewNote: st == DocumentReviewStatus.rechazado
              ? (doc?.reviewNote?.trim().isNotEmpty == true
                  ? doc!.reviewNote
                  : 'Rechazado: corrige y vuelve a subir.')
              : doc?.reviewNote,
          busy: _busyType == logicalType,
          showPickActions: canReplace,
          actionsEnabled: canReplace && _busyType == null,
          onPickCamera: () => _upload(logicalType),
          onPickGallery: () => _upload(logicalType),
          onPickFile: () => _upload(logicalType),
        ),
      ],
    );
  }
}
