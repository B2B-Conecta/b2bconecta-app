import 'package:flutter/material.dart';

import 'app_breakpoints.dart';

/// Centra y limita el ancho del contenido admin en pantallas anchas.
class AdminContentFrame extends StatelessWidget {
  const AdminContentFrame({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.adminContentMaxWidth,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 24),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
