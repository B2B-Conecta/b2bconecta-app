import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Fila única de chips con scroll horizontal, bajo el buscador principal.
class FilterChipStrip extends StatelessWidget {
  const FilterChipStrip({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Chip seleccionable del design system admin (borde fino, relleno suave).
class StripChip extends StatelessWidget {
  const StripChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.tone,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Color de acento al estar activo (p. ej. rojo para «Pago pendiente»).
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? AppColors.brandAccent;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? accent : AppColors.textPrimary,
        ),
      ),
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 16,
              color: selected ? accent : AppColors.textSecondary,
            ),
      selected: selected,
      showCheckmark: false,
      onSelected: onTap == null ? null : (_) => onTap!(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: accent.withOpacity(0.12),
      backgroundColor: AppColors.fieldFill,
      side: BorderSide(
        color: selected ? accent.withOpacity(0.55) : AppColors.borderSubtle,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

/// Separador vertical fino entre grupos de chips.
class StripDivider extends StatelessWidget {
  const StripDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppColors.borderSubtle,
    );
  }
}
