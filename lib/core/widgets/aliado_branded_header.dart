import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/core/widgets/bandeja_sheet.dart';
import 'package:motolink_pro_app/core/widgets/bcv_rate_badge.dart';
import 'package:motolink_pro_app/core/widgets/ios_chrome.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';
import 'package:motolink_pro_app/features/cart/cart_screen.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Encabezado azul redondeado del maquetado aliado (Inicio / Catálogo / tabs).
///
/// Identidad + bolsa / BCV / bandeja. [footer] opcional (p. ej. búsqueda).
class AliadoBrandedHeader extends StatelessWidget {
  const AliadoBrandedHeader({
    super.key,
    required this.profile,
    this.onMessagesTap,
    this.onNotificationTap,
    this.unreadMessages = 0,
    this.unreadNotifications = 0,
    this.footer,
    this.showCart = true,
    this.showBcv = true,
  });

  final ProfileModel profile;
  final VoidCallback? onMessagesTap;
  final VoidCallback? onNotificationTap;
  final int unreadMessages;
  final int unreadNotifications;

  /// Contenido bajo la fila de identidad (búsqueda en Catálogo; null en otras).
  final Widget? footer;

  final bool showCart;
  final bool showBcv;

  static const blue = Color(0xFF004BDD);
  static const blueDark = Color(0xFF0A317B);
  static const navy = Color(0xFF08234C);
  static const filterBlue = Color(0xFF245DE6);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // viewPadding sobrevive a SafeArea anidados; asegura hueco para notch / status bar.
    final top = MediaQuery.viewPaddingOf(context).top;
    final color = dark ? blueDark : blue;
    final bottomPad = footer == null ? 14.0 : 0.0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: IosGlass(
        tint: color,
        border: const Color(0x29FFFFFF),
        radius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        blur: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: top + 6),
            Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 10, bottomPad),
              child: Row(
                children: [
                  Expanded(child: _Identity(profile: profile)),
                  if (showCart)
                    ListenableBuilder(
                      listenable: CartService.instance,
                      builder: (_, __) => _ToolbarIcon(
                        label: 'Bolsa',
                        icon: LucideGlyph.handbag,
                        count: CartService.instance.itemCount,
                        onTap: () {
                          Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => CartScreen(
                                profile: profile,
                                liveTasaBcv: BcvBasePrice.cachedRate,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (showBcv)
                    const BcvRateBadge(
                      alwaysVisible: true,
                      iconColor: Colors.white,
                      size: Size(44, 44),
                    ),
                  if (onMessagesTap != null || onNotificationTap != null)
                    _ToolbarIcon(
                      label: 'Bandeja',
                      icon: LucideGlyph.inbox,
                      unread:
                          unreadNotifications > 0 || unreadMessages > 0,
                      onTap: () => showBandejaSheet(
                        context: context,
                        onMessagesTap: onMessagesTap,
                        onNotificationTap: onNotificationTap,
                        unreadMessages: unreadMessages,
                        unreadNotifications: unreadNotifications,
                      ),
                    ),
                ],
              ),
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.profile});
  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final name = profile.businessName?.trim();
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Abrir perfil',
          child: InkWell(
            onTap: MainShellTabController.navigateToProfileTab,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFA344), width: 1.5),
              ),
              child: _ProfileLogo(
                path: profile.logoStoragePath,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (name != null && name.isNotEmpty) ? name : 'Mi negocio',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.32,
                  height: 1.12,
                ),
              ),
              const Text(
                'Tienda minorista',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Color(0xFFE5EFFF), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileLogo extends StatefulWidget {
  const _ProfileLogo({required this.path, required this.size});
  final String? path;
  final double size;

  @override
  State<_ProfileLogo> createState() => _ProfileLogoState();
}

class _ProfileLogoState extends State<_ProfileLogo> {
  late Future<String?> _url;

  Future<String?> _resolve() async {
    final path = widget.path?.trim();
    if (path == null || path.isEmpty) return null;
    try {
      return await SupabaseService.createSignedUrlForProfileLogo(path);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _url = _resolve();
  }

  @override
  void didUpdateWidget(covariant _ProfileLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _url = _resolve();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: LucideIcon(LucideGlyph.store,
          size: widget.size * .52, color: AppColors.brandLink),
    );
    return SizedBox.square(
      dimension: widget.size,
      child: ClipOval(
        child: ColoredBox(
          color: AppColors.card,
          child: FutureBuilder<String?>(
            future: _url,
            builder: (_, snapshot) => snapshot.data?.isNotEmpty == true
                ? Image.network(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback,
                  )
                : (widget.path == null || widget.path!.trim().isEmpty
                    ? BusinessLogoPlaceholder(size: widget.size)
                    : fallback),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.label,
    required this.icon,
    required this.onTap,
    this.count = 0,
    this.unread = false,
  });

  final String label;
  final LucideGlyph icon;
  final VoidCallback onTap;
  final int count;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        value:
            unread ? 'Con novedades' : (count > 0 ? '$count unidades' : null),
        child: IosPressable(
          onTap: onTap,
          radius: BorderRadius.circular(22),
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: ExcludeSemantics(
                child: Badge(
                  isLabelVisible: unread || count > 0,
                  backgroundColor: unread
                      ? const Color(0xFFFFAA80)
                      : AliadoBrandedHeader.navy,
                  smallSize: 8,
                  label: count > 0 ? Text(count > 9 ? '9+' : '$count') : null,
                  child: LucideIcon(icon, size: 21, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
