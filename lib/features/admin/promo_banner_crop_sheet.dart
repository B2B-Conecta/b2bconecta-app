import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/features/catalog/promo_banner_layout.dart';

/// Resultado del recorte obligatorio de una valla.
class PromoBannerCropResult {
  const PromoBannerCropResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.extension,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  /// Extensión sin punto (`jpeg`).
  final String extension;
}

/// Encaja la imagen completa en el tamaño pedido, centrada y sin recorte.
/// El espacio sobrante toma el color de las esquinas.
PromoBannerCropResult fitPromoBannerImage(
  Uint8List bytes, {
  required int width,
  required int height,
}) {
  if (width <= 0 || height <= 0) {
    throw const FormatException('El tamaño del banner no es válido.');
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    throw const FormatException('No se pudo abrir esta imagen.');
  }
  final source = img.bakeOrientation(decoded);
  final scale = math.min(width / source.width, height / source.height);
  final resizedW = math.max(1, (source.width * scale).round()).clamp(1, width);
  final resizedH =
      math.max(1, (source.height * scale).round()).clamp(1, height);
  final resized = img.copyResize(
    source,
    width: resizedW,
    height: resizedH,
    interpolation: img.Interpolation.average,
  );
  final canvas = img.Image(width: width, height: height);
  img.fill(canvas, color: _bannerEdgeColor(source));
  img.compositeImage(
    canvas,
    resized.hasAlpha ? _flattenBanner(resized) : resized,
    dstX: ((width - resizedW) / 2).round(),
    dstY: ((height - resizedH) / 2).round(),
  );
  return PromoBannerCropResult(
    bytes: Uint8List.fromList(img.encodeJpg(canvas, quality: 88)),
    width: width,
    height: height,
    extension: 'jpeg',
  );
}

img.Color _bannerEdgeColor(img.Image source) {
  img.Pixel sample(int x, int y) => source.getPixel(
        x.clamp(0, source.width - 1),
        y.clamp(0, source.height - 1),
      );
  final corners = [
    sample(0, 0),
    sample(source.width - 1, 0),
    sample(0, source.height - 1),
    sample(source.width - 1, source.height - 1),
  ];
  var r = 0;
  var g = 0;
  var b = 0;
  for (final corner in corners) {
    r += corner.r.toInt();
    g += corner.g.toInt();
    b += corner.b.toInt();
  }
  final count = corners.length;
  return img.ColorRgb8(r ~/ count, g ~/ count, b ~/ count);
}

img.Image _flattenBanner(img.Image source) {
  final base = img.Image(width: source.width, height: source.height);
  img.fill(base, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(base, source);
  return base;
}

/// Diálogo de recorte con aspect ratio fijo (panel móvil).
Future<PromoBannerCropResult?> showPromoBannerCropSheet({
  required BuildContext context,
  required Uint8List imageBytes,
  required bool mobile,
  double? aspectRatio,
  int? minWidth,
  int? minHeight,
  Size? recommended,
  String? ratioLabel,
}) {
  return showDialog<PromoBannerCropResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PromoBannerCropDialog(
      imageBytes: imageBytes,
      mobile: mobile,
      aspectRatio: aspectRatio,
      minWidth: minWidth,
      minHeight: minHeight,
      recommended: recommended,
      ratioLabel: ratioLabel,
    ),
  );
}

class _PromoBannerCropDialog extends StatefulWidget {
  const _PromoBannerCropDialog({
    required this.imageBytes,
    required this.mobile,
    this.aspectRatio,
    this.minWidth,
    this.minHeight,
    this.recommended,
    this.ratioLabel,
  });

  final Uint8List imageBytes;
  final bool mobile;
  final double? aspectRatio;
  final int? minWidth;
  final int? minHeight;
  final Size? recommended;
  final String? ratioLabel;

  @override
  State<_PromoBannerCropDialog> createState() => _PromoBannerCropDialogState();
}

class _PromoBannerCropDialogState extends State<_PromoBannerCropDialog> {
  final _controller = CropController();
  bool _busy = false;
  String? _error;

  double get _aspect =>
      widget.aspectRatio ?? PromoBannerSpec.aspectRatio(mobile: widget.mobile);

  Future<void> _onCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        await _finish(croppedImage);
      case CropFailure(:final cause):
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'No se pudo recortar: $cause';
        });
    }
  }

  Future<void> _finish(Uint8List cropped) async {
    try {
      final decoded = img.decodeImage(cropped);
      if (decoded == null) {
        throw StateError('Imagen inválida tras el recorte.');
      }
      final width = decoded.width;
      final height = decoded.height;
      final resolutionError = promoBannerResolutionError(
        width: width,
        height: height,
        mobile: widget.mobile,
        minWidth: widget.minWidth,
        minHeight: widget.minHeight,
        recommended: widget.recommended,
      );
      if (resolutionError != null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = resolutionError;
        });
        return;
      }

      // Normaliza a JPEG para peso estable en el bucket.
      final encoded = Uint8List.fromList(
        img.encodeJpg(decoded, quality: 88),
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        PromoBannerCropResult(
          bytes: encoded,
          width: width,
          height: height,
          extension: 'jpeg',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = size.width >= 900 ? 720.0 : size.width - 24;
    final maxH = size.height * 0.86;
    final ratioLabel =
        widget.ratioLabel ?? (widget.mobile ? '3:1' : '7:1');
    final slot = widget.mobile ? 'móvil' : 'escritorio';
    final guidance = widget.recommended == null
        ? '${PromoBannerSpec.guidanceLabel(mobile: widget.mobile)}.'
        : 'Escritorio: ${widget.recommended!.width.toInt()} × '
            '${widget.recommended!.height.toInt()} px.';
    final theme = B2BThemeExtension.of(context);

    return Dialog(
      backgroundColor: theme.dialogSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Recortar valla ($slot · $ratioLabel)',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Encuadre la creativa dentro del marco fijo. '
                'Arrastre o pellizque para ajustar. $guidance',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: theme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: theme.textPrimary.withOpacity(0.87),
                    child: Crop(
                      image: widget.imageBytes,
                      controller: _controller,
                      aspectRatio: _aspect,
                      withCircleUi: false,
                      interactive: true,
                      fixCropRect: true,
                      baseColor: theme.textPrimary.withOpacity(0.87),
                      maskColor: theme.textPrimary.withOpacity(0.55),
                      progressIndicator: Center(
                        child: CircularProgressIndicator(color: theme.brand),
                      ),
                      onCropped: _onCropped,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _busy = true;
                              _error = null;
                            });
                            _controller.crop();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.brand,
                      foregroundColor: theme.surfaceCard,
                    ),
                    icon: _busy
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.surfaceCard,
                            ),
                          )
                        : const Icon(Icons.crop),
                    label: Text(_busy ? 'Recortando…' : 'Usar recorte'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
