import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Botón de filtro tipo «píldora» que abre un menú desplegable (uso en web/escritorio).
class FilterMenuButton extends StatelessWidget {
  const FilterMenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.menuChildren,
    this.active = false,
    this.enabled = true,
    this.tone,
  });

  final IconData icon;
  final String label;
  final List<Widget> menuChildren;
  final bool active;
  final bool enabled;

  /// Color de acento al estar activo (p. ej. rojo para alertas de pago).
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.card),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: WidgetStatePropertyAll(Colors.black.withOpacity(0.18)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.borderSubtle),
          ),
        ),
      ),
      menuChildren: menuChildren,
      builder: (context, controller, _) => FilterPillButton(
        icon: icon,
        label: label,
        active: active,
        open: controller.isOpen,
        tone: tone,
        onTap: !enabled
            ? null
            : () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// Píldora de filtro; sin [showChevron] sirve para acciones que abren un diálogo.
class FilterPillButton extends StatelessWidget {
  const FilterPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.open = false,
    this.showChevron = true,
    this.tone,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool open;
  final bool showChevron;
  final VoidCallback? onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? AppColors.brandAccent;
    final highlighted = active || open;
    final fg = active ? accent : AppColors.textPrimary;
    return Material(
      color: active ? accent.withOpacity(0.10) : AppColors.fieldFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color:
              highlighted ? accent.withOpacity(0.55) : AppColors.borderSubtle,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, 6, showChevron ? 6 : 12, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: active ? accent : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                  ),
                ),
                if (showChevron) ...[
                  const SizedBox(width: 2),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: active ? accent : AppColors.textSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opción de selección única dentro de [FilterMenuButton] (muestra ✓ si está activa).
class FilterMenuOption extends StatelessWidget {
  const FilterMenuOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: onPressed,
      leadingIcon: SizedBox(
        width: 18,
        child: selected
            ? Icon(Icons.check, size: 18, color: AppColors.brandAccent)
            : (icon == null
                ? null
                : Icon(icon, size: 16, color: AppColors.textSecondary)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Opción con casilla dentro de [FilterMenuButton]; el menú queda abierto al marcarla.
class FilterMenuCheck extends StatelessWidget {
  const FilterMenuCheck({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxMenuButton(
      value: value,
      closeOnActivate: false,
      onChanged: (v) => onChanged(v ?? false),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

/// Barra de filtros en escritorio: los botones bajan de línea en lugar de recortarse.
class FilterToolbar extends StatelessWidget {
  const FilterToolbar({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}
