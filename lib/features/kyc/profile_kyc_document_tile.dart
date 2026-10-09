import 'package:flutter/material.dart';

import 'document_review_status.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'kyc_status_highlight_widgets.dart';
import 'package:motolink_pro_app/core/widgets/media_pick_action_chips.dart';

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
    this.onView,
    this.compactActions = false,
    this.showPickActions = true,
    this.busy = false,
    this.actionsEnabled = true,
    this.reviewedHint,
    this.reviewNote,
    this.requiredError = false,
  });

  final String title;
  final bool hasFile;
  final String statusLabel;
  final String? effectiveStatus;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onPickFile;

  /// Abre el archivo ya cargado. Solo se muestra si hay documento.
  final VoidCallback? onView;

  /// Cámara, galería y archivo en chips bajos. El expediente del admin lo usa.
  final bool compactActions;

  /// Oculta cámara, galería y archivo. Un documento aprobado o en revisión no se reemplaza.
  final bool showPickActions;
  final bool busy;
  final bool actionsEnabled;
  final String? reviewedHint;
  final String? reviewNote;

  /// Sin archivo tras validar envío/guardado: borde y texto en rojo.
  final bool requiredError;

  @override
  Widget build(BuildContext context) {
    final showRequired = requiredError && !hasFile;
    final errorColor = Colors.red.shade700;
    return Material(
      color: AppColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppDecorations.radius12,
        side: BorderSide(
          color: showRequired
              ? Colors.red.shade400
              : kycDocumentReviewTileBorderColor(
                  has: hasFile,
                  status: effectiveStatus,
                ),
          width: showRequired ? 1.5 : 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: showRequired ? errorColor : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            _CompactDocStatusLine(
              statusLabel: showRequired ? 'Campo obligatorio' : statusLabel,
              hasFile: hasFile,
              effectiveStatus: effectiveStatus,
              requiredError: showRequired,
            ),
            if (hasFile && onView != null && !compactActions) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  foregroundColor: AppColors.brand,
                ),
                onPressed: busy ? null : onView,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Ver archivo'),
              ),
            ],
            if (showPickActions || (compactActions && hasFile && onView != null)) ...[
              const SizedBox(height: 8),
              if (compactActions)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (hasFile && onView != null)
                      _CompactViewChip(
                        onPressed: busy ? null : onView,
                      ),
                    if (showPickActions)
                      MediaPickActionChips(
                        compact: true,
                        busy: busy,
                        enabled: actionsEnabled,
                        onCamera: onPickCamera,
                        onGallery: onPickGallery,
                        onFile: onPickFile,
                      ),
                  ],
                )
              else
                MediaPickActionChips(
                  busy: busy,
                  enabled: actionsEnabled,
                  onCamera: onPickCamera,
                  onGallery: onPickGallery,
                  onFile: onPickFile,
                ),
            ],
            if (reviewedHint != null) ...[
              const SizedBox(height: 6),
              Text(
                reviewedHint!,
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
            if (reviewNote != null && reviewNote!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                reviewNote!,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: AppColors.brandBlue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactViewChip extends StatelessWidget {
  const _CompactViewChip({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 28),
        foregroundColor: AppColors.brand,
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.visibility_outlined, size: 14),
      label: const Text(
        'Ver archivo',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CompactDocStatusLine extends StatelessWidget {
  const _CompactDocStatusLine({
    required this.statusLabel,
    required this.hasFile,
    required this.effectiveStatus,
    this.requiredError = false,
  });

  final String statusLabel;
  final bool hasFile;
  final String? effectiveStatus;
  final bool requiredError;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = requiredError
        ? (Icons.error_outline, Colors.red.shade700)
        : switch (effectiveStatus) {
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
                AppColors.brandAccent,
              ),
            _ when !hasFile => (
                Icons.upload_file_outlined,
                AppColors.textSecondary,
              ),
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
