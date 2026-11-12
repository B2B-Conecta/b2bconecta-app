import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/catalog/catalog_cart_price.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_logo.dart';

import 'cart_suggestions.dart';

/// Strip horizontal de fichas compactas «Completa tu compra» (mock bolsa).
class CartSuggestionsSection extends StatelessWidget {
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

  /// Conservado por compatibilidad con CartScreen / tests; el strip no auto-desplaza.
  final bool autoPlay;

  static const cardWidth = 156.0;
  static const cardGap = 10.0;
  static const cardHeight = 300.0;

  bool get _allSameSupplier =>
      suggestions.isNotEmpty &&
      suggestions.every((s) => !s.differentSupplier);

  @override
  Widget build(BuildContext context) {
    AppColors.brightness = Theme.of(context).brightness;
    if (!loading && suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Semantics(
      container: true,
      label: 'Productos sugeridos para el pedido',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SuggestionsSectionHeader(
            subtitle: _allSameSupplier
                ? 'Del mismo proveedor de tu compra.'
                : 'También te puede interesar.',
          ),
          const SizedBox(height: 10),
          if (loading && suggestions.isEmpty)
            const _SuggestionSkeletonRow()
          else
            SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: cardGap),
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return SizedBox(
                    width: cardWidth,
                    child: _CompactSuggestionCard(
                      suggestion: suggestion,
                      confirming: confirmingIds.contains(suggestion.part.id),
                      bcvRate: bcvRate,
                      onAdd: onAdd == null ? null : () => onAdd!(suggestion),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionsSectionHeader extends StatelessWidget {
  const _SuggestionsSectionHeader({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Completa tu compra',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0A317B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            fontStyle: FontStyle.italic,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CompactSuggestionCard extends StatelessWidget {
  const _CompactSuggestionCard({
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
    final radius = BorderRadius.circular(14);

    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ColoredBox(
                  color: AppColors.photoFrameFor(brightness),
                  child: cover != null && cover.isNotEmpty
                      ? Image.network(
                          cover,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          cacheWidth: 280,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) =>
                              const _PhotoPlaceholder(failed: true),
                          loadingBuilder: (_, image, progress) =>
                              progress == null
                                  ? image
                                  : const _PhotoPlaceholder(loading: true),
                        )
                      : const _PhotoPlaceholder(),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    part.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      ImporterCatalogLogo(
                        storagePath: part.ownerLogoStoragePath,
                        size: 12,
                        fallback: LucideIcon(
                          LucideGlyph.store,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          supplierLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            height: 1.15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: CatalogCartPrice(
                        part: part,
                        compact: true,
                        prominent: false,
                        catalogGrid: true,
                        bcvRate: bcvRate,
                      ),
                    ),
                  ),
                  Text(
                    'Mín. ${part.minOrderQtyEffective} uds',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _AddButton(
              confirming: confirming,
              enabled: onAdd != null && !confirming,
              onPressed: onAdd,
              productName: part.nombre,
            ),
          ],
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
    if (confirming) {
      return Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE5F6EA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LucideIcon(LucideGlyph.check, size: 15, color: Color(0xFF1B7F3A)),
            SizedBox(width: 4),
            Text(
              'Añadido',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B7F3A),
              ),
            ),
          ],
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Añadir al pedido $productName',
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF004BDD),
          disabledBackgroundColor: const Color(0xFF004BDD).withOpacity(0.35),
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        icon: const LucideIcon(
          LucideGlyph.shoppingCart,
          size: 15,
          color: AppColors.white,
        ),
        label: const Text('Agregar'),
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
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : LucideIcon(
                failed ? LucideGlyph.imageOff : LucideGlyph.image,
                size: 26,
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
    final tone = AppColors.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFE6EBF2);
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
          itemBuilder: (_, __) => SizedBox(
            width: CartSuggestionsSection.cardWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 1.1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tone,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(height: 12, color: tone),
                    const SizedBox(height: 8),
                    Container(height: 12, width: 72, color: tone),
                    const Spacer(),
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: tone,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
