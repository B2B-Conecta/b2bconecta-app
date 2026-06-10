import 'package:flutter/material.dart';

import '../models/document_review_status.dart';
import '../theme/app_theme.dart';
import 'kyc_status_highlight_widgets.dart';
import 'media_pick_action_chips.dart';

/// Fila compacta: documento KYC + estado + acciones cámara / galería / archivo.
class ProfileKycDocumentTile extends StatelessWidget {
  const ProfileKycDocumentTile({
    super.key,
    required this.title,
    required this.hasFile,
    required this.statusLabel,
    required this.effectiveStatus,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onPickFile,
    this.busy = false,
    this.actionsEnabled = true,
    this.reviewedHint,
    this.reviewNote,
  });

  final String title;
  final bool hasFile;
  final String statusLabel;
  final String? effectiveStatus;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onPickFile;
  final bool busy;
  final bool actionsEnabled;
  final String? reviewedHint;
  final String? reviewNote;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppDecorations.radius12,
        side: BorderSide(
          color: kycDocumentReviewTileBorderColor(
            has: hasFile,
            status: effectiveStatus,
          ),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            _CompactDocStatusLine(
              statusLabel: statusLabel,
              hasFile: hasFile,
              effectiveStatus: effectiveStatus,
            ),
            const SizedBox(height: 8),
            MediaPickActionChips(
              busy: busy,
              enabled: actionsEnabled,
              onCamera: onPickCamera,
              onGallery: onPickGallery,
              onFile: onPickFile,
            ),
            if (reviewedHint != null) ...[
              const SizedBox(height: 6),
              Text(
                reviewedHint!,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
            if (reviewNote != null && reviewNote!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                reviewNote!,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactDocStatusLine extends StatelessWidget {
  const _CompactDocStatusLine({
    required this.statusLabel,
    required this.hasFile,
    required this.effectiveStatus,
  });

  final String statusLabel;
  final bool hasFile;
  final String? effectiveStatus;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (effectiveStatus) {
      DocumentReviewStatus.aprobado => (
          Icons.check_circle_outline,
          AppColors.successGreen,
        ),
      DocumentReviewStatus.rechazado => (
          Icons.error_outline,
          Colors.red.shade700,
        ),
      DocumentReviewStatus.enRevision => (
          Icons.schedule,
          Colors.orange.shade800,
        ),
      _ when !hasFile => (Icons.upload_file_outlined, Colors.grey.shade600),
      _ => (Icons.description_outlined, AppColors.brandBlue),
    };
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            statusLabel,
            style: TextStyle(
              fontSize: 11,
              height: 1.25,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
