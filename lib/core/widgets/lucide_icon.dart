import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG assets from Lucide, bundled locally.
enum LucideGlyph {
  store('store'),
  package('package'),
  circleCheck('circle-check'),
  shoppingCart('shopping-cart'),
  shoppingBag('shopping-bag'),
  chevronRight('chevron-right'),
  plus('plus'),
  close('x'),
  image('image'),
  imageOff('image-off'),
  search('search'),
  handbag('handbag'),
  inbox('inbox'),
  messageCircle('message-circle'),
  bell('bell'),
  slidersHorizontal('sliders-horizontal'),
  van('van'),
  truck('truck'),
  arrowRight('arrow-right'),
  arrowLeft('arrow-left'),
  messagesSquare('messages-square'),
  refreshCw('refresh-cw'),
  grid('grid-2x2'),
  layoutGrid('layout-grid'),
  chevronLeft('chevron-left'),
  house('house'),
  heart('heart'),
  userRound('user-round'),
  droplet('droplet'),
  circle('circle'),
  disc('disc'),
  settings('settings'),
  zap('zap'),
  wrench('wrench'),
  trash2('trash-2'),
  check('check'),
  maximize2('maximize-2'),
  star('star'),
  tag('tag'),
  minus('minus');

  const LucideGlyph(this.assetName);

  final String assetName;
}

class LucideIcon extends StatelessWidget {
  const LucideIcon(this.glyph, {super.key, this.size, this.color});

  final LucideGlyph glyph;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final dimension = size ?? iconTheme.size ?? 24;
    final foreground =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      'assets/lucide/${glyph.assetName}.svg',
      width: dimension,
      height: dimension,
      colorFilter: ColorFilter.mode(
        foreground.withOpacity(foreground.opacity * (iconTheme.opacity ?? 1)),
        BlendMode.srcIn,
      ),
      excludeFromSemantics: true,
    );
  }
}
