import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'motolink_pro_logo.dart';
import 'theme_mode_bubble.dart';

/// Altura del logo en AppBar: importadores (compacto) vs aliados (más visible).
abstract final class MotolinkAppBarLogoSizes {
  static const double importador = 36;
  static const double aliado = 44;
}

/// Barra superior: a la izquierda marca del usuario (logo opcional, nombre, rol);
/// a la derecha B2B Conecta + descripción; campana de notificaciones.
class MotolinkAppBar extends StatefulWidget implements PreferredSizeWidget {
  const MotolinkAppBar({
    super.key,
    this.currentUserProfile,
    this.onNotificationTap,
    this.extraActions,
    this.logoHeight = MotolinkAppBarLogoSizes.importador,
    this.unreadNotifications = 0,
  });

  /// Perfil autenticado (para marca izquierda). Si es null, solo se muestra B2B Conecta a la derecha.
  final ProfileModel? currentUserProfile;

  final VoidCallback? onNotificationTap;
  final List<Widget>? extraActions;
  final int unreadNotifications;

  /// Alto del logo B2B Conecta a la derecha y referencia del logo de usuario.
  final double logoHeight;

  @override
  Size get preferredSize =>
      Size.fromHeight(math.max(kToolbarHeight, logoHeight + 18));

  @override
  State<MotolinkAppBar> createState() => _MotolinkAppBarState();
}

class _MotolinkAppBarState extends State<MotolinkAppBar> {
  String? _signedLogoUrl;
  Object? _logoRequestKey;

  @override
  void didUpdateWidget(covariant MotolinkAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final path = widget.currentUserProfile?.logoStoragePath?.trim();
    final oldPath = oldWidget.currentUserProfile?.logoStoragePath?.trim();
    if (path != oldPath) {
      _resolveLogo(path);
    }
  }

  @override
  void initState() {
    super.initState();
    _resolveLogo(widget.currentUserProfile?.logoStoragePath?.trim());
  }

  void _resolveLogo(String? path) {
    if (path == null || path.isEmpty) {
      setState(() {
        _signedLogoUrl = null;
        _logoRequestKey = null;
      });
      return;
    }
    final key = Object();
    _logoRequestKey = key;
    SupabaseService.createSignedUrlForProfileLogo(path).then((url) {
      if (!mounted || _logoRequestKey != key) return;
      setState(() => _signedLogoUrl = url);
    }).catchError((_) {
      if (!mounted || _logoRequestKey != key) return;
      setState(() => _signedLogoUrl = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.currentUserProfile;
    final name = p?.businessName?.trim();
    final roleLabel = ProfileRoleLabels.labelEs(p?.role);
    final lh = widget.logoHeight;

    return AppBar(
      toolbarHeight: math.max(kToolbarHeight, lh + 14),
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (p != null) ...[
            Expanded(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _signedLogoUrl != null
                        ? Image.network(
                            _signedLogoUrl!,
                            width: lh,
                            height: lh,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                BusinessLogoPlaceholder(size: lh),
                          )
                        : BusinessLogoPlaceholder(size: lh),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (name != null && name.isNotEmpty)
                              ? name
                              : 'Mi cuenta',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          roleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ] else
            const Spacer(),
          if (MediaQuery.sizeOf(context).width >= 600)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'B2B Conecta',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.brandBlue,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Marketplace',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    color: AppColors.brandAccent,
                    height: 1.1,
                  ),
                ),
              ],
            ),
        ],
      ),
      actions: [
        ...?widget.extraActions,
        const Padding(
          padding: EdgeInsets.only(right: 2),
          child: ThemeModeBubble(compact: true),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_outlined),
                color: AppColors.textSecondary,
                onPressed: widget.onNotificationTap,
              ),
              if (widget.unreadNotifications > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      widget.unreadNotifications > 99
                          ? '99+'
                          : widget.unreadNotifications.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppColors.divider,
        ),
      ),
    );
  }
}
