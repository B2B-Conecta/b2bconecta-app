import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/media_pick_action_chips.dart';
import 'document_review_status.dart';
import 'kyc_status_highlight_widgets.dart';

/// Casilla compacta KYC: icono · título/estado · Subir.
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
    this.compactActions = true,
    this.showPickActions = true,
    this.busy = false,
    this.actionsEnabled = true,
    this.reviewedHint,
    this.reviewNote,
    this.requiredError = false,
    this.pickButtonLabel,
  });

  final String title;
  final bool hasFile;
  final String statusLabel;
  final String? effectiveStatus;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onPickFile;
  final VoidCallback? onView;
  final bool compactActions;
  final bool showPickActions;
  final bool busy;
  final bool actionsEnabled;
  final String? reviewedHint;
  final String? reviewNote;
  final bool requiredError;
  final String? pickButtonLabel;

  LucideGlyph get _glyph {
    final s = effectiveStatus?.trim().toLowerCase();
    if (s == DocumentReviewStatus.aprobado) return LucideGlyph.circleCheck;
    if (s == DocumentReviewStatus.rechazado) return LucideGlyph.circleAlert;
    if (hasFile) return LucideGlyph.fileText;
    return LucideGlyph.plus;
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final showRequired = requiredError && !hasFile;
    final borderColor = showRequired
        ? theme.brand.withOpacity(0.55)
        : kycDocumentReviewTileBorderColor(
            has: hasFile,
            status: effectiveStatus,
          );

    return Material(
      color: theme.surfaceCard,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: showRequired ? theme.brand : borderColor,
          width: showRequired ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.brandContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: LucideIcon(_glyph, size: 18, color: theme.brand),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    showRequired ? 'Campo obligatorio' : statusLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: showRequired
                          ? theme.brand
                          : theme.textSecondary,
                    ),
                  ),
                  if (reviewNote != null && reviewNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      reviewNote!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: theme.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (hasFile && onView != null)
              IconButton(
                tooltip: 'Ver',
                visualDensity: VisualDensity.compact,
                onPressed: busy ? null : onView,
                icon: LucideIcon(
                  LucideGlyph.eye,
                  size: 16,
                  color: theme.textSecondary,
                ),
              ),
            if (showPickActions)
              SizedBox(
                height: 34,
                child: MediaPickActionChips(
                  compact: true,
                  busy: busy,
                  enabled: actionsEnabled,
                  buttonLabel: pickButtonLabel ??
                      (hasFile ? 'Reemplazar' : 'Subir archivo'),
                  onCamera: onPickCamera,
                  onGallery: onPickGallery,
                  onFile: onPickFile,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
