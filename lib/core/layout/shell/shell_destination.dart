import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

/// Destino de navegación lateral (admin, aliado, importador).
class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.title,
    this.subtitle,
    this.lucideIcon,
    this.lucideSelectedIcon,
    this.children = const [],
    this.id,
    this.badgeKey,
    this.bottomContentPadding = 28,
    this.compactHeaderOnScroll = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String title;
  final String? subtitle;

  /// Preferido en el rail cuando está definido (Material queda de respaldo).
  final LucideGlyph? lucideIcon;
  final LucideGlyph? lucideSelectedIcon;

  /// Sub-ítems anidados (acordeón). Vacío = hoja.
  final List<ShellDestination> children;

  /// Identificador opcional (p. ej. [AdminUsersHubSection]).
  final Object? id;

  /// Clave para resolver [ShellNavBadge] reactivo (p. ej. [AdminShellBadgeKey]).
  final Object? badgeKey;

  final double bottomContentPadding;
  final bool compactHeaderOnScroll;

  bool get hasChildren => children.isNotEmpty;
}

/// Aspecto del rail lateral compartido.
enum DesktopShellChrome {
  light,
  darkCorporate,
}
