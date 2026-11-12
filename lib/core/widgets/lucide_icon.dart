import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// SVG assets from Lucide, bundled locally under `assets/lucide/`.
enum LucideGlyph {
  store('store'),
  package('package'),
  packageCheck('package-check'),
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
  bellOff('bell-off'),
  bellRing('bell-ring'),
  slidersHorizontal('sliders-horizontal'),
  van('van'),
  truck('truck'),
  arrowRight('arrow-right'),
  arrowLeft('arrow-left'),
  arrowLeftRight('arrow-left-right'),
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
  fileText('file-text'),
  pencil('pencil'),
  circlePause('circle-pause'),
  circlePlay('circle-play'),
  userMinus('user-minus'),
  shieldOff('shield-off'),
  check('check'),
  maximize2('maximize-2'),
  star('star'),
  tag('tag'),
  minus('minus'),
  users('users'),
  userCheck('user-check'),
  shieldCheck('shield-check'),
  mailPlus('mail-plus'),
  chevronDown('chevron-down'),
  chevronsUpDown('chevrons-up-down'),
  user('user'),
  logOut('log-out'),
  messageSquare('message-square'),
  messageSquarePlus('message-square-plus'),
  triangleAlert('triangle-alert'),
  menu('menu'),
  trendingUp('trending-up'),
  trendingDown('trending-down'),
  dollarSign('dollar-sign'),
  percent('percent'),
  activity('activity'),
  lifeBuoy('life-buoy'),
  headset('headset'),
  headphones('headphones'),
  layoutDashboard('layout-dashboard'),
  userPlus('user-plus'),
  clipboardCheck('clipboard-check'),
  badgeDollarSign('badge-dollar-sign'),
  barChart3('bar-chart-3'),
  eye('eye'),
  eyeOff('eye-off'),
  monitor('monitor'),
  smartphone('smartphone'),
  copy('copy'),
  scanLine('scan-line'),
  landmark('landmark'),
  creditCard('credit-card'),
  download('download'),
  searchX('search-x'),
  rotateCcw('rotate-ccw'),
  circleAlert('circle-alert'),
  megaphone('megaphone'),
  undo2('undo-2');

  const LucideGlyph(this.assetName);

  final String assetName;

  String get assetPath => 'assets/lucide/$assetName.svg';
}

/// Icono Lucide con color y tamaño explícitos (stroke SVG tintado).
class LucideIcon extends StatelessWidget {
  const LucideIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color,
  });

  final LucideGlyph glyph;

  /// Tamaño del glyph (por defecto 24).
  final double size;

  /// Color de trazo. Si es null, usa [IconTheme] / onSurface.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final dimension = size > 0 ? size : (iconTheme.size ?? 24);
    final base =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    // Opaco explícito: evita glyphs “vacíos” por opacity heredada del tema.
    final foreground = Color.fromARGB(255, base.red, base.green, base.blue);

    return SizedBox(
      width: dimension,
      height: dimension,
      child: SvgPicture.asset(
        glyph.assetPath,
        width: dimension,
        height: dimension,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        // Solo colorFilter: fiable con strokes Lucide en Flutter Web.
        colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
        excludeFromSemantics: true,
        // Evitar Icons.circle_outlined (parecía un círculo vacío).
        placeholderBuilder: (_) => SizedBox(
          width: dimension,
          height: dimension,
        ),
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.help_outline,
            size: dimension * 0.9,
            color: foreground,
          );
        },
      ),
    );
  }
}
