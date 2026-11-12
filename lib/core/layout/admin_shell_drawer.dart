import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_destination.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_nav_badge.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_user_menu.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Drawer móvil del panel admin: nav completa + tarjeta de cuenta.
///
/// Usa [Drawer] (SlideTransition nativo) + tokens [B2BThemeExtension].
class AdminShellDrawer extends StatelessWidget {
  const AdminShellDrawer({
    super.key,
    required this.profile,
    required this.onAction,
    this.destinations = const [],
    this.selectedIndex = 0,
    this.onDestinationSelected,
    this.selectedNestedId,
    this.onNestedDestinationSelected,
    this.navBadges,
    this.resolveNavBadge,
    this.signingOut = false,
    this.subtitle = 'Panel administrador',
  });

  final ProfileModel profile;
  final ValueChanged<ShellUserMenuAction> onAction;
  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;
  final Object? selectedNestedId;
  final void Function(int parentIndex, Object? nestedId)?
      onNestedDestinationSelected;
  final Listenable? navBadges;
  final ShellNavBadge? Function(Object? key)? resolveNavBadge;
  final bool signingOut;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget body() {
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MotoLinkProLogo(
                    height: 36,
                    forceWhite: dark,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.border),
            Expanded(
              child: destinations.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      itemCount: destinations.length,
                      itemBuilder: (context, i) {
                        final dest = destinations[i];
                        final selected = i == selectedIndex;
                        return _DrawerNavItem(
                          destination: dest,
                          selected: selected,
                          selectedNestedId:
                              selected ? selectedNestedId : null,
                          badge: resolveNavBadge?.call(dest.badgeKey),
                          onTap: () {
                            Navigator.of(context).maybePop();
                            if (dest.hasChildren &&
                                onNestedDestinationSelected != null) {
                              final nested = selectedNestedId ??
                                  dest.children.first.id;
                              onNestedDestinationSelected!(i, nested);
                            } else {
                              onDestinationSelected?.call(i);
                            }
                          },
                          onNestedTap: (nestedId) {
                            Navigator.of(context).maybePop();
                            onNestedDestinationSelected?.call(i, nestedId);
                          },
                        );
                      },
                    ),
            ),
            Divider(height: 1, color: theme.border),
            ShellUserMenu(
              profile: profile,
              chrome: dark
                  ? DesktopShellChrome.darkCorporate
                  : DesktopShellChrome.light,
              extended: true,
              signingOut: signingOut,
              openSettingsOnTap: true,
              onAction: (action) {
                Navigator.of(context).maybePop();
                onAction(action);
              },
            ),
          ],
        ),
      );
    }

    return Drawer(
      backgroundColor: theme.surfaceCard,
      surfaceTintColor: theme.surfaceCard,
      child: navBadges == null
          ? body()
          : ListenableBuilder(listenable: navBadges!, builder: (_, __) => body()),
    );
  }
}

class _DrawerNavItem extends StatelessWidget {
  const _DrawerNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.selectedNestedId,
    this.onNestedTap,
    this.badge,
  });

  final ShellDestination destination;
  final bool selected;
  final Object? selectedNestedId;
  final VoidCallback onTap;
  final ValueChanged<Object?>? onNestedTap;
  final ShellNavBadge? badge;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final hasChildren = destination.hasChildren;
    final expanded = selected && hasChildren;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: selected && !hasChildren
              ? theme.brandContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppBreakpoints.minTouchTarget,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    _NavGlyph(
                      destination: destination,
                      selected: selected,
                      color: selected ? theme.brand : theme.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? theme.brand : theme.textPrimary,
                        ),
                      ),
                    ),
                    ShellNavBadgeView(badge: badge, compact: true),
                    if (hasChildren) ...[
                      const SizedBox(width: 4),
                      LucideIcon(
                        expanded
                            ? LucideGlyph.chevronDown
                            : LucideGlyph.chevronRight,
                        size: 16,
                        color: theme.textMuted,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 2, bottom: 6),
            child: Column(
              children: [
                for (final child in destination.children)
                  _DrawerNestedTile(
                    label: child.label,
                    selected: child.id == selectedNestedId,
                    glyph: child.lucideIcon,
                    icon: child.icon,
                    onTap: () => onNestedTap?.call(child.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DrawerNestedTile extends StatelessWidget {
  const _DrawerNestedTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.glyph,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final LucideGlyph? glyph;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: selected ? theme.brandContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppBreakpoints.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                if (glyph != null)
                  LucideIcon(
                    glyph!,
                    size: 16,
                    color: selected ? theme.brand : theme.textSecondary,
                  )
                else if (icon != null)
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? theme.brand : theme.textSecondary,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? theme.brand : theme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavGlyph extends StatelessWidget {
  const _NavGlyph({
    required this.destination,
    required this.selected,
    required this.color,
  });

  final ShellDestination destination;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final glyph = selected
        ? (destination.lucideSelectedIcon ?? destination.lucideIcon)
        : destination.lucideIcon;
    if (glyph != null) {
      return LucideIcon(glyph, size: 20, color: color);
    }
    return Icon(
      selected ? destination.selectedIcon : destination.icon,
      size: 20,
      color: color,
    );
  }
}
