import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';

/// Una foto del visor, con el texto que la identifica (SKU, fila o nombre).
class ProductLightboxSlide {
  const ProductLightboxSlide({required this.image, this.caption = ''});

  final ImageProvider<Object> image;
  final String caption;
}

/// Visor de fotos. Devuelve el índice visible al cerrar.
Future<int> showProductPhotoLightbox(
  BuildContext context, {
  List<ImageProvider<Object>> images = const [],
  List<ProductLightboxSlide>? slides,
  required int initialIndex,
  required String productName,
}) async {
  final resolved = slides ??
      [
        for (final image in images)
          ProductLightboxSlide(image: image, caption: productName),
      ];
  if (resolved.isEmpty) return 0;
  final last = resolved.length - 1;
  var latest = initialIndex.clamp(0, last);
  final selected = await Navigator.of(context, rootNavigator: true).push<int>(
    PageRouteBuilder<int>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, _, __) {
        return LayoutBuilder(builder: (context, constraints) {
          final mobile = constraints.maxWidth < AppBreakpoints.mobileMenu;
          final inset = mobile ? 8.0 : 20.0;
          void close() => Navigator.of(dialogContext).pop(latest);
          return ColoredBox(
            color: B2BThemeExtension.light.textPrimary.withOpacity(0.92),
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: close,
                    behavior: HitTestBehavior.opaque,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(inset),
                  child: ProductPhotoLightbox(
                    slides: resolved,
                    initialIndex: latest,
                    productName: productName,
                    onIndex: (value) => latest = value,
                  ),
                ),
              ],
            ),
          );
        });
      },
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
  return selected ?? latest;
}

class ProductPhotoLightbox extends StatefulWidget {
  const ProductPhotoLightbox({
    super.key,
    required this.slides,
    required this.initialIndex,
    required this.productName,
    required this.onIndex,
  });

  final List<ProductLightboxSlide> slides;
  final int initialIndex;
  final String productName;
  final ValueChanged<int> onIndex;

  @override
  State<ProductPhotoLightbox> createState() => _ProductPhotoLightboxState();
}

class _ProductPhotoLightboxState extends State<ProductPhotoLightbox> {
  final _transform = TransformationController();
  late int _index = widget.initialIndex;
  double _scale = 1;
  Size _photoSize = Size.zero;
  Offset _doubleTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  void _onTransform() {
    final scale = _transform.value.getMaxScaleOnAxis();
    if ((scale - _scale).abs() > 0.01 && mounted) {
      setState(() => _scale = scale);
    }
  }

  void _zoom(double value, {Offset? focalPoint}) {
    final scale = value.clamp(1.0, 4.0).toDouble();
    final center = focalPoint ?? _photoSize.center(Offset.zero);
    _transform.value = Matrix4.identity()
      ..translate(center.dx * (1 - scale), center.dy * (1 - scale))
      ..scale(scale);
  }

  void _go(int index) {
    if (index < 0 || index >= widget.slides.length || index == _index) return;
    _zoom(1);
    setState(() => _index = index);
    widget.onIndex(index);
  }

  void _close() => Navigator.of(context).pop(_index);

  @override
  void dispose() {
    widget.onIndex(_index);
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiple = widget.slides.length > 1;
    final slide = widget.slides[_index];
    final caption =
        slide.caption.trim().isEmpty ? widget.productName : slide.caption;
    final ink = B2BThemeExtension.light.surfaceCard;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _go(_index - 1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _go(_index + 1),
      },
      child: Focus(
        autofocus: true,
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(builder: (context, constraints) {
                  _photoSize = constraints.biggest;
                  return Listener(
                    onPointerSignal: (event) {
                      if (event is! PointerScrollEvent) return;
                      final next =
                          _scale + (event.scrollDelta.dy > 0 ? -0.25 : 0.25);
                      _zoom(next, focalPoint: event.localPosition);
                    },
                    child: GestureDetector(
                      onDoubleTapDown: (details) =>
                          _doubleTapPosition = details.localPosition,
                      onDoubleTap: () => _zoom(
                        _scale > 1.01 ? 1 : 2.5,
                        focalPoint: _doubleTapPosition,
                      ),
                      child: ClipRect(
                        child: InteractiveViewer(
                          transformationController: _transform,
                          minScale: 1,
                          maxScale: 4,
                          panEnabled: _scale > 1.01,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: Image(
                              key: ValueKey(_index),
                              image: slide.image,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              semanticLabel:
                                  'Foto ${_index + 1} de ${widget.slides.length}: $caption',
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.broken_image_outlined,
                                color: ink,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              Positioned(
                top: 12,
                left: 52,
                right: 52,
                child: _badge(caption, multiple, ink),
              ),
              if (multiple) ...[
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 72,
                  child: Center(
                    child: _chromeButton(
                      tooltip: 'Foto anterior',
                      icon: Icons.chevron_left_rounded,
                      ink: ink,
                      onPressed: _index > 0 ? () => _go(_index - 1) : null,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 72,
                  child: Center(
                    child: _chromeButton(
                      tooltip: 'Foto siguiente',
                      icon: Icons.chevron_right_rounded,
                      ink: ink,
                      onPressed: _index < widget.slides.length - 1
                          ? () => _go(_index + 1)
                          : null,
                    ),
                  ),
                ),
              ],
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (multiple)
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.slides.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final selected = i == _index;
                            return Tooltip(
                              message: 'Ver foto ${i + 1}',
                              child: Material(
                                color: ink.withOpacity(0.16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: selected
                                        ? ink
                                        : ink.withOpacity(0.35),
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _go(i),
                                  child: SizedBox.square(
                                    dimension: 44,
                                    child: Image(
                                      image: ResizeImage(
                                        widget.slides[i].image,
                                        width: 120,
                                      ),
                                      fit: BoxFit.contain,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (multiple) const SizedBox(height: 8),
                    Center(child: _controls(ink)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String caption, bool multiple, Color ink) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: B2BThemeExtension.light.textPrimary.withOpacity(0.72),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: B2BThemeExtension.light.textPrimary.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (multiple)
              Text(
                '${_index + 1} / ${widget.slides.length}',
                maxLines: 1,
                style: TextStyle(color: ink, fontWeight: FontWeight.w800),
              ),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: ink, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(Color ink) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: B2BThemeExtension.light.textPrimary.withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: B2BThemeExtension.light.textPrimary.withOpacity(0.32),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 2,
          runSpacing: 2,
          children: [
              _chromeButton(
                tooltip: 'Alejar foto',
                icon: Icons.remove_rounded,
                ink: ink,
                onPressed: _scale > 1.01 ? () => _zoom(_scale - 0.5) : null,
              ),
              Tooltip(
                message: 'Restablecer zoom',
                child: TextButton(
                  onPressed: () => _zoom(1),
                  style: TextButton.styleFrom(
                    foregroundColor: ink,
                    minimumSize: const Size(56, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    '${(_scale * 100).round()}%',
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              _chromeButton(
                tooltip: 'Acercar foto',
                icon: Icons.add_rounded,
                ink: ink,
                onPressed: _scale < 3.99 ? () => _zoom(_scale + 0.5) : null,
              ),
              _chromeButton(
                tooltip: 'Ajustar a pantalla',
                icon: Icons.fit_screen_outlined,
                ink: ink,
                onPressed: () => _zoom(1),
              ),
              _chromeButton(
                tooltip: 'Cerrar fotos',
                icon: Icons.close_rounded,
                ink: ink,
                onPressed: _close,
              ),
            ],
        ),
      ),
    );
  }

  Widget _chromeButton({
    required String tooltip,
    required IconData icon,
    required Color ink,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        foregroundColor: ink,
        disabledForegroundColor: ink.withOpacity(0.35),
        hoverColor: ink.withOpacity(0.14),
        highlightColor: ink.withOpacity(0.22),
        fixedSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
