import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

/// Claves estables para badges del panel admin.
enum AdminShellBadgeKey {
  /// Pedidos activos (carritos en curso).
  pedidos,

  /// Reclamos de soporte abiertos / sin leer.
  mensajes,

  /// Tasa BCV u atención de configuración del sistema.
  configuracion,

  /// Cuentas pendientes de revisión KYC.
  usuarios,
}

/// Indicador reactivo en un destino del shell.
sealed class ShellNavBadge {
  const ShellNavBadge();

  /// Contador numérico (oculto si [count] ≤ 0).
  const factory ShellNavBadge.count(int count) = ShellNavCountBadge;

  /// Punto azul de actividad (p. ej. chat sin leer).
  const factory ShellNavBadge.dot() = ShellNavDotBadge;

  /// Advertencia naranja (acción pendiente).
  const factory ShellNavBadge.warning() = ShellNavWarningBadge;
}

final class ShellNavCountBadge extends ShellNavBadge {
  const ShellNavCountBadge(this.count);
  final int count;

  bool get visible => count > 0;

  String get label {
    if (count > 99) return '99+';
    return '$count';
  }
}

final class ShellNavDotBadge extends ShellNavBadge {
  const ShellNavDotBadge();
}

final class ShellNavWarningBadge extends ShellNavBadge {
  const ShellNavWarningBadge();
}

/// Pinta el badge con animación al cambiar el contador.
class ShellNavBadgeView extends StatelessWidget {
  const ShellNavBadgeView({
    super.key,
    required this.badge,
    this.compact = false,
  });

  final ShellNavBadge? badge;
  final bool compact;

  static const _countRed = Color(0xFFEF4444);
  static const _dotBlue = Color(0xFF3B82F6);
  static const _warnAmber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final b = badge;
    if (b == null) return const SizedBox.shrink();
    final onFilled = B2BThemeExtension.of(context).surfaceCard;

    return switch (b) {
      ShellNavCountBadge(:final count) when count <= 0 =>
        const SizedBox.shrink(),
      ShellNavCountBadge(:final label) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Container(
            key: ValueKey<String>('count-$label'),
            constraints: BoxConstraints(
              minWidth: compact ? 16 : 18,
              minHeight: compact ? 16 : 18,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 4 : 5,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: _countRed,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: onFilled,
                fontSize: compact ? 9.5 : 10.5,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
        ),
      ShellNavDotBadge() => AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Container(
            key: const ValueKey('dot'),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _dotBlue,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ShellNavWarningBadge() => AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: LucideIcon(
            LucideGlyph.triangleAlert,
            key: const ValueKey('warn'),
            size: compact ? 14 : 16,
            color: _warnAmber,
          ),
        ),
    };
  }
}
