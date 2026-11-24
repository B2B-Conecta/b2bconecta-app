import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

class AliadoQuickFilterRow extends StatelessWidget {
  const AliadoQuickFilterRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          primary: false,
          physics: const BouncingScrollPhysics(),
          child: Row(children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              children[index],
            ],
          ]),
        ),
      );
}

class AliadoQuickFilterChip extends StatelessWidget {
  const AliadoQuickFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = selected
        ? AppColors.white
        : dark
            ? AppColors.textPrimary
            : const Color(0xFF000010);
    final active = dark ? AppColors.brandAccent : const Color(0xFF004BDD);
    final idle = dark ? AppColors.surfaceTinted : const Color(0xFFF0F2F5);
    final radius = BorderRadius.circular(999);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? active : idle,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 33),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    IconTheme.merge(
                      data: IconThemeData(size: 14, color: foreground),
                      child: icon!,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                      height: 1.1,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 5),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AliadoSortLabel extends StatelessWidget {
  const AliadoSortLabel({super.key, required this.label, this.resultCount});

  final String label;
  final String? resultCount;

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          if (resultCount case final count?) TextSpan(text: '$count · '),
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const TextSpan(text: ' ↓'),
        ]),
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          height: 1.25,
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.onSurface
              : const Color(0xFF000010),
        ),
      );
}
