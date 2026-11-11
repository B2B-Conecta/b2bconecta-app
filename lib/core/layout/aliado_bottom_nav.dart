import 'package:flutter/material.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

import 'package:motolink_pro_app/app/aliado_shell_tabs.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/ios_chrome.dart';

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
      index: AliadoShellTabs.inicio,
      label: 'Inicio',
      icon: LucideGlyph.house,
    ),
    _AliadoNavItem(
      index: AliadoShellTabs.pedidos,
      label: 'Pedidos',
      icon: LucideGlyph.package,
    ),
    _AliadoNavItem(
      index: AliadoShellTabs.catalogo,
      label: 'Catálogo',
      icon: LucideGlyph.layoutGrid,
      circled: true,
    ),
    _AliadoNavItem(
      index: AliadoShellTabs.favoritos,
      label: 'Favoritos',
      icon: LucideGlyph.heart,
    ),
    _AliadoNavItem(
      index: AliadoShellTabs.perfil,
      label: 'Perfil',
      icon: LucideGlyph.userRound,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final surface = dark ? const Color(0xFF141C29) : Colors.white;
    final tint = surface.withOpacity(highContrast ? 1 : (dark ? .85 : .78));
    final labelExtra =
        (MediaQuery.textScalerOf(context).scale(11) - 11).clamp(0.0, 20.0);
    final height = 74 + labelExtra * 1.2;
    const radius = BorderRadius.all(Radius.circular(26));
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 7),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
                top: 8,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IosGlass(
                    radius: radius,
                    tint: tint,
                    border: dark ? Colors.white24 : const Color(0xFFE1E7F1),
                    child: const SizedBox.expand(),
                  ),
                )),
            Material(
              color: Colors.transparent,
              child: Row(children: [
                for (final item in _items)
                  Expanded(
                      child: _AliadoNavButton(
                    item: item,
                    selected: currentIndex == item.index,
                    onTap: () => onTap(item.index),
                  )),
              ]),
            ),
          ],
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
    this.circled = false,
  });

  final int index;
  final String label;
  final LucideGlyph icon;
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? (dark ? AppColors.brandAccent : const Color(0xFF0052FF))
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = item.icon;
    return Semantics(
        button: true,
        selected: selected,
        child: IosPressable(
          onTap: onTap,
          radius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (item.circled)
                _CatalogCircle(
                  selected: selected,
                  icon: icon,
                )
              else
                LucideIcon(
                  icon,
                  size: 22,
                  color: color,
                ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      fontFamily: iosChromeFontFallback.first,
                      fontFamilyFallback: iosChromeFontFallback,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
            ],
          ),
        ));
  }
}

class _CatalogCircle extends StatelessWidget {
  const _CatalogCircle({
    required this.selected,
    required this.icon,
  });

  final bool selected;
  final LucideGlyph icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFF003BBF) : const Color(0xFF0052FF),
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33003BBF), blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: Center(
        child: LucideIcon(
          icon,
          size: 21,
          color: Colors.white,
        ),
      ),
    );
  }
}
