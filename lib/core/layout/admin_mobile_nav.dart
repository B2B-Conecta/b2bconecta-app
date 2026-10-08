import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/shell/shell_destination.dart';

/// Barra móvil del administrador: cuatro secciones y el resto en «Más».
class AdminMobileNav extends StatelessWidget {
  const AdminMobileNav({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onSelect,
  });

  final int currentIndex;
  final List<ShellDestination> destinations;
  final ValueChanged<int> onSelect;

  static const primaryCount = 4;

  @override
  Widget build(BuildContext context) {
    final primary = destinations.take(primaryCount).toList();
    final more = destinations.skip(primaryCount).toList();
    final moreSelected = currentIndex >= primaryCount;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < primary.length; i++)
                Expanded(
                  child: _NavButton(
                    icon: currentIndex == i
                        ? primary[i].selectedIcon
                        : primary[i].icon,
                    label: primary[i].label,
                    selected: currentIndex == i,
                    onTap: () => onSelect(i),
                  ),
                ),
              if (more.isNotEmpty)
                Expanded(
                  child: _NavButton(
                    icon: moreSelected ? Icons.apps : Icons.apps_outlined,
                    label: 'Más',
                    selected: moreSelected,
                    onTap: () => _openMore(context, more),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMore(
    BuildContext context,
    List<ShellDestination> more,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Más',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                for (var i = 0; i < more.length; i++)
                  ListTile(
                    leading: Icon(
                      currentIndex == primaryCount + i
                          ? more[i].selectedIcon
                          : more[i].icon,
                      color: currentIndex == primaryCount + i
                          ? AppColors.brand
                          : AppColors.textSecondary,
                    ),
                    title: Text(
                      more[i].title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: more[i].subtitle == null
                        ? null
                        : Text(more[i].subtitle!),
                    selected: currentIndex == primaryCount + i,
                    onTap: () => Navigator.of(ctx).pop(primaryCount + i),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) onSelect(picked);
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brand : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
