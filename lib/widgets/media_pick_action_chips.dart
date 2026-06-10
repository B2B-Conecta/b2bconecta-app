import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fila compacta y uniforme: Cámara · Galería · Archivo.
class MediaPickActionChips extends StatelessWidget {
  const MediaPickActionChips({
    super.key,
    required this.onCamera,
    required this.onGallery,
    required this.onFile,
    this.enabled = true,
    this.busy = false,
    this.fileLabel = 'Archivo',
    this.maxWidth = 280,
  });

  final VoidCallback? onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onFile;
  final bool enabled;
  final bool busy;
  final String fileLabel;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        height: 44,
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
        active ? AppColors.brand.withOpacity(0.4) : Colors.grey.shade300;
    final iconColor = active ? AppColors.brand : Colors.grey.shade500;
    final textColor = active ? AppColors.textPrimary : Colors.grey.shade500;

    return Material(
      color: active ? Colors.white : Colors.grey.shade50,
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
