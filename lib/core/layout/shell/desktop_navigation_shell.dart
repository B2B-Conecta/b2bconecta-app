import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/admin_content_frame.dart';
import 'package:motolink_pro_app/core/utils/bcv_base_price.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';
import 'admin_shell_top_bar.dart';
import 'desktop_nav_rail_preference.dart';
import 'desktop_shell_top_bar.dart';
import 'package:motolink_pro_app/core/layout/scroll_compact_layout.dart';
import 'shell_destination.dart';
import 'shell_nav_badge.dart';
import 'shell_user_menu.dart';

/// Layout escritorio: rail lateral (ocultable), barra superior y contenido.
class DesktopNavigationShell extends StatefulWidget {
  const DesktopNavigationShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.pages,
    required this.profile,
    required this.unreadNotifications,
    required this.onNotificationTap,
    this.onMessagesTap,
    this.unreadMessages = 0,
    required this.onOpenSettings,
    this.onOpenProfile,
    this.onOpenNotificationPrefs,
    this.onSignOut,
    required this.railBadgeLabel,
    this.trailingActions = const [],
    this.railStatusBuilder,
    this.chrome = DesktopShellChrome.light,
    this.showBcvFooter = false,
    this.selectedNestedId,
    this.onNestedDestinationSelected,
    this.navBadges,
    this.resolveNavBadge,
    this.onOpenDrawer,
    this.onSearchSubmitted,
    this.onOpenGlobalSearch,
    this.breadcrumbsOverride,
    this.onBreadcrumbBack,
    this.contentOverride,
  });

  /// Bloque opcional sobre la tarjeta de cuenta; recibe si el rail está expandido.
  final Widget Function(bool extended)? railStatusBuilder;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<ShellDestination> destinations;
  final List<Widget> pages;
  final ProfileModel profile;
  final int unreadNotifications;
  final void Function(BuildContext anchorContext) onNotificationTap;
  /// Breadcrumbs cuando el contenido no es un destino del rail (p. ej. Ajustes).
  final List<AdminShellBreadcrumb>? breadcrumbsOverride;
  /// Flecha atrás contextual en subvistas profundas.
  final VoidCallback? onBreadcrumbBack;
  /// Sustituye el IndexedStack (p. ej. hub de ajustes embebido).
  final Widget? contentOverride;
  final VoidCallback? onMessagesTap;
  final int unreadMessages;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenNotificationPrefs;
  final Future<void> Function()? onSignOut;
  final String railBadgeLabel;
  final List<Widget> trailingActions;
  final DesktopShellChrome chrome;
  final bool showBcvFooter;

  /// Id del sub-ítem activo (`ShellDestination.id` del hijo).
  final Object? selectedNestedId;

  /// Padre (índice top-level) + id del hijo al elegir sub-navegación.
  final void Function(int parentIndex, Object? nestedId)?
      onNestedDestinationSelected;

  /// Notifier de badges (p. ej. [AdminShellBadges]).
  final Listenable? navBadges;

  /// Resuelve [ShellNavBadge] por [ShellDestination.badgeKey].
  final ShellNavBadge? Function(Object? key)? resolveNavBadge;

  /// Abre el drawer móvil (hamburguesa del top bar admin).
  final VoidCallback? onOpenDrawer;

  /// Búsqueda global del header admin.
  final ValueChanged<String>? onSearchSubmitted;

  /// Abre la paleta de comandos (⌘K).
  final VoidCallback? onOpenGlobalSearch;

  @override
  State<DesktopNavigationShell> createState() => _DesktopNavigationShellState();
}

class _DesktopNavigationShellState extends State<DesktopNavigationShell> {
  bool _railExpanded = true;
  bool _prefReady = false;
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut || widget.onSignOut == null) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut!();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No pudimos cerrar la sesión. Inténtalo de nuevo.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRailPreference();
  }

  Future<void> _loadRailPreference() async {
    await DesktopNavRailPreference.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _railExpanded = DesktopNavRailPreference.expanded;
      _prefReady = true;
    });
  }

  Future<void> _setRailExpanded(bool expanded) async {
    setState(() => _railExpanded = expanded);
    await DesktopNavRailPreference.setExpanded(expanded);
  }

  @override
  Widget build(BuildContext context) {
    // Engancha al Theme: al cambiar claro/oscuro el rail y el scaffold se redibujan.
    final brightness = Theme.of(context).brightness;
    AppColors.brightness = brightness;
    // Preferencia del usuario: expandido (etiquetas) o colapsado (solo iconos).
    final extended = _prefReady
        ? _railExpanded
        : MediaQuery.sizeOf(context).width >= AppBreakpoints.desktopRailExtended;
    final safeIndex = widget.selectedIndex.clamp(0, widget.pages.length - 1);
    final parent = widget.destinations[
        safeIndex.clamp(0, widget.destinations.length - 1)];
    final dest = _resolveActiveDestination(
      parent: parent,
      nestedId: widget.selectedNestedId,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.centerLeft,
            child: _DesktopSideRail(
              chrome: widget.chrome,
              showBcvFooter: widget.showBcvFooter,
              extended: extended,
              selectedIndex: safeIndex,
              selectedNestedId: widget.selectedNestedId,
              destinations: widget.destinations,
              badgeLabel: widget.railBadgeLabel,
              profile: widget.profile,
              onDestinationSelected: widget.onDestinationSelected,
              onNestedDestinationSelected: widget.onNestedDestinationSelected,
              onOpenSettings: widget.onOpenSettings,
              onOpenProfile: widget.onOpenProfile,
              onOpenNotificationPrefs: widget.onOpenNotificationPrefs,
              onSignOut: widget.onSignOut == null ? null : _signOut,
              signingOut: _signingOut,
              statusBuilder: widget.railStatusBuilder,
              onToggleExpanded: () => _setRailExpanded(!extended),
              navBadges: widget.navBadges,
              resolveNavBadge: widget.resolveNavBadge,
            ),
          ),
          Expanded(
            child: ScrollCompactLayout(
                enabled: dest.compactHeaderOnScroll,
                resetKey: Object.hash(safeIndex, widget.selectedNestedId),
                builder: (context, compact) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.chrome == DesktopShellChrome.darkCorporate)
                          AdminShellTopBar(
                            breadcrumbs: widget.breadcrumbsOverride ??
                                adminShellBreadcrumbsFor(
                                  destinations: widget.destinations,
                                  selectedIndex: safeIndex,
                                  nestedId: widget.selectedNestedId,
                                  onHome: () =>
                                      widget.onDestinationSelected(0),
                                  onSelectParent: (i) =>
                                      widget.onDestinationSelected(i),
                                ),
                            onBreadcrumbBack: widget.onBreadcrumbBack,
                            profile: widget.profile,
                            unreadNotifications: widget.unreadNotifications,
                            onNotificationTap: widget.onNotificationTap,
                            onOpenDrawer: widget.onOpenDrawer,
                            onSearchSubmitted: widget.onSearchSubmitted,
                            onOpenGlobalSearch: widget.onOpenGlobalSearch,
                            signingOut: _signingOut,
                            showUserAvatar: false,
                            onUserMenuAction: (action) {
                              switch (action) {
                                case ShellUserMenuAction.profile:
                                  (widget.onOpenProfile ??
                                      widget.onOpenSettings)();
                                case ShellUserMenuAction.accountSettings:
                                  widget.onOpenSettings();
                                case ShellUserMenuAction.notificationPrefs:
                                  (widget.onOpenNotificationPrefs ??
                                      widget.onOpenSettings)();
                                case ShellUserMenuAction.signOut:
                                  _signOut();
                              }
                            },
                          )
                        else
                          DesktopShellTopBar(
                            unreadNotifications: widget.unreadNotifications,
                            onNotificationTap: () =>
                                widget.onNotificationTap(context),
                            onMessagesTap: widget.onMessagesTap,
                            unreadMessages: widget.unreadMessages,
                            trailingActions: widget.trailingActions,
                          ),
                        if (widget.contentOverride == null)
                          _DesktopPageHeading(
                              destination: dest,
                              compact: compact,
                              hidden:
                                  ScrollCompactState.hideHeadingOf(context)),
                        if (widget.contentOverride != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(28, 18, 28, 8),
                            child: Text(
                              'Ajustes del sistema',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.4,
                                height: 1.15,
                              ),
                            ),
                          ),
                        Expanded(
                          child: AdminContentFrame(
                            padding: EdgeInsets.fromLTRB(
                                24,
                                0,
                                24,
                                widget.contentOverride != null
                                    ? 24
                                    : dest.bottomContentPadding),
                            child: widget.contentOverride ??
                                IndexedStack(
                                  index: safeIndex,
                                  children: widget.pages,
                                ),
                          ),
                        ),
                      ],
                    )),
          ),
        ],
      ),
    );
  }
}

ShellDestination _resolveActiveDestination({
  required ShellDestination parent,
  required Object? nestedId,
}) {
  if (nestedId == null || !parent.hasChildren) return parent;
  for (final child in parent.children) {
    if (child.id == nestedId) return child;
  }
  return parent;
}

class _DesktopPageHeading extends StatelessWidget {
  const _DesktopPageHeading({
    required this.destination,
    required this.compact,
    required this.hidden,
  });

  final ShellDestination destination;
  final bool compact;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final heading = hidden
        ? const SizedBox(key: ValueKey('desktop-page-heading'), height: 0)
        : Padding(
            key: const ValueKey('desktop-page-heading'),
            padding:
                EdgeInsets.fromLTRB(28, compact ? 8 : 22, 28, compact ? 6 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(destination.title,
                    style: TextStyle(
                        fontSize: compact ? 20 : 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.4,
                        height: 1.15)),
                if (!compact && destination.subtitle?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Text(destination.subtitle!,
                          style: TextStyle(
                              fontSize: 14.5,
                              height: 1.45,
                              color: AppColors.textSecondary))),
                ],
              ],
            ),
          );
    // Flutter 3.24 AnimatedSize cannot safely lay out a zero-duration change.
    if (MediaQuery.disableAnimationsOf(context)) return heading;
    return AnimatedSize(
        alignment: Alignment.topLeft,
        duration: ScrollCompactLayout.motionDuration(context),
        curve: Curves.easeOutCubic,
        child: heading);
  }
}

class _RailChromeColors {
  const _RailChromeColors({
    required this.background,
    required this.border,
    required this.muted,
    required this.label,
    required this.selectedFill,
    required this.selectedFg,
    required this.idleIcon,
    required this.footerCard,
    required this.footerBorder,
    required this.toggleIcon,
  });

  final Color background;
  final Color border;
  final Color muted;
  final Color label;
  final Color selectedFill;
  final Color selectedFg;
  final Color idleIcon;
  final Color footerCard;
  final Color footerBorder;
  final Color toggleIcon;

  static const emerald = Color(0xFF34D399);

  factory _RailChromeColors.of(
    DesktopShellChrome chrome, {
    required Brightness brightness,
  }) {
    final isAdmin = chrome == DesktopShellChrome.darkCorporate;
    final dark = brightness == Brightness.dark;
    final t = dark ? B2BThemeExtension.dark : B2BThemeExtension.light;
    if (isAdmin) {
      return _RailChromeColors(
        background: t.sidebarBg,
        border: t.sidebarBorder,
        muted: t.sidebarMuted,
        label: t.sidebarLabel,
        selectedFill: t.sidebarActiveFill,
        selectedFg: t.sidebarActiveFg,
        idleIcon: t.sidebarMuted,
        footerCard: t.sidebarFooterBg,
        footerBorder: t.sidebarFooterBorder,
        toggleIcon: t.sidebarMuted,
      );
    }
    return _RailChromeColors(
      background: t.surfaceElevated,
      border: t.borderSubtle,
      muted: t.textSecondary,
      label: t.textPrimary,
      selectedFill: t.brandContainer,
      selectedFg: t.brand,
      idleIcon: t.textSecondary,
      footerCard: t.surfaceCard,
      footerBorder: t.borderSubtle,
      toggleIcon: t.textSecondary,
    );
  }
}

class _DesktopSideRail extends StatefulWidget {
  const _DesktopSideRail({
    required this.chrome,
    required this.showBcvFooter,
    required this.extended,
    required this.selectedIndex,
    required this.destinations,
    required this.badgeLabel,
    required this.profile,
    required this.onDestinationSelected,
    required this.onOpenSettings,
    this.onOpenProfile,
    this.onOpenNotificationPrefs,
    this.selectedNestedId,
    this.onNestedDestinationSelected,
    this.onToggleExpanded,
    this.onSignOut,
    this.signingOut = false,
    this.statusBuilder,
    this.navBadges,
    this.resolveNavBadge,
  });

  final DesktopShellChrome chrome;
  final bool showBcvFooter;
  final bool extended;
  final int selectedIndex;
  final Object? selectedNestedId;
  final List<ShellDestination> destinations;
  final String badgeLabel;
  final ProfileModel profile;
  final ValueChanged<int> onDestinationSelected;
  final void Function(int parentIndex, Object? nestedId)?
      onNestedDestinationSelected;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenNotificationPrefs;
  final VoidCallback? onToggleExpanded;
  final VoidCallback? onSignOut;
  final bool signingOut;
  final Widget Function(bool extended)? statusBuilder;
  final Listenable? navBadges;
  final ShellNavBadge? Function(Object? key)? resolveNavBadge;

  @override
  State<_DesktopSideRail> createState() => _DesktopSideRailState();
}

class _DesktopSideRailState extends State<_DesktopSideRail> {
  int? _expandedGroupIndex;

  bool get _isAdmin => widget.chrome == DesktopShellChrome.darkCorporate;

  bool get _themeDark =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _expandedGroupIndex = _groupIndexForSelection(
      widget.selectedIndex,
      widget.selectedNestedId,
      widget.destinations,
    );
  }

  @override
  void didUpdateWidget(covariant _DesktopSideRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _groupIndexForSelection(
      widget.selectedIndex,
      widget.selectedNestedId,
      widget.destinations,
    );
    if (next != null) {
      if (next != _expandedGroupIndex) {
        _expandedGroupIndex = next;
      }
    } else if (_expandedGroupIndex != null &&
        widget.selectedIndex != _expandedGroupIndex) {
      // Hoja top-level distinta del grupo: colapsa el acordeón.
      _expandedGroupIndex = null;
    }
  }

  static int? _groupIndexForSelection(
    int selectedIndex,
    Object? nestedId,
    List<ShellDestination> destinations,
  ) {
    if (destinations.isEmpty) return null;
    final i = selectedIndex.clamp(0, destinations.length - 1);
    final parent = destinations[i];
    if (!parent.hasChildren) return null;
    if (nestedId == null) return i;
    for (final child in parent.children) {
      if (child.id == nestedId) return i;
    }
    return i;
  }

  void _toggleGroup(int index) {
    final dest = widget.destinations[index];
    if (!dest.hasChildren) {
      widget.onDestinationSelected(index);
      return;
    }
    final opening = _expandedGroupIndex != index;
    setState(() => _expandedGroupIndex = opening ? index : null);
    if (!opening) return;
    final nested = widget.selectedIndex == index && widget.selectedNestedId != null
        ? widget.selectedNestedId
        : dest.children.first.id;
    final handler = widget.onNestedDestinationSelected;
    if (handler != null) {
      handler(index, nested);
    } else {
      widget.onDestinationSelected(index);
    }
  }

  void _selectLeaf(int index) {
    setState(() => _expandedGroupIndex = null);
    widget.onDestinationSelected(index);
  }

  void _selectNested(int parentIndex, ShellDestination child) {
    setState(() => _expandedGroupIndex = parentIndex);
    final handler = widget.onNestedDestinationSelected;
    if (handler != null) {
      handler(parentIndex, child.id);
    } else {
      widget.onDestinationSelected(parentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _RailChromeColors.of(
      widget.chrome,
      brightness: Theme.of(context).brightness,
    );
    final extended = widget.extended;
    final width = extended ? (_isAdmin ? 250.0 : 232.0) : 72.0;
    final business = widget.profile.businessName?.trim();
    final workshopLabel =
        business != null && business.isNotEmpty ? business : null;

    return Material(
      color: colors.background,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: colors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                extended ? 12 : 6,
                12,
                extended ? 8 : 6,
                8,
              ),
              child: extended
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8, top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MotoLinkProLogo(
                                  height: 42,
                                  forceWhite: _themeDark,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  widget.badgeLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: colors.muted,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                if (workshopLabel != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    workshopLabel,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colors.label,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (widget.onToggleExpanded != null)
                          IconButton(
                            tooltip: 'Contraer menú',
                            onPressed: widget.onToggleExpanded,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(40, 40),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              Icons.menu_open,
                              color: colors.toggleIcon,
                              size: 22,
                            ),
                          ),
                      ],
                    )
                  : Column(
                      children: [
                        B2bConectaMark(size: 32, forceWhite: _themeDark),
                        if (widget.onToggleExpanded != null) ...[
                          const SizedBox(height: 2),
                          IconButton(
                            tooltip: 'Expandir menú',
                            onPressed: widget.onToggleExpanded,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(40, 40),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              Icons.menu,
                              color: colors.toggleIcon,
                              size: 22,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: extended ? 10 : 8,
                  vertical: 4,
                ),
                itemCount: widget.destinations.length,
                itemBuilder: (context, i) {
                  final d = widget.destinations[i];
                  final parentSelected = i == widget.selectedIndex;
                  final groupExpanded =
                      extended && d.hasChildren && _expandedGroupIndex == i;
                  void onTap() {
                    if (d.hasChildren) {
                      if (!extended) {
                        _selectNested(i, d.children.first);
                      } else {
                        _toggleGroup(i);
                      }
                    } else {
                      _selectLeaf(i);
                    }
                  }

                  Widget buildTile([ShellNavBadge? badge]) => _RailNavTile(
                        chrome: widget.chrome,
                        colors: colors,
                        extended: extended,
                        selected: parentSelected &&
                            (!d.hasChildren ||
                                widget.selectedNestedId == null),
                        groupActive: parentSelected && d.hasChildren,
                        expanded: groupExpanded,
                        destination: d,
                        badge: badge,
                        onTap: onTap,
                      );

                  final tile = widget.navBadges != null && d.badgeKey != null
                      ? ListenableBuilder(
                          listenable: widget.navBadges!,
                          builder: (context, _) => buildTile(
                            widget.resolveNavBadge?.call(d.badgeKey),
                          ),
                        )
                      : buildTile(
                          widget.resolveNavBadge?.call(d.badgeKey),
                        );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        tile,
                        if (d.hasChildren)
                          ClipRect(
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              alignment: Alignment.topCenter,
                              child: groupExpanded
                                  ? Padding(
                                      padding: const EdgeInsets.only(
                                        left: 12,
                                        top: 2,
                                        bottom: 2,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (final child in d.children)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 2,
                                              ),
                                              child: _RailNestedNavTile(
                                                chrome: widget.chrome,
                                                colors: colors,
                                                selected: parentSelected &&
                                                    widget.selectedNestedId ==
                                                        child.id,
                                                destination: child,
                                                onTap: () =>
                                                    _selectNested(i, child),
                                              ),
                                            ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (widget.statusBuilder != null) widget.statusBuilder!(extended),
            if (widget.showBcvFooter)
              _RailBcvFooter(extended: extended, dark: _themeDark),
            ShellUserMenu(
              chrome: widget.chrome,
              extended: extended,
              profile: widget.profile,
              signingOut: widget.signingOut,
              openSettingsOnTap:
                  widget.chrome == DesktopShellChrome.darkCorporate,
              onAction: (action) {
                switch (action) {
                  case ShellUserMenuAction.profile:
                    (widget.onOpenProfile ?? widget.onOpenSettings)();
                  case ShellUserMenuAction.accountSettings:
                    widget.onOpenSettings();
                  case ShellUserMenuAction.notificationPrefs:
                    (widget.onOpenNotificationPrefs ??
                        widget.onOpenSettings)();
                  case ShellUserMenuAction.signOut:
                    widget.onSignOut?.call();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RailBcvFooter extends StatefulWidget {
  const _RailBcvFooter({required this.extended, required this.dark});

  final bool extended;
  final bool dark;

  @override
  State<_RailBcvFooter> createState() => _RailBcvFooterState();
}

class _RailBcvFooterState extends State<_RailBcvFooter> {
  double? _tasa;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rate = await BcvBasePrice.currentRate();
    if (!mounted) return;
    setState(() {
      _tasa = rate;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const emerald = _RailChromeColors.emerald;
    final label = _loading
        ? 'BCV…'
        : (_tasa != null && _tasa! > 0
            ? '${formatBsLabel(_tasa!, fractionDigits: 2)} / REF'
            : 'BCV —');
    if (!widget.extended) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Tooltip(
          message: label,
          child: const Icon(Icons.currency_exchange, size: 20, color: emerald),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: widget.dark
              ? const Color(0xFF064E3B).withOpacity(0.35)
              : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.dark
                ? emerald.withOpacity(0.35)
                : const Color(0xFFA7F3D0),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.currency_exchange, size: 16, color: emerald),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: emerald,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailNavTile extends StatelessWidget {
  const _RailNavTile({
    required this.chrome,
    required this.colors,
    required this.extended,
    required this.selected,
    required this.destination,
    required this.onTap,
    this.groupActive = false,
    this.expanded = false,
    this.badge,
  });

  final DesktopShellChrome chrome;
  final _RailChromeColors colors;
  final bool extended;
  final bool selected;
  final bool groupActive;
  final bool expanded;
  final ShellDestination destination;
  final VoidCallback onTap;
  final ShellNavBadge? badge;

  Widget _icon(Color color) {
    final active = selected || groupActive;
    final glyph = active
        ? (destination.lucideSelectedIcon ?? destination.lucideIcon)
        : destination.lucideIcon;
    if (glyph != null) {
      return LucideIcon(glyph, size: 22, color: color);
    }
    return Icon(
      active ? destination.selectedIcon : destination.icon,
      size: 22,
      color: color,
    );
  }

  Widget _iconWithBadge(Color color) {
    final icon = _icon(color);
    if (badge == null) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -6,
          top: -4,
          child: ShellNavBadgeView(badge: badge, compact: true),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = selected && !destination.hasChildren;
    final bg = highlight ? colors.selectedFill : Colors.transparent;
    final fg = highlight
        ? colors.selectedFg
        : (groupActive ? colors.selectedFg : colors.label);
    final iconColor = highlight
        ? colors.selectedFg
        : (groupActive ? colors.selectedFg : colors.idleIcon);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: (!themeDark && highlight)
                ? Border(
                    left: BorderSide(color: colors.selectedFg, width: 3),
                  )
                : null,
          ),
          child: Tooltip(
            message: destination.label,
            waitDuration: const Duration(milliseconds: 350),
            child: extended
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        _icon(iconColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            destination.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: (highlight || groupActive)
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: fg,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          ShellNavBadgeView(badge: badge),
                          const SizedBox(width: 6),
                        ],
                        if (destination.hasChildren)
                          AnimatedRotation(
                            turns: expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 220),
                            child: LucideIcon(
                              LucideGlyph.chevronDown,
                              size: 16,
                              color: colors.muted,
                            ),
                          ),
                      ],
                    ),
                  )
                : SizedBox(
                    height: 48,
                    child: Center(child: _iconWithBadge(iconColor)),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RailNestedNavTile extends StatelessWidget {
  const _RailNestedNavTile({
    required this.chrome,
    required this.colors,
    required this.selected,
    required this.destination,
    required this.onTap,
  });

  final DesktopShellChrome chrome;
  final _RailChromeColors colors;
  final bool selected;
  final ShellDestination destination;
  final VoidCallback onTap;

  Widget _icon(Color color) {
    final glyph = selected
        ? (destination.lucideSelectedIcon ?? destination.lucideIcon)
        : destination.lucideIcon;
    if (glyph != null) {
      return LucideIcon(glyph, size: 18, color: color);
    }
    return Icon(
      selected ? destination.selectedIcon : destination.icon,
      size: 18,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeDark = Theme.of(context).brightness == Brightness.dark;
    final bg = selected ? colors.selectedFill : Colors.transparent;
    final fg = selected ? colors.selectedFg : colors.label;
    final iconColor = selected ? colors.selectedFg : colors.idleIcon;
    final borderColor = selected
        ? colors.selectedFg
        : (themeDark ? const Color(0xFF334155) : colors.border);

    return Material(
      color: bg,
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(10)),
            border: Border(
              left: BorderSide(color: borderColor, width: 2),
            ),
          ),
          child: Tooltip(
            message: destination.label,
            waitDuration: const Duration(milliseconds: 350),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _icon(iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
