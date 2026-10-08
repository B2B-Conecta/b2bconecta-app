import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/aliado_shell_tabs.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Barra de la tienda minorista. El centro es Catálogo, con círculo resaltado.
class AliadoBottomNav extends StatelessWidget {
  const AliadoBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <_AliadoNavItem>[
    _AliadoNavItem(
      index: AliadoShellTabs.pedidos,
      label: 'Pedidos',
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart,
    ),
    _AliadoNavItem(
      index: AliadoShellTabs.reputacion,
      label: 'Reputación',
      icon: Icons.star_outline,
      selectedIcon: Icons.star,
    ),
    _AliadoNavItem(
      index: AliadoShellTabs.catalogo,
      label: 'Catálogo',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view,
      circled: true,
    ),
    _AliadoNavItem(
      index: AliadoShellTabs.favoritos,
      label: 'Favoritos',
      icon: Icons.favorite_border,
      selectedIcon: Icons.favorite,
    ),
    _AliadoNavItem(
      index: AliadoShellTabs.perfil,
      label: 'Perfil',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
          height: 64,
          child: Row(
            children: [
              for (final item in _items)
                Expanded(
                  child: _AliadoNavButton(
                    item: item,
                    selected: currentIndex == item.index,
                    onTap: () => onTap(item.index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AliadoNavItem {
  const _AliadoNavItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.circled = false,
  });

  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool circled;
}

class _AliadoNavButton extends StatelessWidget {
  const _AliadoNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _AliadoNavItem item;
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
          if (item.circled)
            _CatalogCircle(
              selected: selected,
              icon: selected ? item.selectedIcon : item.icon,
            )
          else
            Icon(
              selected ? item.selectedIcon : item.icon,
              size: 22,
              color: color,
            ),
          const SizedBox(height: 2),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogCircle extends StatelessWidget {
  const _CatalogCircle({
    required this.selected,
    required this.icon,
  });

  final bool selected;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.brand : AppColors.brandBlueContainer,
        border: Border.all(
          color: AppColors.brand,
          width: selected ? 0 : 1.5,
        ),
      ),
      child: Icon(
        icon,
        size: 20,
        color: selected ? AppColors.white : AppColors.brand,
      ),
    );
  }
}
