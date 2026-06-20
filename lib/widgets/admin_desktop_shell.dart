import 'package:flutter/material.dart';

import '../models/profile_model.dart';
import 'shell/desktop_navigation_shell.dart';
import 'shell/shell_destination.dart';

/// Alias histórico — mismos campos que [ShellDestination].
typedef AdminShellDestination = ShellDestination;

/// Shell web/escritorio para administradores.
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
  final List<ShellDestination> destinations;
  final List<Widget> pages;
  final ProfileModel profile;
  final int unreadNotifications;
  final VoidCallback onNotificationTap;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return DesktopNavigationShell(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: destinations,
      pages: pages,
      profile: profile,
      unreadNotifications: unreadNotifications,
      onNotificationTap: onNotificationTap,
      onOpenSettings: onOpenSettings,
      railBadgeLabel: 'Panel administrador',
    );
  }
}
