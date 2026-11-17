import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

typedef CatalogEditedPhoto = ({Uint8List bytes, String extension});

const catalogMaskSide = 320;

class CatalogPhotoAdjustments {
  const CatalogPhotoAdjustments({
    this.turns = 0,
    this.brightness = 1,
    this.center = false,
    this.whiteBackground = false,
    this.quality = 90,
    this.removeBackground = false,
    this.fill = .8,
    this.shadow = false,
    this.contrast = 1,
    this.sharpness = 0,
    this.denoise = 0,
  });

  final int turns;
  final double brightness;
  final bool center;
  final bool whiteBackground;
  final int quality;
  final bool removeBackground;
  final double fill;
  final bool shadow;
  final double contrast;
  final double sharpness;
  final double denoise;
}

typedef CatalogPhotoEditRequest = ({
  Uint8List bytes,
  CatalogPhotoAdjustments adjustments,
  bool preview,
  bool lossless,
});

/// Canonical PNG before segmentation so its mask and source share orientation.
CatalogEditedPhoto normalizeCatalogPhoto(Uint8List bytes) =>
    renderCatalogPhoto((
      bytes: bytes,
      adjustments: const CatalogPhotoAdjustments(),
      preview: false,
      lossless: true,
    ));

/// Keeps the original bytes unless the photo is larger than 1600 px or 2 MB.
bool catalogMasterNeedsFit(Uint8List bytes) {
  if (bytes.length > 2 * 1024 * 1024) return true;
  final info = img.findDecoderForData(bytes)?.startDecode(bytes);
  if (info == null) return false;
  return math.max(info.width, info.height) > 1600;
}

/// Downscales only. Never enlarges a small master. JPEG quality 90.
Uint8List fitCatalogMasterBytes(Uint8List bytes) {
  var photo = _decode(bytes);
  if (math.max(photo.width, photo.height) > 1600) {
    photo = _fit(photo, 1600);
  }
  return Uint8List.fromList(img.encodeJpg(photo, quality: 90));
}

CatalogEditedPhoto renderCatalogPhoto(CatalogPhotoEditRequest request) =>
    renderCatalogPhotoWithMask((request: request, mask: null));

CatalogEditedPhoto renderCatalogPhotoWithMask(
  ({CatalogPhotoEditRequest request, Uint8List? mask}) input,
) {
  final request = input.request;
  var photo = _decode(request.bytes);
  final settings = request.adjustments;
  if (input.mask case final mask?) photo = _cutOut(photo, mask);
  if (settings.turns % 4 != 0) {
    photo = img.copyRotate(photo, angle: settings.turns * 90);
  }

  final maxSide = request.preview ? 640 : 1600;
  if (math.max(photo.width, photo.height) > maxSide) {
    photo = _fit(photo, maxSide);
  }
  photo = _enhance(photo, settings);

  if (settings.center || settings.whiteBackground) {
    photo = _frame(photo, settings, maxSide, input.mask != null);
  }

  if (request.lossless || (photo.hasAlpha && !settings.whiteBackground)) {
    final bytes = img.encodePng(photo, level: 6);
    if (bytes.length > 10 * 1024 * 1024) {
      throw const FormatException('La imagen editada supera 10 MiB.');
    }
    return (bytes: bytes, extension: 'png');
  }
  return (
    bytes: img.encodeJpg(photo, quality: settings.quality),
    extension: 'jpeg'
  );
}

img.Image _decode(Uint8List bytes) {
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width <= 0 || info.height <= 0) {
    throw const FormatException('No se pudo abrir esta imagen.');
  }
  if (info.width * info.height > 25000000) {
    throw const FormatException(
        'Imagen demasiado grande para editar (máximo 25 MP).');
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null)
    throw const FormatException('No se pudo abrir esta imagen.');
  return img.bakeOrientation(decoded);
}

img.Image _fit(img.Image photo, int side) {
  if (math.max(photo.width, photo.height) == side) return photo;
  return img.copyResize(
    photo,
    width: photo.width >= photo.height ? side : null,
    height: photo.height > photo.width ? side : null,
    interpolation: img.Interpolation.average,
  );
}

img.Image _masked(img.Image photo, Uint8List mask) {
  if (mask.length != catalogMaskSide * catalogMaskSide) {
    throw const FormatException('El recorte no tiene el tamaño esperado.');
  }
  final matte = img.Image(
      width: catalogMaskSide, height: catalogMaskSide, numChannels: 1);
  for (final pixel in matte) {
    pixel.r = mask[pixel.y * catalogMaskSide + pixel.x];
  }
  final expanded = img.copyResize(
    matte,
    width: photo.width,
    height: photo.height,
    interpolation: img.Interpolation.linear,
  );
  final result = photo.convert(format: img.Format.uint8, numChannels: 4);
  for (final pixel in result) {
    pixel.a = (pixel.a * expanded.getPixel(pixel.x, pixel.y).r / 255).round();
  }
  return result;
}

img.Image _cutOut(img.Image photo, Uint8List mask) {
  final result = _masked(photo, mask);
  var left = result.width;
  var top = result.height;
  var right = -1;
  var bottom = -1;
  for (final pixel in result) {
    if (pixel.a < 20) continue;
    left = math.min(left, pixel.x);
    right = math.max(right, pixel.x);
    top = math.min(top, pixel.y);
    bottom = math.max(bottom, pixel.y);
  }
  if (right < left ||
      bottom < top ||
      (right - left + 1) * (bottom - top + 1) <
          result.width * result.height * .01) {
    throw const FormatException(
        'El recorte dejó muy poca pieza. Revisa el borde.');
  }
  return img.copyCrop(result,
      x: left, y: top, width: right - left + 1, height: bottom - top + 1);
}

CatalogEditedPhoto previewCatalogMask(
    ({Uint8List bytes, Uint8List mask}) input) {
  final photo = _decode(input.bytes);
  return (
    bytes: img.encodePng(
        _masked(_fit(photo, math.min(640, math.max(photo.width, photo.height))),
            input.mask),
        level: 1),
    extension: 'png',
  );
}

img.Image _frame(img.Image photo, CatalogPhotoAdjustments settings, int maxSide,
    bool cutOut) {
  final longest = math.max(photo.width, photo.height);
  final fill = settings.fill.clamp(.60, .88);
  final framed = settings.center && cutOut;
  final side = framed ? math.min(maxSide, (longest / fill).ceil()) : longest;
  final content = framed
      ? _fit(photo, math.min(longest, math.max(1, (side * fill).round())))
      : photo;
  final width = settings.center ? side : content.width;
  final height = settings.center ? side : content.height;
  final canvas = img.Image(
      width: width,
      height: height,
      numChannels: settings.whiteBackground ? 3 : 4);
  if (settings.whiteBackground)
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  final x = (width - content.width) ~/ 2;
  var y = (height - content.height) ~/ 2;
  if (framed && settings.shadow && settings.whiteBackground) {
    y -= (side * .01).round();
    final radiusX = math.max(1, content.width * .32);
    final radiusY = math.max(1, side * .018);
    final shadowY = y + content.height;
    for (final pixel in canvas) {
      final dx = (pixel.x - width / 2) / radiusX;
      final dy = (pixel.y - shadowY) / radiusY;
      final distance = dx * dx + dy * dy;
      if (distance > 9) continue;
      final gray = (255 - 30 * math.exp(-distance / 2)).round();
      pixel.setRgb(gray, gray, gray);
    }
  }
  return img.compositeImage(canvas, content, dstX: x, dstY: y);
}

// Edge-aware smoothing and restrained sharpening, adapted from Conecta Fotos.
img.Image _enhance(img.Image photo, CatalogPhotoAdjustments settings) {
  if (settings.brightness != 1 || settings.contrast != 1) {
    photo = img.adjustColor(photo,
        brightness: settings.brightness, contrast: settings.contrast);
  }
  if (settings.denoise == 0 && settings.sharpness == 0) return photo;
  final result = photo.convert(format: img.Format.uint8, numChannels: 4);
  if (settings.denoise > 0) {
    final source = img.Image.from(result);
    for (final pixel in result) {
      if (pixel.a < 128 ||
          pixel.x == 0 ||
          pixel.y == 0 ||
          pixel.x == result.width - 1 ||
          pixel.y == result.height - 1) continue;
      final center = source.getPixel(pixel.x, pixel.y);
      num r = 0, g = 0, b = 0;
      var count = 0;
      for (var y = -1; y <= 1; y++) {
        for (var x = -1; x <= 1; x++) {
          final neighbor = source.getPixel(pixel.x + x, pixel.y + y);
          if (neighbor.a < 128 ||
              (center.r - neighbor.r).abs() > 30 ||
              (center.g - neighbor.g).abs() > 30 ||
              (center.b - neighbor.b).abs() > 30) continue;
          r += neighbor.r;
          g += neighbor.g;
          b += neighbor.b;
          count++;
        }
      }
      final strength = settings.denoise;
      pixel.setRgb(
          center.r * (1 - strength) + r / count * strength,
          center.g * (1 - strength) + g / count * strength,
          center.b * (1 - strength) + b / count * strength);
    }
  }
  if (settings.sharpness > 0) {
    final source = img.Image.from(result);
    for (final pixel in result) {
      if (pixel.a < 128 ||
          pixel.x == 0 ||
          pixel.y == 0 ||
          pixel.x == result.width - 1 ||
          pixel.y == result.height - 1) continue;
      final left = source.getPixel(pixel.x - 1, pixel.y);
      final right = source.getPixel(pixel.x + 1, pixel.y);
      final top = source.getPixel(pixel.x, pixel.y - 1);
      final bottom = source.getPixel(pixel.x, pixel.y + 1);
      if ([left, right, top, bottom].any((neighbor) => neighbor.a < 128))
        continue;
      num sharpen(num base, num sum) =>
          (base + ((base - sum / 4) * settings.sharpness).clamp(-24, 24))
              .clamp(0, 255);
      pixel.setRgb(
          sharpen(pixel.r, left.r + right.r + top.r + bottom.r),
          sharpen(pixel.g, left.g + right.g + top.g + bottom.g),
          sharpen(pixel.b, left.b + right.b + top.b + bottom.b));
    }
  }
  return !photo.hasAlpha ? result.convert(numChannels: 3) : result;
}
