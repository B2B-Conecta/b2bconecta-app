import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';
import 'shell_destination.dart';

/// Acciones del menú de cuenta en el footer del shell.
enum ShellUserMenuAction {
  profile,
  accountSettings,
  notificationPrefs,
  signOut,
}

/// Nombre visible + badge de rol para el footer de cuenta.
abstract final class ShellUserIdentity {
  static String displayName(ProfileModel profile) {
    final legal = profile.legalContactName?.trim();
    if (legal != null && legal.isNotEmpty) return legal;
    final business = profile.businessName?.trim();
    if (business != null && business.isNotEmpty) return business;
    final email = profile.email?.trim();
    if (email != null && email.isNotEmpty) {
      final at = email.indexOf('@');
      return at > 0 ? email.substring(0, at) : email;
    }
    return 'Admin B2B';
  }

  static String roleBadge(ProfileModel profile) {
    if (profile.isOwner) return 'Super Admin';
    final role = profile.role?.trim().toLowerCase();
    if (role == 'administrador') return 'Administrador';
    return ProfileRoleLabels.labelEs(profile.role);
  }

  static String initials(ProfileModel profile) {
    final name = displayName(profile);
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'AD';
    if (parts.length == 1) {
      final w = parts.first;
      return w.substring(0, w.length >= 2 ? 2 : 1).toUpperCase();
    }
    return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
  }
}

/// Tarjeta de usuario + menú flotante (rail / drawer).
class ShellUserMenu extends StatefulWidget {
  const ShellUserMenu({
    super.key,
    required this.profile,
    required this.onAction,
    this.chrome = DesktopShellChrome.darkCorporate,
    this.extended = true,
    this.signingOut = false,

    /// Si es true, el tap abre Ajustes/Perfil sin menú intermedio (admin).
    this.openSettingsOnTap = false,

    /// Resalta la tarjeta cuando Perfil/Ajustes está activo.
    this.selected = false,
  });

  final ProfileModel profile;
  final ValueChanged<ShellUserMenuAction> onAction;
  final DesktopShellChrome chrome;
  final bool extended;
  final bool signingOut;
  final bool openSettingsOnTap;
  final bool selected;

  @override
  State<ShellUserMenu> createState() => _ShellUserMenuState();
}

class _ShellUserMenuState extends State<ShellUserMenu> {
  String? _logoUrl;
  Object? _logoKey;

  @override
  void initState() {
    super.initState();
    _resolveLogo(widget.profile.logoStoragePath?.trim());
  }

  @override
  void didUpdateWidget(covariant ShellUserMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    final path = widget.profile.logoStoragePath?.trim();
    if (path != oldWidget.profile.logoStoragePath?.trim()) {
      _resolveLogo(path);
    }
  }

  void _resolveLogo(String? path) {
    if (path == null || path.isEmpty) {
      setState(() {
        _logoUrl = null;
        _logoKey = null;
      });
      return;
    }
    final key = Object();
    _logoKey = key;
    SupabaseService.createSignedUrlForProfileLogo(path).then((url) {
      if (!mounted || _logoKey != key) return;
      setState(() => _logoUrl = url);
    }).catchError((_) {
      if (!mounted || _logoKey != key) return;
      setState(() => _logoUrl = null);
    });
  }

  Future<void> _openMenu() async {
    if (widget.signingOut) return;
    if (widget.openSettingsOnTap) {
      widget.onAction(ShellUserMenuAction.accountSettings);
      return;
    }
    final action = await showShellUserAccountMenu(
      context: context,
      signingOut: widget.signingOut,
    );
    if (action != null && mounted) {
      widget.onAction(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final name = ShellUserIdentity.displayName(widget.profile);
    final badge = ShellUserIdentity.roleBadge(widget.profile);
    final initials = ShellUserIdentity.initials(widget.profile);
    final cardBg = widget.selected ? theme.brandContainer : theme.sidebarFooterBg;
    final border = widget.selected
        ? theme.brand.withOpacity(0.45)
        : theme.sidebarFooterBorder;
    final labelColor = theme.textPrimary;
    final muted = theme.textSecondary;
    final badgeBg = theme.brandContainer;
    final badgeFg = widget.profile.isOwner ? theme.successFg : theme.brand;

    final avatar = ShellUserAvatar(
      size: 40,
      initials: initials,
      imageUrl: _logoUrl,
      borderColor: border,
      fillColor: theme.surfaceCard,
      foreground: labelColor,
    );

    if (!widget.extended) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Tooltip(
          message: '$name · $badge',
          child: Material(
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: border,
                width: widget.selected ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              onTap: _openMenu,
              borderRadius: BorderRadius.circular(12),
              hoverColor: theme.brand.withOpacity(0.08),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(child: avatar),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: theme.border,
          ),
          const SizedBox(height: 10),
          Material(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _openMenu,
              borderRadius: BorderRadius.circular(12),
              hoverColor: theme.brand.withOpacity(0.08),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: border,
                    width: widget.selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: labelColor,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: badgeFg.withOpacity(0.35),
                              ),
                            ),
                            child: Text(
                              badge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: badgeFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    LucideIcon(
                      widget.openSettingsOnTap
                          ? LucideGlyph.settings
                          : LucideGlyph.chevronsUpDown,
                      size: 16,
                      color: widget.selected ? theme.brand : muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Muestra el menú rápido de cuenta (mismo que el footer del rail).
Future<ShellUserMenuAction?> showShellUserAccountMenu({
  required BuildContext context,
  bool signingOut = false,
}) {
  final box = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) {
    return Future<ShellUserMenuAction?>.value(null);
  }

  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final rect = Rect.fromLTWH(
    topLeft.dx,
    topLeft.dy,
    box.size.width,
    box.size.height,
  );
  final position = RelativeRect.fromRect(rect, Offset.zero & overlay.size);
  final theme = B2BThemeExtension.of(context);
  final danger = Theme.of(context).colorScheme.error;

  PopupMenuItem<ShellUserMenuAction> item(
    ShellUserMenuAction value,
    String label,
    LucideGlyph glyph, {
    bool isDanger = false,
  }) {
    final color = isDanger ? danger : theme.textPrimary;
    return PopupMenuItem<ShellUserMenuAction>(
      value: value,
      height: 44,
      child: Row(
        children: [
          LucideIcon(glyph, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  return showMenu<ShellUserMenuAction>(
    context: context,
    position: position,
    elevation: 16,
    color: theme.dialogSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: theme.borderStrong),
    ),
    items: [
      item(
        ShellUserMenuAction.profile,
        'Ajustes del sistema',
        LucideGlyph.settings,
      ),
      item(
        ShellUserMenuAction.accountSettings,
        'Cuenta y seguridad',
        LucideGlyph.user,
      ),
      item(
        ShellUserMenuAction.notificationPrefs,
        'Preferencias de notificaciones',
        LucideGlyph.bell,
      ),
      const PopupMenuDivider(height: 10),
      item(
        ShellUserMenuAction.signOut,
        signingOut ? 'Cerrando sesión…' : 'Cerrar sesión',
        LucideGlyph.logOut,
        isDanger: true,
      ),
    ],
  );
}

/// Avatar circular del perfil activo (rail / top bar).
class ShellUserAvatar extends StatelessWidget {
  const ShellUserAvatar({
    super.key,
    required this.size,
    required this.initials,
    required this.borderColor,
    required this.fillColor,
    required this.foreground,
    this.imageUrl,
  });

  final double size;
  final String initials;
  final String? imageUrl;
  final Color borderColor;
  final Color fillColor;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: fillColor,
        backgroundImage:
            url != null && url.isNotEmpty ? NetworkImage(url) : null,
        onBackgroundImageError:
            url != null && url.isNotEmpty ? (_, __) {} : null,
        child: url != null && url.isNotEmpty
            ? null
            : Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.32,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
      ),
    );
  }
}

/// Avatar 36px que abre el menú de cuenta (header admin).
class ShellUserAvatarButton extends StatefulWidget {
  const ShellUserAvatarButton({
    super.key,
    required this.profile,
    required this.onAction,
    this.size = 36,
    this.signingOut = false,
  });

  final ProfileModel profile;
  final ValueChanged<ShellUserMenuAction> onAction;
  final double size;
  final bool signingOut;

  @override
  State<ShellUserAvatarButton> createState() => _ShellUserAvatarButtonState();
}

class _ShellUserAvatarButtonState extends State<ShellUserAvatarButton> {
  String? _logoUrl;
  Object? _logoKey;

  @override
  void initState() {
    super.initState();
    _resolveLogo(widget.profile.logoStoragePath?.trim());
  }

  @override
  void didUpdateWidget(covariant ShellUserAvatarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final path = widget.profile.logoStoragePath?.trim();
    if (path != oldWidget.profile.logoStoragePath?.trim()) {
      _resolveLogo(path);
    }
  }

  void _resolveLogo(String? path) {
    if (path == null || path.isEmpty) {
      setState(() {
        _logoUrl = null;
        _logoKey = null;
      });
      return;
    }
    final key = Object();
    _logoKey = key;
    SupabaseService.createSignedUrlForProfileLogo(path).then((url) {
      if (!mounted || _logoKey != key) return;
      setState(() => _logoUrl = url);
    }).catchError((_) {
      if (!mounted || _logoKey != key) return;
      setState(() => _logoUrl = null);
    });
  }

  Future<void> _open() async {
    if (widget.signingOut) return;
    final action = await showShellUserAccountMenu(
      context: context,
      signingOut: widget.signingOut,
    );
    if (action != null && mounted) widget.onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Tooltip(
      message: ShellUserIdentity.displayName(widget.profile),
      child: InkWell(
        onTap: _open,
        customBorder: const CircleBorder(),
        child: ShellUserAvatar(
          size: widget.size,
          initials: ShellUserIdentity.initials(widget.profile),
          imageUrl: _logoUrl,
          borderColor: theme.border,
          fillColor: theme.surfaceCard,
          foreground: theme.textPrimary,
        ),
      ),
    );
  }
}
