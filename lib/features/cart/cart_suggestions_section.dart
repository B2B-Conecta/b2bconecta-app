import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_layout.dart';
import 'package:motolink_pro_app/features/catalog/catalog_cart_price.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_logo.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_seals.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica.dart';

import 'cart_suggestions.dart';

/// Carrusel de sugeridos con fichas grandes y desplazamiento automático.
class CartSuggestionsSection extends StatefulWidget {
  const CartSuggestionsSection({
    super.key,
    required this.suggestions,
    required this.loading,
    required this.confirmingIds,
    required this.onAdd,
    this.bcvRate,
    this.autoPlay = true,
  });

  final List<CartSuggestion> suggestions;
  final bool loading;
  final Set<String> confirmingIds;
  final ValueChanged<CartSuggestion>? onAdd;
  final double? bcvRate;
  final bool autoPlay;

  static const cardWidth = 228.0;
  static const cardGap = 14.0;

  static const cardHeight =
      8 + (cardWidth - 16) / AliadoCatalogLayout.cardImageAspect + 210;

  static const _loopCopies = 4;

  @override
  State<CartSuggestionsSection> createState() => _CartSuggestionsSectionState();
}

class _CartSuggestionsSectionState extends State<CartSuggestionsSection> {
  final _scroll = ScrollController();
  Timer? _autoTimer;
  bool _canBack = false;
  bool _canForward = false;
  DateTime? _resumeAt;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncArrows();
      _startAutoScroll();
    });
  }

  @override
  void didUpdateWidget(CartSuggestionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestions.length != widget.suggestions.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncArrows();
        _startAutoScroll();
      });
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _scroll.removeListener(_syncArrows);
    _scroll.dispose();
    super.dispose();
  }

  double get _cycleWidth {
    final n = widget.suggestions.length;
    if (n == 0) return 0;
    return n *
        (CartSuggestionsSection.cardWidth + CartSuggestionsSection.cardGap);
  }

  int get _itemCount {
    final n = widget.suggestions.length;
    if (n == 0) return 0;
    if (n == 1) return 1;
    return n * CartSuggestionsSection._loopCopies;
  }

  void _startAutoScroll() {
    _autoTimer?.cancel();
    if (!widget.autoPlay || widget.suggestions.length < 2) return;
    _autoTimer = Timer.periodic(const Duration(milliseconds: 28), (_) {
      if (!mounted || !_scroll.hasClients) return;
      final resumeAt = _resumeAt;
      if (resumeAt != null && DateTime.now().isBefore(resumeAt)) return;
      final max = _scroll.position.maxScrollExtent;
      if (max <= 0) return;
      final cycle = _cycleWidth;
      var next = _scroll.offset + 0.7;
      if (cycle > 0 && next >= cycle * (CartSuggestionsSection._loopCopies - 1)) {
        next -= cycle;
        _scroll.jumpTo(next.clamp(0.0, max));
        return;
      }
      if (next >= max) {
        _scroll.jumpTo(0);
        return;
      }
      _scroll.jumpTo(next);
    });
  }

  void _pauseAuto({Duration resumeAfter = const Duration(seconds: 5)}) {
    _resumeAt = DateTime.now().add(resumeAfter);
  }

  void _syncArrows() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final back = position.pixels > 4;
    final forward = position.pixels < position.maxScrollExtent - 4;
    if (back == _canBack && forward == _canForward) return;
    setState(() {
      _canBack = back;
      _canForward = forward;
    });
  }

  Future<void> _page(int direction) async {
    _pauseAuto();
    if (!_scroll.hasClients) return;
    const step =
        CartSuggestionsSection.cardWidth + CartSuggestionsSection.cardGap;
    final target = (_scroll.offset + direction * step)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    await _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  double _scaleForIndex(int index, double viewportWidth) {
    if (!_scroll.hasClients || viewportWidth <= 0) return 1;
    final itemCenter = index *
            (CartSuggestionsSection.cardWidth +
                CartSuggestionsSection.cardGap) +
        CartSuggestionsSection.cardWidth / 2;
    final viewCenter = _scroll.offset + viewportWidth / 2;
    final distance = (itemCenter - viewCenter).abs();
    return (1 - (distance / viewportWidth) * 0.14).clamp(0.93, 1.0);
  }

  Widget _suggestionCard(CartSuggestion suggestion) {
    return _SuggestionCard(
      suggestion: suggestion,
      confirming: widget.confirmingIds.contains(suggestion.part.id),
      bcvRate: widget.bcvRate,
      onAdd: widget.onAdd == null
          ? null
          : () {
              _pauseAuto();
              widget.onAdd!(suggestion);
            },
    );
  }

  Widget _buildCarousel(double viewportWidth) {
    return SizedBox(
      height: CartSuggestionsSection.cardHeight,
      child: AnimatedBuilder(
        animation: _scroll,
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification &&
                      notification.dragDetails != null) {
                    _pauseAuto();
                  }
                  return false;
                },
                child: Listener(
                  onPointerDown: (_) => _pauseAuto(),
                  child: ListView.separated(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: _itemCount,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: CartSuggestionsSection.cardGap),
                    itemBuilder: (context, index) {
                      final suggestion = widget.suggestions[
                          index % widget.suggestions.length];
                      final scale = _scaleForIndex(index, viewportWidth);
                      return Transform.scale(
                        scale: scale,
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: scale.clamp(0.88, 1.0),
                          child: SizedBox(
                            width: CartSuggestionsSection.cardWidth,
                            height: CartSuggestionsSection.cardHeight,
                            child: _suggestionCard(suggestion),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_canBack)
                Align(
                  alignment: Alignment.centerLeft,
                  child: _CarouselArrow(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Anterior',
                    onTap: () => _page(-1),
                  ),
                ),
              if (_canForward)
                Align(
                  alignment: Alignment.centerRight,
                  child: _CarouselArrow(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'Siguiente',
                    onTap: () => _page(1),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.brightness = Theme.of(context).brightness;
    if (!widget.loading && widget.suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Semantics(
      container: true,
      label: 'Productos sugeridos para el pedido',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SuggestionsSectionHeader(),
          const SizedBox(height: 10),
          if (widget.loading && widget.suggestions.isEmpty)
            const _SuggestionSkeletonRow()
          else
            LayoutBuilder(builder: (context, constraints) {
              return _buildCarousel(constraints.maxWidth);
            }),
        ],
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shadowColor: Colors.black26,
      color: AppColors.card,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: Icon(icon, color: AppColors.brandLink),
      ),
    );
  }
}

class _SuggestionsSectionHeader extends StatelessWidget {
  const _SuggestionsSectionHeader();

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.brandLink;
    final soft = Color.lerp(AppColors.card, accent, 0.08)!;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.divider.withOpacity(0),
                  AppColors.divider,
                  AppColors.divider.withOpacity(0.35),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withOpacity(0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 14, color: accent),
                const SizedBox(width: 6),
                Text(
                  'Sugeridos',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.divider.withOpacity(0.35),
                  AppColors.divider,
                  AppColors.divider.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.confirming,
    required this.bcvRate,
    required this.onAdd,
  });

  final CartSuggestion suggestion;
  final bool confirming;
  final double? bcvRate;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final part = suggestion.part;
    final brightness = Theme.of(context).brightness;
    final supplier = (part.ownerBusinessName ?? '').trim();
    final supplierLabel = supplier.isEmpty ? 'Proveedor' : supplier;
    final cover = part.coverImageUrl?.trim();
    final shippingIncluded =
        EnvioPolitica.normalize(part.ownerEnvioTipo) == EnvioPolitica.incluido;
    final note = suggestion.logisticsNote;
    final radius = BorderRadius.circular(AliadoCatalogLayout.cardRadius);

    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: AspectRatio(
              aspectRatio: AliadoCatalogLayout.cardImageAspect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(
                  color: AppColors.photoFrameFor(brightness),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ProductPhoto(url: cover),
                      if (part.isCatalogVerified || part.isCatalogFeatured)
                        Positioned(
                          top: 8,
                          left: 8,
                          right: 8,
                          child: ImporterCatalogSealsRow(
                            verified: part.isCatalogVerified,
                            featured: part.isCatalogFeatured,
                            compact: true,
                            spacing: 4,
                          ),
                        ),
                      if (shippingIncluded)
                        const Positioned(
                          left: 6,
                          bottom: 6,
                          child: _ShippingChip(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    part.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  CatalogCartPrice(
                    part: part,
                    compact: true,
                    prominent: true,
                    catalogGrid: true,
                    bcvRate: bcvRate,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ImporterCatalogLogo(
                        storagePath: part.ownerLogoStoragePath,
                        size: 14,
                        fallback: LucideIcon(
                          LucideGlyph.store,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          supplierLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (part.ownerRatingAvg != null &&
                          (part.ownerRatingCount ?? 0) > 0) ...[
                        Icon(Icons.star_rounded,
                            size: 13, color: Colors.amber.shade800),
                        const SizedBox(width: 2),
                        Text(
                          part.ownerRatingAvg!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 4),
                    _LogisticsDetailToggle(
                      summary: suggestion.differentSupplier
                          ? 'Pedido aparte'
                          : 'Mismo prov.',
                      detail: note,
                      sameSupplier: !suggestion.differentSupplier,
                    ),
                  ],
                  const Spacer(flex: 1),
                  _AddButton(
                    confirming: confirming,
                    enabled: onAdd != null && !confirming,
                    onPressed: onAdd,
                    productName: part.nombre,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShippingChip extends StatelessWidget {
  const _ShippingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        'Envío incluido',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Chip de una línea; el texto largo se abre fuera de la tarjeta.
class _LogisticsDetailToggle extends StatelessWidget {
  const _LogisticsDetailToggle({
    required this.summary,
    required this.detail,
    required this.sameSupplier,
  });

  final String summary;
  final String detail;
  final bool sameSupplier;

  Future<void> _showDetail(BuildContext context) {
    final bg = sameSupplier ? const Color(0xFFE8F5EE) : const Color(0xFFFFF6E8);
    final border =
        sameSupplier ? const Color(0xFFB7DFC6) : const Color(0xFFF0D7A8);
    final fg =
        sameSupplier ? const Color(0xFF1B6B3A) : const Color(0xFF6B4510);
    final icon =
        sameSupplier ? Icons.check_circle_outline : Icons.local_shipping_outlined;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  summary,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 18, color: fg),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            detail,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = sameSupplier ? const Color(0xFFE8F5EE) : const Color(0xFFFFF6E8);
    final border =
        sameSupplier ? const Color(0xFFB7DFC6) : const Color(0xFFF0D7A8);
    final fg =
        sameSupplier ? const Color(0xFF1B6B3A) : const Color(0xFF6B4510);
    final icon =
        sameSupplier ? Icons.check_circle_outline : Icons.local_shipping_outlined;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                'Detalle',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              Icon(Icons.chevron_right, size: 15, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.confirming,
    required this.enabled,
    required this.onPressed,
    required this.productName,
  });

  final bool confirming;
  final bool enabled;
  final VoidCallback? onPressed;
  final String productName;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: confirming
          ? const _AddedPill(key: ValueKey('added'))
          : Semantics(
              button: true,
              label: 'Añadir al pedido $productName',
              child: FilledButton.icon(
                key: const ValueKey('add'),
                onPressed: enabled ? onPressed : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 16),
                label: const Text('Añadir al pedido'),
              ),
            ),
    );
  }
}

class _AddedPill extends StatelessWidget {
  const _AddedPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE5F6EA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_rounded, size: 16, color: Color(0xFF1B7F3A)),
          SizedBox(width: 5),
          Text(
            'Añadido',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B7F3A),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final resolved = url;
    if (resolved == null || resolved.isEmpty) {
      return const _PhotoPlaceholder();
    }
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Image.network(
        resolved,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        cacheWidth: 360,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const _PhotoPlaceholder(failed: true),
        loadingBuilder: (_, image, progress) => progress == null
            ? image
            : const _PhotoPlaceholder(loading: true),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.loading = false, this.failed = false});

  final bool loading;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return ColoredBox(
      color: AppColors.surfaceTintedFor(b),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                failed ? Icons.broken_image_outlined : Icons.image_outlined,
                size: 30,
                color: AppColors.textSecondary,
              ),
      ),
    );
  }
}

class _SuggestionSkeletonRow extends StatelessWidget {
  const _SuggestionSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando sugerencias',
      child: SizedBox(
        height: CartSuggestionsSection.cardHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) =>
              const SizedBox(width: CartSuggestionsSection.cardGap),
          itemBuilder: (_, __) => const SizedBox(
            width: CartSuggestionsSection.cardWidth,
            child: _SuggestionSkeletonCard(),
          ),
        ),
      ),
    );
  }
}

class _SuggestionSkeletonCard extends StatelessWidget {
  const _SuggestionSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final tone = AppColors.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFE6EBF2);
    final radius = BorderRadius.circular(AliadoCatalogLayout.cardRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: radius,
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: AliadoCatalogLayout.cardImageAspect,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(height: 14, width: 140, color: tone),
            const SizedBox(height: 8),
            Container(height: 14, width: 80, color: tone),
            const Spacer(),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
