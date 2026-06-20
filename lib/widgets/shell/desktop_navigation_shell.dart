import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../models/profile_role_labels.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_breakpoints.dart';
import '../admin_content_frame.dart';
import '../motolink_pro_logo.dart';
import 'desktop_shell_top_bar.dart';
import 'shell_destination.dart';

/// Layout escritorio: rail lateral, barra superior y contenido centrado.
class DesktopNavigationShell extends StatelessWidget {
  const DesktopNavigationShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.pages,
    required this.profile,
    required this.unreadNotifications,
    required this.onNotificationTap,
    required this.onOpenSettings,
    required this.railBadgeLabel,
    this.trailingActions = const [],
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<ShellDestination> destinations;
  final List<Widget> pages;
  final ProfileModel profile;
  final int unreadNotifications;
  final VoidCallback onNotificationTap;
  final VoidCallback onOpenSettings;
  final String railBadgeLabel;
  final List<Widget> trailingActions;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final extended = width >= AppBreakpoints.desktopRailExtended;
    final safeIndex = selectedIndex.clamp(0, pages.length - 1);
    final dest = destinations[safeIndex.clamp(0, destinations.length - 1)];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DesktopSideRail(
            extended: extended,
            selectedIndex: safeIndex,
            destinations: destinations,
            badgeLabel: railBadgeLabel,
            profile: profile,
            onDestinationSelected: onDestinationSelected,
            onOpenSettings: onOpenSettings,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DesktopShellTopBar(
                  unreadNotifications: unreadNotifications,
                  onNotificationTap: onNotificationTap,
                  trailingActions: trailingActions,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 28, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dest.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                          height: 1.15,
                        ),
                      ),
                      if (dest.subtitle != null && dest.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Text(
                            dest.subtitle!,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.45,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: AdminContentFrame(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    child: IndexedStack(
                      index: safeIndex,
                      children: pages,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
  });

  final bool extended;
  final int selectedIndex;
  final List<ShellDestination> destinations;
  final String badgeLabel;
  final ProfileModel profile;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceTinted,
      child: Container(
        width: extended ? 232 : 80,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(extended ? 20 : 12, 20, extended ? 20 : 12, 16),
              child: Column(
                crossAxisAlignment:
                    extended ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  MotoLinkProLogo(height: extended ? 42 : 34),
                  if (extended) ...[
                    const SizedBox(height: 10),
                    Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onOpenSettings,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
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
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 16,
                        color: AppColors.brandBlue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ajustes de cuenta',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandBlue,
                        ),
                      ),
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
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade200),
            minimumSize: const Size(48, 48),
          ),
          icon: Icon(Icons.settings_outlined, color: Colors.grey.shade700),
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
    final bg = selected
        ? AppColors.brandOrange.withOpacity(0.12)
        : Colors.transparent;
    final fg = selected ? AppColors.brandOrange : AppColors.textPrimary;
    final iconColor = selected ? AppColors.brandOrange : Colors.grey.shade700;

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
                    left: BorderSide(color: AppColors.brandOrange, width: 3),
                  )
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? 14 : 8,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment:
                  extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: iconColor),
                if (extended) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
