import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/core/widgets/aliado_branded_header.dart';
import 'package:motolink_pro_app/core/widgets/aliado_home_header.dart';
import 'package:motolink_pro_app/core/widgets/bandeja_sheet.dart';
import 'package:motolink_pro_app/core/widgets/bcv_rate_badge.dart';
import 'package:motolink_pro_app/core/widgets/ios_chrome.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';
import 'package:motolink_pro_app/features/cart/cart_screen.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Encabezado colapsable del Catálogo (misma animación de scroll que Inicio).
///
/// Expande búsqueda; al scrollear queda chrome básico + lupa.
class AliadoCatalogBrandedHeader extends StatelessWidget {
  const AliadoCatalogBrandedHeader({
    super.key,
    required this.profile,
    required this.searchController,
    required this.onSearchSubmitted,
    required this.onOpenSearch,
    required this.onOpenFilters,
    this.onMessagesTap,
    this.onNotificationTap,
    this.unreadMessages = 0,
    this.unreadNotifications = 0,
    this.filterBadge = 0,
  });

  final ProfileModel profile;
  final TextEditingController searchController;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onOpenSearch;
  final VoidCallback? onOpenFilters;
  final VoidCallback? onMessagesTap;
  final VoidCallback? onNotificationTap;
  final int unreadMessages;
  final int unreadNotifications;
  final int filterBadge;

  @override
  Widget build(BuildContext context) {
    return AliadoHomeHeader(
      identity: (compact) => _CatalogIdentity(profile: profile, compact: compact),
      search: CatalogCollapsingSearchField(
        controller: searchController,
        onSubmitted: onSearchSubmitted,
        onOpenFilters: onOpenFilters,
        filterBadge: filterBadge,
      ),
      searchAction: _CatalogToolbarIcon(
        label: 'Abrir búsqueda',
        icon: LucideGlyph.search,
        onTap: onOpenSearch,
      ),
      actions: [
        ListenableBuilder(
          listenable: CartService.instance,
          builder: (_, __) => _CatalogToolbarIcon(
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
        const BcvRateBadge(
          alwaysVisible: true,
          iconColor: Colors.white,
          size: Size(44, 44),
        ),
        if (onMessagesTap != null || onNotificationTap != null)
          _CatalogToolbarIcon(
            label: 'Bandeja',
            icon: LucideGlyph.inbox,
            unread: unreadNotifications > 0 || unreadMessages > 0,
            onTap: () => showBandejaSheet(
              context: context,
              onMessagesTap: onMessagesTap,
              onNotificationTap: onNotificationTap,
              unreadMessages: unreadMessages,
              unreadNotifications: unreadNotifications,
            ),
          ),
      ],
    );
  }
}

/// Campo de búsqueda del header expandido / sheet colapsado.
class CatalogCollapsingSearchField extends StatelessWidget {
  const CatalogCollapsingSearchField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.onOpenFilters,
    this.filterBadge = 0,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final VoidCallback? onOpenFilters;
  final int filterBadge;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted =
        dark ? theme.colorScheme.onSurfaceVariant : const Color(0xFF64748B);
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmitted(),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: 'Buscar repuestos, bujías, cauchos…',
          hintStyle: TextStyle(color: muted, fontSize: 14),
          prefixIcon: IconButton(
            tooltip: 'Buscar en el catálogo',
            onPressed: onSubmitted,
            icon: LucideIcon(LucideGlyph.search, size: 19, color: muted),
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: 'Filtros del catálogo',
              onPressed: onOpenFilters,
              style: IconButton.styleFrom(
                minimumSize: const Size.square(44),
                padding: EdgeInsets.zero,
                foregroundColor: AliadoBrandedHeader.filterBlue,
              ),
              icon: Badge(
                isLabelVisible: filterBadge > 0,
                label: Text('$filterBadge'),
                backgroundColor: AppColors.brandAccent,
                child: const SizedBox.square(
                  dimension: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AliadoBrandedHeader.filterBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: LucideIcon(LucideGlyph.slidersHorizontal,
                          size: 17, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
          filled: true,
          fillColor: dark ? theme.colorScheme.surface : Colors.white,
          border: outline,
          enabledBorder: outline,
          focusedBorder: outline.copyWith(
            borderSide: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

class _CatalogIdentity extends StatelessWidget {
  const _CatalogIdentity({required this.profile, required this.compact});
  final ProfileModel profile;
  final bool compact;

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
              child: _CatalogLogo(path: profile.logoStoragePath, size: 38),
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
              if (!compact)
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

class _CatalogLogo extends StatefulWidget {
  const _CatalogLogo({required this.path, required this.size});
  final String? path;
  final double size;

  @override
  State<_CatalogLogo> createState() => _CatalogLogoState();
}

class _CatalogLogoState extends State<_CatalogLogo> {
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
  void didUpdateWidget(covariant _CatalogLogo oldWidget) {
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

class _CatalogToolbarIcon extends StatelessWidget {
  const _CatalogToolbarIcon({
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
