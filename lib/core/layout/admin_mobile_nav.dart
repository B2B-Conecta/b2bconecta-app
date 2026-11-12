import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_destination.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_nav_badge.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

/// Barra móvil del administrador: módulos principales + «Más».
///
/// Por defecto: Inicio · Pedidos · Reportes · Usuarios · Más
/// (Valoraciones, Comisiones, Soporte van al sheet).
class AdminMobileNav extends StatelessWidget {
  const AdminMobileNav({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
    this.primaryIndices = const [0, 1, 2, 5],
    this.onOpenAccountMenu,
    this.navBadges,
    this.resolveNavBadge,
  });

  final int currentIndex;
  final List<ShellDestination> destinations;
  final ValueChanged<int> onSelect;

  /// Índices reales en [destinations] que viven en la barra.
  final List<int> primaryIndices;

  /// Abre Mi cuenta / Ajustes (sin drawer).
  final VoidCallback? onOpenAccountMenu;
  final Listenable? navBadges;
  final ShellNavBadge? Function(Object? key)? resolveNavBadge;

  List<int> get _primary {
    return [
      for (final i in primaryIndices)
        if (i >= 0 && i < destinations.length) i,
    ];
  }

  List<int> get _more {
    final primary = _primary.toSet();
    return [
      for (var i = 0; i < destinations.length; i++)
        if (!primary.contains(i)) i,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final primaryIdx = _primary;
    final moreIdx = _more;
    final moreSelected = moreIdx.contains(currentIndex);

    Widget bar() {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surfaceCard,
          boxShadow: [
            BoxShadow(
              color: theme.textPrimary.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight < AppBreakpoints.minTouchTarget ||
                  constraints.maxWidth < AppBreakpoints.minTouchTarget) {
                return const SizedBox.shrink();
              }
              final moreBadge = _aggregateMoreBadge(moreIdx);
              return SizedBox(
                height: AppBreakpoints.minTouchTarget + 12,
                child: Row(
                  children: [
                    for (final i in primaryIdx)
                      Expanded(
                        child: _NavButton(
                          icon: currentIndex == i
                              ? destinations[i].selectedIcon
                              : destinations[i].icon,
                          label: destinations[i].label,
                          selected: currentIndex == i,
                          badge: resolveNavBadge?.call(destinations[i].badgeKey),
                          onTap: () => onSelect(i),
                        ),
                      ),
                    if (moreIdx.isNotEmpty)
                      Expanded(
                        child: _NavButton(
                          icon: moreSelected
                              ? Icons.apps
                              : Icons.apps_outlined,
                          label: 'Más',
                          selected: moreSelected,
                          badge: moreBadge,
                          onTap: () => _openMore(context, moreIdx),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    if (navBadges == null) return bar();
    return ListenableBuilder(listenable: navBadges!, builder: (_, __) => bar());
  }

  ShellNavBadge? _aggregateMoreBadge(List<int> moreIdx) {
    ShellNavCountBadge? count;
    var dot = false;
    var warn = false;
    for (final i in moreIdx) {
      final b = resolveNavBadge?.call(destinations[i].badgeKey);
      if (b is ShellNavCountBadge && b.visible) {
        count = ShellNavCountBadge((count?.count ?? 0) + b.count);
      } else if (b is ShellNavDotBadge) {
        dot = true;
      } else if (b is ShellNavWarningBadge) {
        warn = true;
      }
    }
    if (count != null && count.visible) return count;
    if (dot) return const ShellNavBadge.dot();
    if (warn) return const ShellNavBadge.warning();
    return null;
  }

  Future<void> _openMore(BuildContext context, List<int> moreIdx) async {
    final theme = B2BThemeExtension.of(context);
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: theme.dialogSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        Widget sheet() {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Más secciones',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Valoraciones, comisiones, soporte y cuenta',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.textSecondary,
                    ),
                  ),
                  if (onOpenAccountMenu != null) ...[
                    const SizedBox(height: 12),
                    Material(
                      color: theme.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onOpenAccountMenu!();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: theme.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              LucideIcon(
                                LucideGlyph.settings,
                                size: 20,
                                color: theme.brand,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mi cuenta / Ajustes',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: theme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Perfil, notificaciones y sistema',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: theme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              LucideIcon(
                                LucideGlyph.chevronRight,
                                size: 16,
                                color: theme.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: moreIdx.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.55,
                    ),
                    itemBuilder: (context, i) {
                      final destIndex = moreIdx[i];
                      final selected = currentIndex == destIndex;
                      final destination = destinations[destIndex];
                      final badge =
                          resolveNavBadge?.call(destination.badgeKey);
                      return Material(
                        color: selected
                            ? theme.brandContainer
                            : theme.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => Navigator.of(ctx).pop(destIndex),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? theme.brand
                                    : theme.borderSubtle,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      selected
                                          ? destination.selectedIcon
                                          : destination.icon,
                                      size: 22,
                                      color: selected
                                          ? theme.brand
                                          : theme.textSecondary,
                                    ),
                                    const Spacer(),
                                    ShellNavBadgeView(
                                      badge: badge,
                                      compact: true,
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  destination.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: selected
                                        ? theme.brand
                                        : theme.textPrimary,
                                  ),
                                ),
                                if (destination.subtitle != null)
                                  Text(
                                    destination.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }

        if (navBadges == null) return sheet();
        return ListenableBuilder(
          listenable: navBadges!,
          builder: (_, __) => sheet(),
        );
      },
    );
    if (picked != null) onSelect(picked);
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ShellNavBadge? badge;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final color = selected ? theme.brand : theme.textSecondary;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppBreakpoints.minTouchTarget,
          minWidth: AppBreakpoints.minTouchTarget,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight < 28 || constraints.maxWidth < 8) {
              return const SizedBox.expand();
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 22, color: color),
                    if (badge != null)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: ShellNavBadgeView(badge: badge, compact: true),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
