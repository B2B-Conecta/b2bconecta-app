import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/profile/profile_role_labels.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/admin_content_frame.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';
import 'desktop_nav_rail_preference.dart';
import 'desktop_shell_top_bar.dart';
import 'package:motolink_pro_app/core/layout/scroll_compact_layout.dart';
import 'shell_destination.dart';

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
    required this.railBadgeLabel,
    this.trailingActions = const [],
    this.railStatusBuilder,
  });

  /// Bloque opcional sobre la tarjeta de cuenta; recibe si el rail está expandido.
  final Widget Function(bool extended)? railStatusBuilder;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<ShellDestination> destinations;
  final List<Widget> pages;
  final ProfileModel profile;
  final int unreadNotifications;
  final VoidCallback onNotificationTap;
  final VoidCallback? onMessagesTap;
  final int unreadMessages;
  final VoidCallback onOpenSettings;
  final String railBadgeLabel;
  final List<Widget> trailingActions;

  @override
  State<DesktopNavigationShell> createState() => _DesktopNavigationShellState();
}

class _DesktopNavigationShellState extends State<DesktopNavigationShell> {
  bool _railVisible = true;
  bool _prefReady = false;

  @override
  void initState() {
    super.initState();
    _loadRailPreference();
  }

  Future<void> _loadRailPreference() async {
    await DesktopNavRailPreference.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _railVisible = DesktopNavRailPreference.visible;
      _prefReady = true;
    });
  }

  Future<void> _setRailVisible(bool visible) async {
    setState(() => _railVisible = visible);
    await DesktopNavRailPreference.setVisible(visible);
  }

  @override
  Widget build(BuildContext context) {
    // Engancha al Theme: al cambiar claro/oscuro el rail y el scaffold se redibujan.
    final brightness = Theme.of(context).brightness;
    AppColors.brightness = brightness;
    final width = MediaQuery.sizeOf(context).width;
    final extended = width >= AppBreakpoints.desktopRailExtended;
    final safeIndex = widget.selectedIndex.clamp(0, widget.pages.length - 1);
    final dest =
        widget.destinations[safeIndex.clamp(0, widget.destinations.length - 1)];
    final showRail = !_prefReady || _railVisible;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.centerLeft,
            child: showRail
                ? _DesktopSideRail(
                    extended: extended,
                    selectedIndex: safeIndex,
                    destinations: widget.destinations,
                    badgeLabel: widget.railBadgeLabel,
                    profile: widget.profile,
                    onDestinationSelected: widget.onDestinationSelected,
                    onOpenSettings: widget.onOpenSettings,
                    statusBuilder: widget.railStatusBuilder,
                    onHideRail: () => _setRailVisible(false),
                  )
                : const SizedBox(width: 0),
          ),
          Expanded(
            child: ScrollCompactLayout(
                enabled: dest.compactHeaderOnScroll,
                resetKey: safeIndex,
                builder: (context, compact) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DesktopShellTopBar(
                          unreadNotifications: widget.unreadNotifications,
                          onNotificationTap: widget.onNotificationTap,
                          onMessagesTap: widget.onMessagesTap,
                          unreadMessages: widget.unreadMessages,
                          trailingActions: widget.trailingActions,
                          leading: showRail
                              ? null
                              : IconButton(
                                  tooltip: 'Mostrar menú',
                                  onPressed: () => _setRailVisible(true),
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(44, 44),
                                  ),
                                  icon: Icon(
                                    Icons.menu,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                        ),
                        _DesktopPageHeading(
                            destination: dest,
                            compact: compact,
                            hidden: ScrollCompactState.hideHeadingOf(context)),
                        Expanded(
                          child: AdminContentFrame(
                            padding: EdgeInsets.fromLTRB(
                                24, 0, 24, dest.bottomContentPadding),
                            child: IndexedStack(
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

class _DesktopSideRail extends StatelessWidget {
  const _DesktopSideRail({
    required this.extended,
    required this.selectedIndex,
    required this.destinations,
    required this.badgeLabel,
    required this.profile,
    required this.onDestinationSelected,
    required this.onOpenSettings,
    required this.onHideRail,
    this.statusBuilder,
  });

  final bool extended;
  final int selectedIndex;
  final List<ShellDestination> destinations;
  final String badgeLabel;
  final ProfileModel profile;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenSettings;
  final VoidCallback onHideRail;
  final Widget Function(bool extended)? statusBuilder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceTinted,
      child: Container(
        width: extended ? 232 : 96,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  extended ? 12 : 8, 12, extended ? 8 : 8, 8),
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
                                MotoLinkProLogo(height: 42),
                                const SizedBox(height: 10),
                                Text(
                                  badgeLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Ocultar menú',
                          onPressed: onHideRail,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(40, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                            Icons.menu_open,
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        const B2bConectaMark(size: 36),
                        const SizedBox(height: 4),
                        IconButton(
                          tooltip: 'Ocultar menú',
                          onPressed: onHideRail,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(40, 40),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                            Icons.menu_open,
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
            ),
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                itemCount: destinations.length,
                itemBuilder: (context, i) {
                  final d = destinations[i];
                  final selected = i == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _RailNavTile(
                      extended: extended,
                      selected: selected,
                      icon: selected ? d.selectedIcon : d.icon,
                      label: d.label,
                      onTap: () => onDestinationSelected(i),
                    ),
                  );
                },
              ),
            ),
            if (statusBuilder != null) statusBuilder!(extended),
            _DesktopSideRailAccountFooter(
              extended: extended,
              profile: profile,
              onOpenSettings: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSideRailAccountFooter extends StatelessWidget {
  const _DesktopSideRailAccountFooter({
    required this.extended,
    required this.profile,
    required this.onOpenSettings,
  });

  final bool extended;
  final ProfileModel profile;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final business = profile.businessName?.trim();
    final role = ProfileRoleLabels.labelEs(profile.role);
    final displayName =
        business != null && business.isNotEmpty ? business : 'Mi cuenta';

    if (extended) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onOpenSettings,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 16,
                        color: AppColors.brandLink,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(
                        'Ajustes de cuenta',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandLink,
                        ),
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      child: Tooltip(
        message: '$displayName · $role · Ajustes',
        child: IconButton(
          onPressed: onOpenSettings,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.card,
            side: BorderSide(color: AppColors.borderSubtle),
            minimumSize: const Size(48, 48),
          ),
          icon: Icon(Icons.settings_outlined, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _RailNavTile extends StatelessWidget {
  const _RailNavTile({
    required this.extended,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool extended;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg =
        selected ? AppColors.brand.withOpacity(0.12) : Colors.transparent;
    final fg = selected ? AppColors.brand : AppColors.textPrimary;
    final iconColor = selected ? AppColors.brand : AppColors.textSecondary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border(
                    left: BorderSide(color: AppColors.brand, width: 3),
                  )
                : null,
          ),
          child: Tooltip(
            message: label,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: extended ? 14 : 4,
                vertical: extended ? 12 : 8,
              ),
              child: extended
                  ? Row(
                      children: [
                        Icon(icon, size: 22, color: iconColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w600,
                              color: fg,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Icon(icon, size: 22, color: iconColor),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.15,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                            color: fg,
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
