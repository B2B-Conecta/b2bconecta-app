import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'shell/admin_shell_top_bar.dart';
import 'shell/desktop_navigation_shell.dart';
import 'shell/shell_destination.dart';
import 'shell/shell_nav_badge.dart';

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
    this.onMessagesTap,
    this.unreadMessages = 0,
    required this.onOpenSettings,
    this.onOpenProfile,
    this.onOpenNotificationPrefs,
    this.onSignOut,
    this.railStatusBuilder,
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

  final Widget Function(bool extended)? railStatusBuilder;

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<ShellDestination> destinations;
  final List<Widget> pages;
  final ProfileModel profile;
  final int unreadNotifications;
  final void Function(BuildContext anchorContext) onNotificationTap;
  final List<AdminShellBreadcrumb>? breadcrumbsOverride;
  final VoidCallback? onBreadcrumbBack;
  final Widget? contentOverride;
  final VoidCallback? onMessagesTap;
  final int unreadMessages;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenNotificationPrefs;
  final Future<void> Function()? onSignOut;
  final Object? selectedNestedId;
  final void Function(int parentIndex, Object? nestedId)?
      onNestedDestinationSelected;
  final Listenable? navBadges;
  final ShellNavBadge? Function(Object? key)? resolveNavBadge;
  final VoidCallback? onOpenDrawer;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onOpenGlobalSearch;

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
      onMessagesTap: onMessagesTap,
      unreadMessages: unreadMessages,
      onOpenSettings: onOpenSettings,
      onOpenProfile: onOpenProfile,
      onOpenNotificationPrefs: onOpenNotificationPrefs,
      onSignOut: onSignOut,
      railBadgeLabel: 'Panel administrador',
      railStatusBuilder: railStatusBuilder,
      chrome: DesktopShellChrome.darkCorporate,
      showBcvFooter: true,
      selectedNestedId: selectedNestedId,
      onNestedDestinationSelected: onNestedDestinationSelected,
      navBadges: navBadges,
      resolveNavBadge: resolveNavBadge,
      onOpenDrawer: onOpenDrawer,
      onSearchSubmitted: onSearchSubmitted,
      onOpenGlobalSearch: onOpenGlobalSearch,
      breadcrumbsOverride: breadcrumbsOverride,
      onBreadcrumbBack: onBreadcrumbBack,
      contentOverride: contentOverride,
    );
  }
}
