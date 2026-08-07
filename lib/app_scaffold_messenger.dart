import 'package:flutter/material.dart';

/// Messenger global para SnackBars que sobreviven cambios de ruta en [AuthGate].
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Navigator raíz de [MaterialApp] (para cerrar rutas al hacer logout).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Vuelve a la ruta inicial (login / AuthGate) descartando pantallas apiladas.
void popNavigationToRoot() {
  final nav = rootNavigatorKey.currentState;
  if (nav == null || !nav.canPop()) return;
  nav.popUntil((route) => route.isFirst);
}
