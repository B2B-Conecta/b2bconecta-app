import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Proporciones oficiales de vallas (escritorio 7:1, móvil 3:1).
abstract final class PromoBannerSpec {
  static const double desktopAspect = 7;
  static const double mobileAspect = 3;

  /// Ancho a partir del cual se usa creativo y marco de escritorio.
  static const double breakpoint = 600;

  static const Size desktopRecommended = Size(2100, 300);
  static const Size mobileRecommended = Size(1500, 500);

  /// Mínimos tras el recorte (evita pixelado en pantallas densas).
  static const int desktopMinWidth = 1200;
  static const int desktopMinHeight = 171; // floor(1200 / 7)
  static const int mobileMinWidth = 1200;
  static const int mobileMinHeight = 400; // 1200 / 3

  static double aspectForWidth(double width) =>
      width < breakpoint ? mobileAspect : desktopAspect;

  static bool isMobileVariant(bool mobile) => mobile;

  static double aspectRatio({required bool mobile}) =>
      mobile ? mobileAspect : desktopAspect;

  static int minWidth({required bool mobile}) =>
      mobile ? mobileMinWidth : desktopMinWidth;

  static int minHeight({required bool mobile}) =>
      mobile ? mobileMinHeight : desktopMinHeight;

  static Size recommended({required bool mobile}) =>
      mobile ? mobileRecommended : desktopRecommended;

  static String guidanceLabel({required bool mobile}) {
    final size = recommended(mobile: mobile);
    final ratio = mobile ? '3:1' : '7:1';
    final slot = mobile ? 'Móvil' : 'Escritorio';
    return '$slot: ${size.width.toInt()} × ${size.height.toInt()} px ($ratio)';
  }
}

/// Marco del carrusel: proporción fija según el ancho disponible.
Size promoBannerFrameSize(double availableWidth) {
  final width = availableWidth.isFinite && availableWidth > 0
      ? availableWidth
      : PromoBannerSpec.breakpoint;
  final ratio = PromoBannerSpec.aspectForWidth(width);
  final maxHeight = width < PromoBannerSpec.breakpoint ? 180.0 : 220.0;
  final framedWidth = math.min(width, maxHeight * ratio);
  return Size(framedWidth, framedWidth / ratio);
}

/// Compat: conserva la firma antigua usada en tests legacy.
Size promoBannerImageSize(double availableWidth, double aspectRatio) {
  final ratio =
      aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : PromoBannerSpec.mobileAspect;
  final maxHeight =
      availableWidth < PromoBannerSpec.breakpoint ? 180.0 : 220.0;
  final width = math.min(availableWidth, maxHeight * ratio);
  return Size(width, width / ratio);
}

/// Comprueba que el recorte cumple el mínimo de resolución.
String? promoBannerResolutionError({
  required int width,
  required int height,
  required bool mobile,
}) {
  final minW = PromoBannerSpec.minWidth(mobile: mobile);
  final minH = PromoBannerSpec.minHeight(mobile: mobile);
  if (width < minW || height < minH) {
    final slot = mobile ? 'móvil' : 'escritorio';
    return 'La imagen $slot queda en ${width}×$height px. '
        'Use al menos ${minW}×${minH}px (recomendado '
        '${PromoBannerSpec.recommended(mobile: mobile).width.toInt()}×'
        '${PromoBannerSpec.recommended(mobile: mobile).height.toInt()}).';
  }
  return null;
}
