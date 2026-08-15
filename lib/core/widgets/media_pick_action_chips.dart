import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/theme_controller.dart';

/// Acciones de captura/selección de medios.
///
/// Con [iconOnly] muestra solo iconos compactos (perfil, logos).
/// Sin él, muestra chips con etiqueta (KYC, comprobantes).
class MediaPickActionChips extends StatelessWidget {
  const MediaPickActionChips({
    super.key,
    required this.onCamera,
    required this.onGallery,
    required this.onFile,
    this.onDelete,
    this.enabled = true,
    this.busy = false,
    this.fileLabel = 'Archivo',
    this.maxWidth = 280,
    this.iconOnly = false,
  });

  final VoidCallback? onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onFile;
  final VoidCallback? onDelete;
  final bool enabled;
  final bool busy;
  final String fileLabel;
  final double maxWidth;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final active = enabled;
    if (iconOnly) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MediaPickIconButton(
            icon: Icons.photo_camera_outlined,
            tooltip: 'Cámara',
            onTap: active ? onCamera : null,
          ),
          const SizedBox(width: 4),
          _MediaPickIconButton(
            icon: Icons.photo_library_outlined,
            tooltip: 'Galería',
            onTap: active ? onGallery : null,
          ),
          const SizedBox(width: 4),
          _MediaPickIconButton(
            icon: Icons.upload_file_outlined,
            tooltip: fileLabel,
            onTap: active ? onFile : null,
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            _MediaPickIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Quitar',
              onTap: active ? onDelete : null,
              destructive: true,
            ),
          ],
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        children: [
          Expanded(
            child: _MediaPickChip(
              icon: Icons.photo_camera_outlined,
              label: 'Cámara',
              onTap: active ? onCamera : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _MediaPickChip(
              icon: Icons.photo_library_outlined,
              label: 'Galería',
              onTap: active ? onGallery : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _MediaPickChip(
              icon: Icons.upload_file_outlined,
              label: fileLabel,
              onTap: active ? onFile : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPickIconButton extends StatelessWidget {
  const _MediaPickIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final active = onTap != null;
        final accent = ThemeController.instance.isDark
            ? AppColors.brandAccent
            : AppColors.brandBlue;
        final color = !active
            ? AppColors.textMuted
            : destructive
                ? Colors.red.shade400
                : accent;

        return Tooltip(
          message: tooltip,
          child: Material(
            color: AppColors.fieldFill,
            shape: CircleBorder(
              side: BorderSide(
                color: active ? accent.withOpacity(0.45) : AppColors.borderSubtle,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Builder(
                builder: (context) {
                  final compact = MediaQuery.sizeOf(context).width < 600;
                  final box = compact ? 36.0 : 40.0;
                  return SizedBox(
                    width: box,
                    height: box,
                    child: Icon(icon, size: compact ? 18 : 20, color: color),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MediaPickChip extends StatelessWidget {
  const _MediaPickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    final borderColor =
        active ? AppColors.brandAccent.withOpacity(0.45) : AppColors.borderSubtle;
    final iconColor = active ? AppColors.brandAccent : AppColors.textMuted;
    final textColor = active ? AppColors.textPrimary : AppColors.textMuted;

    return Material(
      color: active ? AppColors.card : AppColors.surfaceTinted,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
