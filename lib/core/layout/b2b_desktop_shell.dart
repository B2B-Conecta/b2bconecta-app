import 'package:flutter/material.dart';

import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'shell/admin_shell_top_bar.dart';
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
    this.onMessagesTap,
    this.unreadMessages = 0,
    required this.onOpenSettings,
    this.onOpenProfile,
    this.onOpenNotificationPrefs,
    required this.onSignOut,
    required this.railBadgeLabel,
    this.trailingActions = const [],
    this.railStatusBuilder,
    this.chrome = DesktopShellChrome.light,
    this.showGlobalSearch = false,
    this.showBcvFooter = false,
    this.pageIndex,
    this.railSelectionActive = true,
    this.accountFooterSelected = false,
    this.breadcrumbsOverride,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<ShellDestination> destinations;
  final List<Widget> pages;
  final ProfileModel profile;
  final int unreadNotifications;
  final void Function(BuildContext anchorContext) onNotificationTap;
  final VoidCallback? onMessagesTap;
  final int unreadMessages;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenNotificationPrefs;
  final Future<void> Function() onSignOut;
  final String railBadgeLabel;
  final List<Widget> trailingActions;

  /// Bloque opcional sobre la tarjeta de cuenta; recibe si el rail está expandido.
  final Widget Function(bool extended)? railStatusBuilder;

  /// [DesktopShellChrome.darkCorporate] alinea el panel con el chrome admin.
  final DesktopShellChrome chrome;

  /// Búsqueda global tipo admin (⌘K). Por defecto off en B2B.
  final bool showGlobalSearch;

  final bool showBcvFooter;

  /// Índice del contenido ([IndexedStack]); útil si Perfil no está en el rail.
  final int? pageIndex;

  /// Si false, ningún ítem del rail queda seleccionado.
  final bool railSelectionActive;

  /// Resalta la tarjeta inferior de cuenta.
  final bool accountFooterSelected;

  final List<AdminShellBreadcrumb>? breadcrumbsOverride;

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
      railBadgeLabel: railBadgeLabel,
      trailingActions: trailingActions,
      railStatusBuilder: railStatusBuilder,
      chrome: chrome,
      showGlobalSearch: showGlobalSearch,
      showBcvFooter: showBcvFooter,
      pageIndex: pageIndex,
      railSelectionActive: railSelectionActive,
      accountFooterSelected: accountFooterSelected,
      breadcrumbsOverride: breadcrumbsOverride,
    );
  }
}
