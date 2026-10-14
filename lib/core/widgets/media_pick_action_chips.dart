import 'package:flutter/foundation.dart';
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
    this.buttonLabel = 'Adjuntar',
    this.maxWidth = 280,
    this.iconOnly = false,
    this.compact = false,
    this.imagesOnly = false,
  });

  final VoidCallback? onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onFile;
  final VoidCallback? onDelete;
  final bool enabled;
  final bool busy;
  final String fileLabel;
  final String buttonLabel;
  final double maxWidth;
  final bool iconOnly;

  /// En la web abre solo imágenes. El comprobante deja el PDF incluido.
  final bool imagesOnly;

  /// Chips bajos, icono y texto en una línea, sin estirarse al ancho.
  final bool compact;

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
    final pick = active ? () => _pick(context) : null;
    if (iconOnly) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MediaPickIconButton(
            icon: Icons.add_a_photo_outlined,
            tooltip: buttonLabel,
            onTap: pick,
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

    final button = OutlinedButton.icon(
      onPressed: pick,
      icon: const Icon(Icons.attach_file, size: 18),
      label: Text(buttonLabel),
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? AppColors.brand : AppColors.textMuted,
        side: BorderSide(
          color: active ? AppColors.brand : AppColors.borderSubtle,
        ),
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        minimumSize: Size(compact ? 0 : double.infinity, compact ? 32 : 44),
      ),
    );
    if (compact) return button;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: button),
    );
  }

  void _pick(BuildContext context) {
    if (kIsWeb) {
      (imagesOnly ? onGallery ?? onFile : onFile ?? onGallery)?.call();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Adjuntar',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.of(ctx).pop();
                onCamera?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () {
                Navigator.of(ctx).pop();
                onGallery?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(imagesOnly ? 'Elegir archivo de imagen' : fileLabel),
              subtitle: Text(
                imagesOnly ? 'JPG, PNG o WEBP' : 'PDF, JPG, PNG o WEBP',
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                onFile?.call();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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

