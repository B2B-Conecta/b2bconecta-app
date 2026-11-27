import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/product_photo_lightbox.dart';
import 'package:motolink_pro_app/features/inventory/product_images.dart';

/// Product photos remain uncropped; inspection happens in a separate viewer.
class ProductPhotoGallery extends StatefulWidget {
  const ProductPhotoGallery({
    super.key,
    required this.urls,
    required this.productName,
    this.heroTag,
    this.imageProvider,
  });

  final List<String> urls;
  final String productName;
  final String? heroTag;
  final ImageProvider<Object> Function(String)? imageProvider;

  @override
  State<ProductPhotoGallery> createState() => ProductPhotoGalleryState();
}

class ProductPhotoGalleryState extends State<ProductPhotoGallery> {
  final _pages = PageController();
  late List<String> _urls;
  int _index = 0;

  /// Opens the fullscreen viewer on the current photo (AppBar amplify).
  Future<void> openFullscreen() => _open(_index);

  @override
  void initState() {
    super.initState();
    _urls = normalizeProductImageUrls(widget.urls);
  }

  @override
  void didUpdateWidget(covariant ProductPhotoGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    final urls = normalizeProductImageUrls(widget.urls);
    if (!listEquals(urls, _urls)) {
      _urls = urls;
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  ImageProvider<Object> _provider(String url) =>
      widget.imageProvider?.call(url) ?? NetworkImage(url);

  void _go(int index) {
    if (index < 0 || index >= _urls.length) return;
    _pages.jumpToPage(index);
    setState(() => _index = index);
  }

  Future<void> _open(int index) async {
    final selected = await showProductPhotoLightbox(
      context,
      images: _urls.map(_provider).toList(),
      productName: widget.productName,
      initialIndex: index,
      catalogGalleryLayout: true,
    );
    if (mounted) _go(selected);
  }

  Widget _hero(Widget child) => widget.heroTag == null
      ? child
      : Hero(
          tag: widget.heroTag!,
          child: Material(type: MaterialType.transparency, child: child));

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty) {
      return _hero(const _PhotoStatus(message: 'Foto no disponible'));
    }
    final multiple = _urls.length > 1;
    return ColoredBox(
      color: AppColors.white,
      child: Column(children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            PageView.builder(
              controller: _pages,
              itemCount: _urls.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (_, index) {
                final photo = _ProductPhoto(
                  image: _provider(_urls[index]),
                  label:
                      'Foto ${index + 1} de ${_urls.length}: ${widget.productName}',
                  padding: const EdgeInsets.all(16),
                  onOpen: () => _open(index),
                );
                return index == 0 ? _hero(photo) : photo;
              },
            ),
            if (multiple)
              Positioned(
                bottom: 12,
                left: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('${_index + 1} / ${_urls.length}',
                        style: TextStyle(color: AppColors.textPrimary)),
                  ),
                ),
              ),
          ]),
        ),
        if (multiple)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                tooltip: 'Foto anterior',
                onPressed: _index > 0 ? () => _go(_index - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              for (var i = 0; i < _urls.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Semantics(
                    button: true,
                    selected: i == _index,
                    label: 'Ver foto ${i + 1} de ${_urls.length}',
                    child: Tooltip(
                      message: 'Ver foto ${i + 1}',
                      excludeFromSemantics: true,
                      child: Material(
                        color: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: i == _index
                                  ? AppColors.brand
                                  : AppColors.borderSubtle,
                              width: i == _index ? 2 : 1),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _go(i),
                          child: SizedBox.square(
                            dimension: 52,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Image(
                                image: _provider(_urls[i]),
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                                errorBuilder: (_, __, ___) => ColoredBox(
                                  color: AppColors.surfaceTinted,
                                  child: Icon(Icons.broken_image_outlined,
                                      color: AppColors.textMuted),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Foto siguiente',
                onPressed:
                    _index < _urls.length - 1 ? () => _go(_index + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _ProductPhoto extends StatefulWidget {
  const _ProductPhoto({
    super.key,
    required this.image,
    required this.label,
    this.padding = const EdgeInsets.all(16),
    this.onOpen,
  });
  final ImageProvider<Object> image;
  final String label;
  final EdgeInsets padding;
  final VoidCallback? onOpen;

  @override
  State<_ProductPhoto> createState() => _ProductPhotoState();
}

class _ProductPhotoState extends State<_ProductPhoto> {
  int _attempt = 0;

  Future<void> _retry() async {
    await widget.image.evict();
    if (mounted) setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.white,
        child: Image(
          key: ValueKey(_attempt),
          image: widget.image,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          semanticLabel: widget.label,
          frameBuilder: (_, image, frame, synchronous) {
            if (frame == null && !synchronous) {
              return const _PhotoStatus(message: 'Cargando foto…');
            }
            return Stack(fit: StackFit.expand, children: [
              Padding(
                padding: widget.padding,
                child: widget.onOpen == null
                    ? image
                    : InkWell(onTap: widget.onOpen, child: image),
              ),
              if (widget.onOpen != null)
                Positioned(
                  right: 12,
                  bottom: 8,
                  child: IconButton.filledTonal(
                    tooltip: 'Ampliar foto',
                    onPressed: widget.onOpen,
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    icon: const Icon(Icons.open_in_full_rounded, size: 20),
                  ),
                ),
            ]);
          },
          errorBuilder: (_, __, ___) => _PhotoStatus(
            message: 'No se pudo cargar la foto',
            onRetry: _retry,
          ),
        ),
      );
}

class _PhotoStatus extends StatelessWidget {
  const _PhotoStatus({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return ColoredBox(
      color: AppColors.surfaceTintedFor(b),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.image_outlined,
                size: 40, color: AppColors.textMutedFor(b)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondaryFor(b))),
            if (onRetry != null)
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
          ]),
        ),
      ),
    );
  }
}
