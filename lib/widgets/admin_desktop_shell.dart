import 'package:flutter/material.dart';

import '../models/profile_model.dart';
import '../models/profile_role_labels.dart';
import '../theme/app_theme.dart';
import '../utils/app_breakpoints.dart';
import 'admin_content_frame.dart';
import 'motolink_pro_logo.dart';

/// Destino del panel admin (mismos índices que el bottom nav móvil).
class AdminShellDestination {
  const AdminShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String title;
  final String? subtitle;
}

/// Shell web/escritorio para administradores: rail lateral + área de contenido ancha.
class AdminDesktopShell extends StatelessWidget {
  const AdminDesktopShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.pages,
    required this.profile,
    required this.unreadNotifications,
    required this.onNotificationTap,
    required this.onOpenSettings,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdminShellDestination> destinations;
  final List<Widget> pages;
  final ProfileModel profile;
  final int unreadNotifications;
  final VoidCallback onNotificationTap;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final extended = width >= AppBreakpoints.adminRailExtended;
    final safeIndex = selectedIndex.clamp(0, pages.length - 1);
    final dest = destinations[safeIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 220,
            backgroundColor: AppColors.surfaceTinted,
            selectedIndex: safeIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: Padding(
              padding: EdgeInsets.fromLTRB(extended ? 16 : 8, 16, extended ? 16 : 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MotoLinkProLogo(height: extended ? 40 : 32),
                  if (extended) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Panel admin',
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
            trailing: extended
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Ajustes de cuenta',
                          onPressed: onOpenSettings,
                          icon: const Icon(Icons.settings_outlined),
                        ),
                      ],
                    ),
                  )
                : null,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminDesktopTopBar(
                  profile: profile,
                  unreadNotifications: unreadNotifications,
                  onNotificationTap: onNotificationTap,
                  onOpenSettings: onOpenSettings,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dest.title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (dest.subtitle != null && dest.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          dest.subtitle!,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: Colors.grey.shade700,
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

class _AdminDesktopTopBar extends StatelessWidget {
  const _AdminDesktopTopBar({
    required this.profile,
    required this.unreadNotifications,
    required this.onNotificationTap,
    required this.onOpenSettings,
  });

  final ProfileModel profile;
  final int unreadNotifications;
  final VoidCallback onNotificationTap;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final business = profile.businessName?.trim();
    final role = ProfileRoleLabels.labelEs(profile.role);

    return Material(
      color: AppColors.surfaceTinted,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'MotoLink · Operaciones',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              if (business != null && business.isNotEmpty) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      business,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      role,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              IconButton(
                tooltip: 'Ajustes',
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Notificaciones',
                    onPressed: onNotificationTap,
                    icon: const Icon(Icons.notifications_outlined),
                  ),
                  if (unreadNotifications > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.brandOrange,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
