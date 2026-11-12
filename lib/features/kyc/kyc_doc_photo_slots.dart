import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/document_pick_utils.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/kyc/aliado_doc_type.dart';
import 'package:motolink_pro_app/features/kyc/document_review_status.dart';
import 'package:motolink_pro_app/features/kyc/kyc_document_preview_sheet.dart';
import 'package:motolink_pro_app/features/kyc/profile_document_model.dart';

/// Bloque uniforme: un documento lógico con hasta 3 fotos + review.
class KycDocPhotoSlots extends StatelessWidget {
  const KycDocPhotoSlots({
    super.key,
    required this.baseType,
    required this.docsByType,
    required this.busyType,
    required this.canUpload,
    required this.canReview,
    required this.onUpload,
    required this.onApprove,
    required this.onReject,
  });

  final String baseType;
  final Map<String, ProfileDocumentModel> docsByType;
  final String? busyType;
  final bool canUpload;
  final bool canReview;
  final Future<void> Function(String docType, DocumentPickChannel channel)
      onUpload;
  final Future<void> Function(String docType) onApprove;
  final Future<void> Function(String docType) onReject;

  List<String> get _slots => AliadoDocType.photoSlotsFor(baseType);

  int get _filled => _slots.where(docsByType.containsKey).length;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final isStore = AliadoDocType.isStorePhoto(baseType);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AliadoDocType.groupLabelEs(baseType),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isStore
                          ? 'Fachada e interior · máx. 3 fotos'
                          : 'Hasta 3 fotos / páginas de este documento',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_filled / ${AliadoDocType.maxPhotosPerDoc}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _slots.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _SlotThumb(
                    docType: _slots[i],
                    index: i + 1,
                    doc: docsByType[_slots[i]],
                    busy: busyType == _slots[i],
                    canUpload: canUpload,
                    canReview: canReview,
                    onUpload: onUpload,
                    onApprove: onApprove,
                    onReject: onReject,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotThumb extends StatefulWidget {
  const _SlotThumb({
    required this.docType,
    required this.index,
    required this.doc,
    required this.busy,
    required this.canUpload,
    required this.canReview,
    required this.onUpload,
    required this.onApprove,
    required this.onReject,
  });

  final String docType;
  final int index;
  final ProfileDocumentModel? doc;
  final bool busy;
  final bool canUpload;
  final bool canReview;
  final Future<void> Function(String docType, DocumentPickChannel channel)
      onUpload;
  final Future<void> Function(String docType) onApprove;
  final Future<void> Function(String docType) onReject;

  @override
  State<_SlotThumb> createState() => _SlotThumbState();
}

class _SlotThumbState extends State<_SlotThumb> {
  String? _thumbUrl;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _SlotThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doc?.storagePath != widget.doc?.storagePath) _resolve();
  }

  Future<void> _resolve() async {
    final path = widget.doc?.storagePath;
    if (path == null || path.isEmpty) {
      if (mounted) setState(() => _thumbUrl = null);
      return;
    }
    try {
      final url =
          await SupabaseService.createSignedUrlForProfileDocument(path);
      if (mounted) setState(() => _thumbUrl = url);
    } catch (_) {
      if (mounted) setState(() => _thumbUrl = null);
    }
  }

  Color _statusColor() {
    switch (widget.doc?.reviewStatus?.trim()) {
      case DocumentReviewStatus.aprobado:
        return const Color(0xFF16A34A);
      case DocumentReviewStatus.rechazado:
        return const Color(0xFFB91C1C);
      case DocumentReviewStatus.enRevision:
        return AdminUsersChrome.brand;
      default:
        return AdminUsersChrome.muted;
    }
  }

  Future<void> _pick() async {
    // En web el selector nativo ya basta; el sheet móvil sobra.
    if (kIsWeb) {
      await widget.onUpload(widget.docType, DocumentPickChannel.file);
      return;
    }

    final theme = B2BThemeExtension.of(context);
    final channel = await showModalBottomSheet<DocumentPickChannel>(
      context: context,
      backgroundColor: theme.dialogSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminUsersChrome.sheetRadius),
        ),
      ),
      builder: (ctx) {
        final t = B2BThemeExtension.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: LucideIcon(
                    LucideGlyph.image,
                    size: 20,
                    color: t.brand,
                  ),
                  title: Text(
                    'Galería',
                    style: TextStyle(color: t.textPrimary),
                  ),
                  onTap: () => Navigator.pop(ctx, DocumentPickChannel.gallery),
                ),
                ListTile(
                  leading: LucideIcon(
                    LucideGlyph.plus,
                    size: 20,
                    color: t.brand,
                  ),
                  title: Text(
                    'Cámara',
                    style: TextStyle(color: t.textPrimary),
                  ),
                  onTap: () => Navigator.pop(ctx, DocumentPickChannel.camera),
                ),
                ListTile(
                  leading: LucideIcon(
                    LucideGlyph.inbox,
                    size: 20,
                    color: t.brand,
                  ),
                  title: Text(
                    'Archivo / PDF',
                    style: TextStyle(color: t.textPrimary),
                  ),
                  onTap: () => Navigator.pop(ctx, DocumentPickChannel.file),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (channel == null) return;
    await widget.onUpload(widget.docType, channel);
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final doc = widget.doc;
    final has = doc != null;
    final st = doc?.reviewStatus?.trim();
    final canApprove =
        widget.canReview && has && st != DocumentReviewStatus.aprobado;
    final canReject =
        widget.canReview && has && st != DocumentReviewStatus.rechazado;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Material(
            color: theme.surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.busy
                  ? null
                  : () async {
                      if (has) {
                        await showKycDocumentPreviewSheet(context, doc: doc);
                      } else if (widget.canUpload) {
                        await _pick();
                      }
                    },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_thumbUrl != null)
                    Image.network(_thumbUrl!, fit: BoxFit.cover)
                  else
                    Center(
                      child: LucideIcon(
                        has ? LucideGlyph.image : LucideGlyph.plus,
                        size: 22,
                        color: theme.textSecondary,
                      ),
                    ),
                  if (widget.busy)
                    ColoredBox(
                      color: theme.dialogSurface.withOpacity(0.55),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.textPrimary.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.index}',
                        style: TextStyle(
                          color: theme.surfaceCard,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (has)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _statusColor(),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.surfaceCard,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  if (has)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: LucideIcon(
                        LucideGlyph.maximize2,
                        size: 14,
                        color: theme.surfaceCard,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!has && widget.canUpload)
          TextButton(
            onPressed: widget.busy ? null : _pick,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AdminUsersChrome.brand,
            ),
            child: const Text('Subir', style: TextStyle(fontSize: 11)),
          )
        else if (has && (canApprove || canReject))
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (canApprove)
                IconButton(
                  tooltip: 'Aprobar',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.busy
                      ? null
                      : () => widget.onApprove(widget.docType),
                  icon: const LucideIcon(
                    LucideGlyph.check,
                    size: 16,
                    color: Color(0xFF16A34A),
                  ),
                ),
              if (canReject)
                IconButton(
                  tooltip: 'Rechazar',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.busy
                      ? null
                      : () => widget.onReject(widget.docType),
                  icon: const LucideIcon(
                    LucideGlyph.close,
                    size: 16,
                    color: Color(0xFFB91C1C),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
