import 'package:flutter/material.dart';

import '../models/profile_model.dart';
import 'shell/desktop_navigation_shell.dart';
import 'shell/shell_destination.dart';

/// Shell web/escritorio para aliados e importadores.
class B2bDesktopShell extends StatelessWidget {
  const B2bDesktopShell({
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
    required this.contextLabel,
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
  final String contextLabel;
  final List<Widget> trailingActions;

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
      railBadgeLabel: railBadgeLabel,
      contextLabel: contextLabel,
      trailingActions: trailingActions,
    );
  }
}
