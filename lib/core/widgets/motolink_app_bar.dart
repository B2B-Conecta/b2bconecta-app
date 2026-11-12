import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'bandeja_sheet.dart';
import 'bcv_rate_badge.dart';
import 'header_icon_button.dart';
import 'lucide_icon.dart';
import 'messages_icon_button.dart';
import 'motolink_pro_logo.dart';
import 'theme_mode_bubble.dart';

/// Altura del logo en AppBar: importadores (compacto) vs aliados (más visible).
abstract final class MotolinkAppBarLogoSizes {
  static const double importador = 36;
  static const double aliado = 44;
}

/// Barra superior: marca a la izquierda.
/// A la derecha: acciones extra, bandeja (aliado) o mensajes+notificaciones, y tema.
class MotolinkAppBar extends StatefulWidget implements PreferredSizeWidget {
  const MotolinkAppBar({
    super.key,
    this.currentUserProfile,
    this.onNotificationTap,
    this.onMessagesTap,
    this.onProfileTap,
    this.extraActions,
    this.logoHeight = MotolinkAppBarLogoSizes.importador,
    this.unreadNotifications = 0,
    this.unreadMessages = 0,
    this.showBcvRate = true,
    this.branded = false,
    this.combineInbox,
  });

  /// Perfil autenticado (para marca izquierda). Si es null, solo se muestra B2B Conecta a la derecha.
  final ProfileModel? currentUserProfile;

  final VoidCallback? onNotificationTap;
  final VoidCallback? onMessagesTap;

  /// Tap en la foto de perfil (por defecto abre la pestaña Perfil del shell).
  final VoidCallback? onProfileTap;
  final List<Widget>? extraActions;
  final int unreadNotifications;
  final int unreadMessages;

  /// Icono de tasa BCV en vivo (aliado / importador / admin).
  final bool showBcvRate;

  /// Alto del logo B2B Conecta a la derecha y referencia del logo de usuario.
  final double logoHeight;

  /// Cabecera azul corporativa (catálogo aliado / maquetado B2B Conecta).
  final bool branded;

  /// Unifica mensajes y notificaciones en icono «Bandeja».
  /// Por defecto: activo para aliado.
  final bool? combineInbox;

  @override
  Size get preferredSize =>
      Size.fromHeight(math.max(kToolbarHeight + 8, logoHeight + 24));

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
    final branded = widget.branded;
    final titleColor = branded ? AppColors.white : AppColors.textPrimary;
    final subtitleColor =
        branded ? AppColors.white.withOpacity(0.78) : AppColors.textSecondary;
    final actionIconColor = branded ? AppColors.white : null;
    final useBandeja = widget.combineInbox ?? (p?.isAliado == true);
    final hasInbox =
        widget.onMessagesTap != null || widget.onNotificationTap != null;
    final inboxUnread =
        widget.unreadMessages + widget.unreadNotifications;

    return AppBar(
      toolbarHeight: math.max(kToolbarHeight + 8, lh + 20),
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      backgroundColor: branded ? AppColors.brandBlue : null,
      foregroundColor: branded ? AppColors.white : null,
      surfaceTintColor: branded ? Colors.transparent : null,
      elevation: branded ? 0 : null,
      systemOverlayStyle: branded
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            )
          : null,
      iconTheme:
          branded ? const IconThemeData(color: AppColors.white) : null,
      actionsIconTheme:
          branded ? const IconThemeData(color: AppColors.white) : null,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (p != null) ...[
            Expanded(
              child: Row(
                children: [
                  Tooltip(
                    message: 'Ir a perfil',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onProfileTap ??
                            MainShellTabController.navigateToProfileTab,
                        borderRadius: BorderRadius.circular(10),
                        child: ClipRRect(
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
                      ),
                    ),
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
                            fontSize: branded ? 15 : 14,
                            color: titleColor,
                            height: 1.15,
                          ),
                        ),
                        if (!branded)
                          Text(
                            roleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                              color: subtitleColor,
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
          if (!branded && MediaQuery.sizeOf(context).width >= 600)
            const Column(
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
        if (widget.showBcvRate && !branded)
          const Padding(
            padding: EdgeInsets.only(right: 2),
            child: Center(child: BcvRateBadge()),
          ),
        ...?widget.extraActions?.map(
          (action) => actionIconColor == null
              ? action
              : IconTheme(
                  data: IconThemeData(color: actionIconColor, size: 22),
                  child: action,
                ),
        ),
        if (useBandeja && hasInbox)
          HeaderIconButton(
            tooltip: 'Bandeja',
            onPressed: () => showBandejaSheet(
              context: context,
              onMessagesTap: widget.onMessagesTap,
              onNotificationTap: widget.onNotificationTap,
              unreadMessages: widget.unreadMessages,
              unreadNotifications: widget.unreadNotifications,
            ),
            count: inboxUnread,
            badgeColor: Colors.red,
            iconColor: actionIconColor,
            icon: Icons.inbox_outlined,
            iconWidget: LucideIcon(
              LucideGlyph.inbox,
              size: 22,
              color: actionIconColor,
            ),
          )
        else ...[
          if (widget.onMessagesTap != null)
            MessagesIconButton(
              onPressed: widget.onMessagesTap!,
              unreadCount: widget.unreadMessages,
              iconColor: actionIconColor,
            ),
          HeaderIconButton(
            tooltip: 'Notificaciones',
            onPressed: widget.onNotificationTap,
            count: widget.unreadNotifications,
            badgeColor: Colors.red,
            iconColor: actionIconColor,
            icon: Icons.notifications_none_outlined,
            iconWidget: LucideIcon(
              LucideGlyph.bell,
              size: 22,
              color: actionIconColor,
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 8),
          child: ThemeModeBubble(
            compact: true,
            iconColor: actionIconColor,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: branded
              ? AppColors.white.withOpacity(0.18)
              : AppColors.divider,
        ),
      ),
    );
  }
}
