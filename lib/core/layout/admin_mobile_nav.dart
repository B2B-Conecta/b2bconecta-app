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
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxHeight < 48 || constraints.maxWidth < 48) {
              return const SizedBox.shrink();
            }
            return SizedBox(
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
        );
          },
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Más secciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verificación, soporte, cuentas y perfil',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: more.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                  ),
                  itemBuilder: (context, i) {
                    final selected = currentIndex == primaryCount + i;
                    final destination = more[i];
                    return Material(
                      color: selected
                          ? AppColors.brandBlueContainer
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => Navigator.of(ctx).pop(primaryCount + i),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? AppColors.brand
                                  : AppColors.borderSubtle,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                selected
                                    ? destination.selectedIcon
                                    : destination.icon,
                                size: 22,
                                color: selected
                                    ? AppColors.brand
                                    : AppColors.textSecondary,
                              ),
                              const Spacer(),
                              Text(
                                destination.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: selected
                                      ? AppColors.brand
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (destination.subtitle != null)
                                Text(
                                  destination.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 28 || constraints.maxWidth < 8) {
            return const SizedBox.expand();
          }
          return Column(
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
          );
        },
      ),
    );
  }
}
