import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/stored_file_actions.dart';
import 'package:motolink_pro_app/core/utils/stored_file_frame.dart';
import 'package:motolink_pro_app/core/utils/stored_file_name.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/kyc/aliado_doc_type.dart';
import 'package:motolink_pro_app/features/kyc/document_review_status.dart';
import 'package:motolink_pro_app/features/kyc/profile_document_model.dart';

/// Popup lightbox moderno con zoom (pinch / botones) para documentos KYC.
Future<void> showKycDocumentPreviewSheet(
  BuildContext context, {
  required ProfileDocumentModel doc,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar vista previa',
    barrierColor: Colors.black.withOpacity(0.72),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim, secondary) {
      return _KycLightboxDialog(doc: doc);
    },
    transitionBuilder: (ctx, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _KycLightboxDialog extends StatefulWidget {
  const _KycLightboxDialog({required this.doc});

  final ProfileDocumentModel doc;

  @override
  State<_KycLightboxDialog> createState() => _KycLightboxDialogState();
}

class _KycLightboxDialogState extends State<_KycLightboxDialog> {
  final _viewer = TransformationController();
  String? _url;
  Object? _error;
  double _rotation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _viewer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final url = await SupabaseService.createSignedUrlForProfileDocument(
        widget.doc.storagePath,
      );
      if (!mounted) return;
      setState(() => _url = url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  String get _title {
    final name = widget.doc.fileName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return AliadoDocType.labelEs(widget.doc.docType);
  }

  void _zoomBy(double factor) {
    final m = _viewer.value.clone();
    final next = m.getMaxScaleOnAxis() * factor;
    final clamped = next.clamp(0.5, 4.0);
    final ratio = clamped / m.getMaxScaleOnAxis();
    _viewer.value = m.scaled(ratio);
    setState(() {});
  }

  void _resetView() {
    _viewer.value = Matrix4.identity();
    setState(() => _rotation = 0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = math.min(size.width - 32, 860.0);
    final maxH = size.height * 0.9;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          child: Material(
            color: const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(AdminUsersChrome.sheetRadius),
            clipBehavior: Clip.antiAlias,
            elevation: 28,
            shadowColor: Colors.black.withOpacity(0.45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AliadoDocType.labelEs(widget.doc.docType),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusPill(status: widget.doc.reviewStatus),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: LucideIcon(
                          LucideGlyph.close,
                          size: 20,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.doc.reviewNote?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'Motivo: ${widget.doc.reviewNote!.trim()}',
                      style: const TextStyle(
                        color: Color(0xFFFECACA),
                        fontSize: 12,
                      ),
                    ),
                  ),
                Expanded(
                  child: ColoredBox(
                    color: Colors.black,
                    child: _error != null
                        ? Center(
                            child: Text(
                              'No se pudo cargar: $_error',
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _url == null
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : InteractiveViewer(
                                transformationController: _viewer,
                                minScale: 0.5,
                                maxScale: 4,
                                child: Center(
                                  child: Transform.rotate(
                                    angle: _rotation * math.pi / 180,
                                    child: _PreviewBody(
                                      url: _url!,
                                      title: _title,
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ),
                Container(
                  color: const Color(0xFF111827),
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Alejar',
                        onPressed: _url == null ? null : () => _zoomBy(1 / 1.25),
                        icon: LucideIcon(
                          LucideGlyph.minus,
                          size: 18,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Acercar',
                        onPressed: _url == null ? null : () => _zoomBy(1.25),
                        icon: LucideIcon(
                          LucideGlyph.plus,
                          size: 18,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Rotar',
                        onPressed: _url == null
                            ? null
                            : () => setState(() => _rotation += 90),
                        icon: LucideIcon(
                          LucideGlyph.refreshCw,
                          size: 18,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Restablecer',
                        onPressed: _url == null ? null : _resetView,
                        icon: LucideIcon(
                          LucideGlyph.maximize2,
                          size: 18,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const Spacer(),
                      if (_url != null)
                        TextButton(
                          onPressed: () => openStoredFileExternally(_url!),
                          child: Text(
                            'Abrir externo',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewBody extends StatelessWidget {
  const _PreviewBody({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    final isImage = storedFileIsImage(title, url);
    if (isImage) {
      return Image.network(url, fit: BoxFit.contain);
    }
    final frame = buildStoredFileFrame(url);
    return frame ??
        TextButton(
          onPressed: () => openStoredFileExternally(url),
          child: const Text(
            'Abrir archivo',
            style: TextStyle(color: Colors.white),
          ),
        );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final st = status?.trim();
    final Color bg;
    final Color fg;
    switch (st) {
      case DocumentReviewStatus.aprobado:
        bg = const Color(0xFF14532D);
        fg = const Color(0xFF86EFAC);
      case DocumentReviewStatus.rechazado:
        bg = const Color(0xFF7F1D1D);
        fg = const Color(0xFFFECACA);
      case DocumentReviewStatus.enRevision:
        bg = const Color(0xFF1E3A8A);
        fg = const Color(0xFFBFDBFE);
      default:
        bg = const Color(0xFF334155);
        fg = const Color(0xFFE2E8F0);
    }
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        DocumentReviewStatus.labelEs(st ?? DocumentReviewStatus.pendiente),
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
