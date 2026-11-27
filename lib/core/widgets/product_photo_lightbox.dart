import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';

const _mobileGalleryBackground = Color(0xFF0E172B);
const _thumbnailSpacing = 8.0;

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
  bool catalogGalleryLayout = false,
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
            color: mobile && catalogGalleryLayout
                ? _mobileGalleryBackground
                : B2BThemeExtension.light.textPrimary.withOpacity(0.92),
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
                    catalogGalleryLayout: catalogGalleryLayout,
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
    this.catalogGalleryLayout = false,
  });

  final List<ProductLightboxSlide> slides;
  final int initialIndex;
  final String productName;
  final ValueChanged<int> onIndex;
  final bool catalogGalleryLayout;

  @override
  State<ProductPhotoLightbox> createState() => _ProductPhotoLightboxState();
}

class _ProductPhotoLightboxState extends State<ProductPhotoLightbox> {
  final _transform = TransformationController();
  final _thumbnailScroll = ScrollController();
  late int _index = widget.initialIndex;
  double _scale = 1;
  Size _photoSize = Size.zero;
  Offset _doubleTapPosition = Offset.zero;
  final _photoPointers = <int>{};
  Offset? _swipeOrigin;
  double _thumbnailSize = 0;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    _showSelectedThumbnail();
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
    _showSelectedThumbnail();
  }

  void _showSelectedThumbnail() {
    if (!widget.catalogGalleryLayout) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_thumbnailScroll.hasClients) return;
      final position = _thumbnailScroll.position;
      final left = _index * (_thumbnailSize + _thumbnailSpacing);
      final right = left + _thumbnailSize;
      if (left >= position.pixels &&
          right <= position.pixels + position.viewportDimension) {
        return;
      }
      final offset =
          (left < position.pixels ? left : right - position.viewportDimension)
              .clamp(0.0, position.maxScrollExtent)
              .toDouble();
      _thumbnailScroll.jumpTo(offset);
    });
  }

  void _startSwipe(PointerDownEvent event) {
    _photoPointers.add(event.pointer);
    _swipeOrigin =
        _photoPointers.length == 1 && _scale <= 1.01 ? event.position : null;
  }

  void _cancelSwipe(PointerCancelEvent event) {
    _photoPointers.remove(event.pointer);
    _swipeOrigin = null;
  }

  void _finishSwipe(PointerUpEvent event) {
    _photoPointers.remove(event.pointer);
    final origin = _swipeOrigin;
    _swipeOrigin = null;
    if (origin == null || _scale > 1.01) return;
    final distance = event.position - origin;
    final horizontal = distance.dx.abs();
    if (horizontal >= 48 && horizontal > distance.dy.abs() * 1.5) {
      _go(_index + (distance.dx < 0 ? 1 : -1));
    }
  }

  void _close() => Navigator.of(context).pop(_index);

  @override
  void dispose() {
    widget.onIndex(_index);
    _thumbnailScroll.dispose();
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
    final mobile = widget.catalogGalleryLayout &&
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
    final photo = _photo(slide, caption,
        widget.catalogGalleryLayout ? B2BThemeExtension.light.textMuted : ink,
        swipe: mobile && multiple);
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
        child: widget.catalogGalleryLayout
            ? Material(
                type: MaterialType.transparency,
                child: mobile
                    ? _mobileViewer(photo, caption, multiple, ink)
                    : _desktopViewer(photo, caption, multiple, ink),
              )
            : SizedBox.expand(
                child: Stack(
                  children: [
                    Positioned.fill(child: photo),
                    Positioned(
                      top: 12,
                      left: 52,
                      right: 52,
                      child: _badge(caption, multiple, ink),
                    ),
                    if (multiple) ..._arrows(ink, bottom: 72),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (multiple) ...[
                            _thumbnails(ink, size: 44),
                            const SizedBox(height: 8),
                          ],
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

  Widget _photo(ProductLightboxSlide slide, String caption, Color ink,
      {required bool swipe}) {
    return LayoutBuilder(builder: (context, constraints) {
      _photoSize = constraints.biggest;
      return Listener(
        onPointerDown: swipe ? _startSwipe : null,
        onPointerUp: swipe ? _finishSwipe : null,
        onPointerCancel: swipe ? _cancelSwipe : null,
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          final next = _scale + (event.scrollDelta.dy > 0 ? -0.25 : 0.25);
          _zoom(next, focalPoint: event.localPosition);
        },
        child: GestureDetector(
          onDoubleTapDown: (details) =>
              _doubleTapPosition = details.localPosition,
          onDoubleTap: () => _zoom(
            _scale > 1.01 ? 1 : 2.5,
            focalPoint: _doubleTapPosition,
          ),
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
      );
    });
  }

  Widget _mobileViewer(Widget photo, String caption, bool multiple, Color ink) {
    return SafeArea(
      child: LayoutBuilder(builder: (context, viewport) {
        final compact = viewport.maxHeight < 470;
        final thumbSize = compact
            ? 48.0
            : ((viewport.maxWidth - 48) / 4).clamp(52.0, 76.0).toDouble();
        final zoomed = _scale > 1.01;
        return Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Cerrar fotos',
                  onPressed: _close,
                  icon: const Icon(Icons.close_rounded),
                  color: ink,
                ),
                Expanded(
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: ink, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: multiple
                        ? Text(
                            '${_index + 1} / ${widget.slides.length}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                color: ink, fontWeight: FontWeight.w700),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, stage) {
                final side = (stage.maxWidth - 24)
                    .clamp(0.0, stage.maxHeight)
                    .toDouble();
                return Center(
                  child: SizedBox(
                    width: side + 24,
                    height: side,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child:
                                ColoredBox(color: Colors.white, child: photo),
                          ),
                        ),
                        if (multiple)
                          ..._arrows(ink,
                              bottom: 0,
                              background:
                                  _mobileGalleryBackground.withOpacity(.90)),
                      ],
                    ),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      zoomed
                          ? '${(_scale * 100).round()}%'
                          : 'Pellizca para ampliar',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ink, fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    tooltip: zoomed ? 'Ajustar a pantalla' : 'Acercar foto',
                    onPressed: () => _zoom(zoomed ? 1 : 2),
                    icon: Icon(zoomed
                        ? Icons.fit_screen_outlined
                        : Icons.zoom_in_rounded),
                    color: ink,
                  ),
                ],
              ),
            ),
            if (multiple) ...[
              const SizedBox(height: 4),
              _thumbnails(ink, size: thumbSize, framed: true),
            ],
            SizedBox(height: compact ? 2 : 12),
          ],
        );
      }),
    );
  }

  Widget _desktopViewer(
      Widget photo, String caption, bool multiple, Color ink) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxHeight < 420;
          final gap = compact ? 6.0 : 14.0;
          final palette = B2BThemeExtension.light;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (multiple)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${_index + 1} / ${widget.slides.length}',
                        style:
                            TextStyle(color: ink, fontWeight: FontWeight.w700),
                      ),
                    ),
                  _chromeButton(
                    tooltip: 'Cerrar fotos',
                    icon: Icons.close_rounded,
                    ink: ink,
                    onPressed: _close,
                    size: 44,
                  ),
                ],
              ),
              SizedBox(height: gap),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: multiple ? 56 : 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ColoredBox(
                            color: palette.surfaceCard, child: photo),
                      ),
                    ),
                    if (multiple)
                      ..._arrows(ink,
                          bottom: 0, background: palette.textPrimary),
                  ],
                ),
              ),
              SizedBox(height: gap),
              if (multiple) ...[
                _thumbnails(ink, size: compact ? 48 : 68, framed: true),
                SizedBox(height: gap),
              ],
              Center(child: _controls(ink, showClose: false)),
            ],
          );
        }),
      ),
    );
  }

  List<Widget> _arrows(Color ink, {required double bottom, Color? background}) {
    Widget arrow(bool next) {
      final index = _index + (next ? 1 : -1);
      final button = _chromeButton(
        tooltip: next ? 'Foto siguiente' : 'Foto anterior',
        icon: next ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
        ink: ink,
        onPressed: index >= 0 && index < widget.slides.length
            ? () => _go(index)
            : null,
        size: background == null ? 40 : 44,
      );
      return Positioned(
        left: next ? null : (background == null ? 8 : 0),
        right: next ? (background == null ? 8 : 0) : null,
        top: 0,
        bottom: bottom,
        child: Center(
          child: background == null
              ? button
              : Material(
                  color: background,
                  shape: CircleBorder(
                      side: BorderSide(color: ink.withOpacity(.45))),
                  child: button,
                ),
        ),
      );
    }

    return [arrow(false), arrow(true)];
  }

  Widget _thumbnails(Color ink, {required double size, bool framed = false}) {
    return SizedBox(
      height: size + 4,
      width: double.infinity,
      child: LayoutBuilder(builder: (context, constraints) {
        if (framed) _thumbnailSize = size;
        final stripWidth = widget.slides.length * (size + _thumbnailSpacing) -
            _thumbnailSpacing;
        final sidePadding = framed
            ? ((constraints.maxWidth - stripWidth) / 2)
                .clamp(0.0, double.infinity)
                .toDouble()
            : 0.0;
        return ListView.separated(
          controller: framed ? _thumbnailScroll : null,
          padding: EdgeInsets.symmetric(horizontal: sidePadding),
          scrollDirection: Axis.horizontal,
          itemCount: widget.slides.length,
          separatorBuilder: (_, __) => const SizedBox(width: _thumbnailSpacing),
          itemBuilder: (context, i) {
            final selected = i == _index;
            return Tooltip(
              message: 'Ver foto ${i + 1}',
              child: Semantics(
                selected: selected,
                child: Material(
                  color: framed ? ink : ink.withOpacity(0.16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(framed ? 12 : 8),
                    side: BorderSide(
                      color: selected
                          ? (framed ? B2BThemeExtension.light.brand : ink)
                          : ink.withOpacity(0.35),
                      width: selected ? (framed ? 3 : 2) : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _go(i),
                    child: SizedBox(
                      width: size,
                      child: Padding(
                        padding: EdgeInsets.all(framed ? 4 : 0),
                        child: Image(
                          image: ResizeImage(widget.slides[i].image,
                              width: framed ? 160 : 120),
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
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

  Widget _controls(Color ink, {bool showClose = true}) {
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
            if (showClose)
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
    double size = 40,
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
        fixedSize: Size.square(size),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
