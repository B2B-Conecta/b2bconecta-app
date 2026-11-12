import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';

/// Scaffold adaptativo del AppShell: en anchos &lt; [AppBreakpoints.mobileMenu]
/// el menú lateral se entrega como [drawer] (cajón deslizable).
///
/// En escritorio el caller suele omitir [drawer] y renderizar el rail fuera
/// de este widget (`DesktopNavigationShell`).
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.scaffoldKey,
    this.appBar,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBody = false,
    this.backgroundColor,
  });

  final GlobalKey<ScaffoldState>? scaffoldKey;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? drawer;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBody;
  final Color? backgroundColor;

  /// `true` cuando el shell debe usar cajón en lugar de rail fijo.
  static bool useDrawer(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;

  /// Área táctil mínima recomendada (WCAG / Material).
  static const double minTouchTarget = AppBreakpoints.minTouchTarget;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: backgroundColor ?? theme.background,
      appBar: appBar,
      drawer: drawer,
      endDrawer: endDrawer,
      extendBody: extendBody,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
