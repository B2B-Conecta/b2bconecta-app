import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Official Material Symbols Rounded SVGs, at Google revision 10ecc147.
enum MaterialSymbolGlyph {
  home('home'),
  inventory('inventory_2'),
  grid('grid_view'),
  heart('favorite'),
  user('person'),
  box('package_2'),
  store('storefront'),
  cart('shopping_cart'),
  checkCircle('check_circle'),
  chevronRight('chevron_right'),
  plus('add'),
  close('close'),
  photo('image'),
  search('search'),
  shoppingBag('shopping_bag'),
  currencyExchange('currency_exchange'),
  inbox('inbox'),
  messageCircle('chat_bubble'),
  bell('notifications'),
  adjustments('tune'),
  truck('local_shipping'),
  arrowRight('arrow_forward'),
  messageDots('chat');

  const MaterialSymbolGlyph(this.assetName);

  final String assetName;
}

class MaterialSymbolIcon extends StatelessWidget {
  const MaterialSymbolIcon(
    this.icon, {
    super.key,
    this.filled = false,
    this.size,
    this.color,
  });

  final MaterialSymbolGlyph icon;
  final bool filled;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final dimension = size ?? theme.size ?? 24;
    final foreground =
        color ?? theme.color ?? Theme.of(context).colorScheme.onSurface;
    final variant = filled ? 'filled' : 'outline';
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SvgPicture.asset(
        'assets/material_symbols/$variant/${icon.assetName}.svg',
        width: dimension,
        height: dimension,
        colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
        excludeFromSemantics: true,
      ),
    );
  }
}
