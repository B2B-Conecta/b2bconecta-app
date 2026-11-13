import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/messages_icon_button.dart';
import 'package:motolink_pro_app/core/widgets/theme_mode_bubble.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'shell_destination.dart';
import 'shell_user_menu.dart';

/// Segmento de breadcrumb del header admin.
class AdminShellBreadcrumb {
  const AdminShellBreadcrumb({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;
}

/// Barra superior del panel admin (64px, breadcrumb + búsqueda + acciones).
/// Se adapta a claro/oscuro vía [B2BThemeExtension].
class AdminShellTopBar extends StatefulWidget implements PreferredSizeWidget {
  const AdminShellTopBar({
    super.key,
    required this.breadcrumbs,
    required this.profile,
    required this.unreadNotifications,
    required this.onNotificationTap,
    this.onUserMenuAction,
    this.onOpenDrawer,
    this.onSearchSubmitted,
    this.onOpenGlobalSearch,
    this.searchFocusNode,
    this.signingOut = false,
    this.showThemeToggle = true,
    this.showUserAvatar = false,
    this.onBreadcrumbBack,
    this.showGlobalSearch = true,
    this.onMessagesTap,
    this.unreadMessages = 0,
    this.trailingActions = const [],
  });

  final List<AdminShellBreadcrumb> breadcrumbs;
  final ProfileModel profile;
  final int unreadNotifications;
  /// Recibe el [BuildContext] de la campana para anclar el popover.
  final void Function(BuildContext anchorContext) onNotificationTap;
  final ValueChanged<ShellUserMenuAction>? onUserMenuAction;
  final VoidCallback? onOpenDrawer;
  final ValueChanged<String>? onSearchSubmitted;
  /// Abre la paleta de comandos (⌘K). Si es null, se usa [onSearchSubmitted].
  final VoidCallback? onOpenGlobalSearch;
  final FocusNode? searchFocusNode;
  final bool signingOut;
  final bool showThemeToggle;
  /// Avatar de cuenta en header (redundante con la tarjeta del rail).
  final bool showUserAvatar;

  /// Retroceso contextual en subvistas profundas (Registro Incompleto, detalle…).
  final VoidCallback? onBreadcrumbBack;

  /// Búsqueda global (admin). Los paneles B2B pueden ocultarla.
  final bool showGlobalSearch;
  final VoidCallback? onMessagesTap;
  final int unreadMessages;
  final List<Widget> trailingActions;

  static const double height = 64;
  static const double mobileMenuBreakpoint = AppBreakpoints.mobileMenu;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  State<AdminShellTopBar> createState() => _AdminShellTopBarState();
}

class _AdminShellTopBarState extends State<AdminShellTopBar> {
  void _openGlobalSearch() {
    if (widget.onOpenGlobalSearch != null) {
      widget.onOpenGlobalSearch!();
      return;
    }
    widget.onSearchSubmitted?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final theme = B2BThemeExtension.of(context);
    final showMenu = widget.onOpenDrawer != null &&
        width < AdminShellTopBar.mobileMenuBreakpoint;
    final showSearch = widget.showGlobalSearch && width >= 560;
    final barBg = theme.surfaceCard;
    final barBorder = theme.borderStrong;
    final iconColor = theme.textPrimary;
    final mutedIcon = theme.textSecondary;

    Widget bar = Material(
            color: barBg,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: barBorder),
                ),
              ),
              child: SizedBox(
                height: AdminShellTopBar.height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      if (showMenu) ...[
                        IconButton(
                          tooltip: 'Abrir menú',
                          onPressed: widget.onOpenDrawer,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(
                              AppBreakpoints.minTouchTarget,
                              AppBreakpoints.minTouchTarget,
                            ),
                            tapTargetSize: MaterialTapTargetSize.padded,
                          ),
                          icon: LucideIcon(
                            LucideGlyph.menu,
                            size: 22,
                            color: iconColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: _Breadcrumbs(
                          items: widget.breadcrumbs,
                          onBack: widget.onBreadcrumbBack,
                        ),
                      ),
                      if (widget.showGlobalSearch) ...[
                        if (showSearch) ...[
                          const SizedBox(width: 12),
                          _GlobalSearchField(
                            onOpen: _openGlobalSearch,
                          ),
                        ] else ...[
                          IconButton(
                            tooltip: 'Buscar (⌘K)',
                            onPressed: _openGlobalSearch,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(
                                AppBreakpoints.minTouchTarget,
                                AppBreakpoints.minTouchTarget,
                              ),
                            ),
                            icon: LucideIcon(
                              LucideGlyph.search,
                              size: 20,
                              color: mutedIcon,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                      ],
                      ...widget.trailingActions,
                      if (widget.onMessagesTap != null)
                        MessagesIconButton(
                          onPressed: widget.onMessagesTap!,
                          unreadCount: widget.unreadMessages,
                        ),
                      _NotificationBell(
                        unread: widget.unreadNotifications,
                        onTap: widget.onNotificationTap,
                      ),
                      if (widget.showThemeToggle) ...[
                        const SizedBox(width: 4),
                        const ThemeModeBubble(),
                      ],
                      if (widget.showUserAvatar &&
                          widget.onUserMenuAction != null) ...[
                        const SizedBox(width: 8),
                        ShellUserAvatarButton(
                          profile: widget.profile,
                          size: 36,
                          signingOut: widget.signingOut,
                          onAction: widget.onUserMenuAction!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );

    if (!widget.showGlobalSearch) return bar;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _FocusAdminSearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _FocusAdminSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusAdminSearchIntent: CallbackAction<_FocusAdminSearchIntent>(
            onInvoke: (_) {
              _openGlobalSearch();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: bar,
        ),
      ),
    );
  }
}

class _FocusAdminSearchIntent extends Intent {
  const _FocusAdminSearchIntent();
}

/// Construye crumbs `Inicio > …` a partir del destino activo del shell.
List<AdminShellBreadcrumb> adminShellBreadcrumbsFor({
  required List<ShellDestination> destinations,
  required int selectedIndex,
  Object? nestedId,
  VoidCallback? onHome,
  ValueChanged<int>? onSelectParent,
}) {
  if (destinations.isEmpty) {
    return [AdminShellBreadcrumb(label: 'Inicio', onTap: onHome)];
  }
  final i = selectedIndex.clamp(0, destinations.length - 1);
  final parent = destinations[i];

  if (i == 0 && parent.label == 'Inicio') {
    return const [AdminShellBreadcrumb(label: 'Inicio')];
  }

  final crumbs = <AdminShellBreadcrumb>[
    AdminShellBreadcrumb(label: 'Inicio', onTap: onHome),
  ];
  ShellDestination? child;
  if (nestedId != null && parent.hasChildren) {
    for (final c in parent.children) {
      if (c.id == nestedId) {
        child = c;
        break;
      }
    }
  }
  if (child != null) {
    crumbs.add(
      AdminShellBreadcrumb(
        label: parent.label,
        onTap: onSelectParent == null ? null : () => onSelectParent(i),
      ),
    );
    crumbs.add(AdminShellBreadcrumb(label: child.label));
  } else {
    crumbs.add(AdminShellBreadcrumb(label: parent.label));
  }
  return crumbs;
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({required this.items, this.onBack});

  final List<AdminShellBreadcrumb> items;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = B2BThemeExtension.of(context);
    final chevron = theme.textMuted;
    // Título de página único (móvil): tipografía de vista, sin chevrons.
    if (items.length == 1 && onBack == null) {
      return Text(
        items.first.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: theme.textPrimary,
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton(
              tooltip: 'Volver',
              onPressed: onBack,
              style: IconButton.styleFrom(
                minimumSize: const Size(
                  AppBreakpoints.minTouchTarget,
                  AppBreakpoints.minTouchTarget,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
              icon: LucideIcon(
                LucideGlyph.arrowLeft,
                size: 18,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(width: 2),
          ],
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: LucideIcon(
                  LucideGlyph.chevronRight,
                  size: 14,
                  color: chevron,
                ),
              ),
            ],
            _Crumb(
              label: items[i].label,
              active: i == items.length - 1,
              onTap: items[i].onTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _Crumb extends StatefulWidget {
  const _Crumb({
    required this.label,
    required this.active,
    this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  State<_Crumb> createState() => _CrumbState();
}

class _CrumbState extends State<_Crumb> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final interactive = widget.onTap != null && !widget.active;
    final color = widget.active
        ? theme.textPrimary
        : (_hovered && interactive ? theme.brand : theme.textSecondary);
    final style = TextStyle(
      fontSize: 13.5,
      fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
      color: color,
      decoration: _hovered && interactive ? TextDecoration.underline : null,
      decorationColor: theme.brand.withOpacity(0.55),
    );
    if (!interactive) {
      return Text(
        widget.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: theme.brandContainer.withOpacity(0.55),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppBreakpoints.minTouchTarget,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlobalSearchField extends StatelessWidget {
  const _GlobalSearchField({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isMac = Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.iOS;
    final shortcut = isMac ? '⌘K' : 'Ctrl+K';
    final theme = B2BThemeExtension.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320, minWidth: 180),
      child: Material(
        color: theme.inputFill,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.borderStrong),
            ),
            child: Row(
              children: [
                LucideIcon(
                  LucideGlyph.search,
                  size: 18,
                  color: theme.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Buscar usuarios, pedidos, productos…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.textMuted,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    shortcut,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.textSecondary,
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

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unread, required this.onTap});

  final int unread;
  final void Function(BuildContext anchorContext) onTap;

  @override
  Widget build(BuildContext context) {
    final label = unread > 99 ? '99+' : '$unread';
    final theme = B2BThemeExtension.of(context);
    final iconColor = theme.textSecondary;
    final badgeBorder = theme.surfaceCard;
    return Tooltip(
      message: 'Notificaciones',
      child: InkWell(
        onTap: () => onTap(context),
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: AppBreakpoints.minTouchTarget,
          height: AppBreakpoints.minTouchTarget,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              LucideIcon(
                LucideGlyph.bell,
                size: 20,
                color: iconColor,
              ),
              if (unread > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: badgeBorder, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: theme.surfaceCard,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
