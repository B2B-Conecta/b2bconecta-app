import 'package:flutter/material.dart';

/// Destino de navegación lateral (admin, aliado, importador).
class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String title;
  final String? subtitle;
}
