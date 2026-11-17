import 'package:flutter/material.dart';

/// Navigator del inventario del importador.
///
/// Carga masiva, fotos y la ficha se abren dentro del panel: el rail, la barra
/// superior y la barra inferior siguen visibles y cambian de sección. Volver a
/// tocar Inventario cierra esa pila y regresa al catálogo.
class ShellBodyNavigator extends StatefulWidget {
  const ShellBodyNavigator({super.key, required this.child});

  final Widget child;

  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  static void popToRoot() {
    final nav = navKey.currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.isFirst);
  }

  @override
  State<ShellBodyNavigator> createState() => _ShellBodyNavigatorState();
}

class _ShellBodyNavigatorState extends State<ShellBodyNavigator> {
  @override
  Widget build(BuildContext context) {
    return _ShellBodyHost(
      page: widget.child,
      child: Navigator(
        key: ShellBodyNavigator.navKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => const _ShellBodySlot(),
          );
        },
      ),
    );
  }
}

class _ShellBodyHost extends InheritedWidget {
  const _ShellBodyHost({required this.page, required super.child});

  final Widget page;

  static _ShellBodyHost of(BuildContext context) {
    final host = context.dependOnInheritedWidgetOfExactType<_ShellBodyHost>();
    assert(host != null, 'ShellBodyNavigator no está en el árbol');
    return host!;
  }

  @override
  bool updateShouldNotify(_ShellBodyHost oldWidget) => true;
}

class _ShellBodySlot extends StatelessWidget {
  const _ShellBodySlot();

  @override
  Widget build(BuildContext context) => _ShellBodyHost.of(context).page;
}
