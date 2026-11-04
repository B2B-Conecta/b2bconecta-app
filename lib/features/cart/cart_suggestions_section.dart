import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/utils/ves_amount_format.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_seals.dart';

import 'cart_suggestions.dart';

/// Carrusel (móvil) o grilla (escritorio) de complementos y proveedores líderes.
class CartSuggestionsSection extends StatelessWidget {
  const CartSuggestionsSection({
    super.key,
    required this.suggestions,
    required this.loading,
    required this.confirmingIds,
    required this.onAdd,
    this.bcvRate,
  });

  final List<CartSuggestion> suggestions;
  final bool loading;
  final Set<String> confirmingIds;
  final ValueChanged<CartSuggestion>? onAdd;
  final double? bcvRate;

  static const cardWidth = 232.0;
  static const cardHeight = 318.0;

  @override
  Widget build(BuildContext context) {
    AppColors.brightness = Theme.of(context).brightness;
    if (!loading && suggestions.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: 'Productos sugeridos para el pedido',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Complementa tu pedido',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complementos del carrito y productos de proveedores con mejor cumplimiento.',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (loading && suggestions.isEmpty)
            const _SuggestionSkeletonRow()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 560;
                if (!wide) {
                  return SizedBox(
                    height: cardHeight,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        return SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: _SuggestionCard(
                            suggestion: suggestion,
                            confirming: confirmingIds
                                .contains(suggestion.part.id),
                            bcvRate: bcvRate,
                            onAdd: onAdd == null
                                ? null
                                : () => onAdd!(suggestion),
                          ),
                        );
                      },
                    ),
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: suggestions.length,
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: cardHeight,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return _SuggestionCard(
                      suggestion: suggestion,
                      confirming: confirmingIds.contains(suggestion.part.id),
                      bcvRate: bcvRate,
                      onAdd: onAdd == null ? null : () => onAdd!(suggestion),
                    );
                  },
                );
              },
            ),
        ],
      ),
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
    final supplier = (part.ownerBusinessName ?? '').trim();
    final supplierLabel = supplier.isEmpty ? 'Proveedor' : supplier;
    final unit = part.precioUnitarioParaAliado();
    final showBs = bcvRate != null &&
        bcvRate! > 0 &&
        !part.ownerPagoSoloDivisas;
    final cover = part.coverImageUrl?.trim();
    final badge = suggestion.kind == CartSuggestionKind.complement
        ? 'Complemento'
        : 'Proveedor líder';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Thumb(url: cover),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandLink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        part.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    supplierLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (part.isCatalogVerified) ...[
                  const SizedBox(width: 6),
                  const ImporterCatalogSealChip(
                    kind: ImporterCatalogSealKind.verified,
                    compact: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              part.ownerPagoSoloDivisas
                  ? '${formatRefAmount(unit)} USD'
                  : '${formatRefAmount(unit)} REF',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (showBs)
              Text(
                formatBsLabel(unit * bcvRate!),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            if (suggestion.logisticsNote != null) ...[
              const SizedBox(height: 8),
              _LogisticsNote(text: suggestion.logisticsNote!),
            ],
            const Spacer(),
            const SizedBox(height: 8),
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

class _LogisticsNote extends StatelessWidget {
  const _LogisticsNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF0D7A8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.local_shipping_outlined,
              size: 16,
              color: Color(0xFF8A5A12),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: Color(0xFF6B4510),
                ),
              ),
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
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
                  minimumSize: const Size(double.infinity, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
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
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE5F6EA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_rounded, size: 18, color: Color(0xFF1B7F3A)),
          SizedBox(width: 6),
          Text(
            'Añadido',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B7F3A),
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final resolved = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        height: 64,
        child: ColoredBox(
          color: AppColors.surfaceTinted,
          child: resolved == null || resolved.isEmpty
              ? Icon(Icons.image_outlined, color: AppColors.textSecondary)
              : Image.network(
                  resolved,
                  fit: BoxFit.cover,
                  cacheWidth: 192,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.image_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
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
        child: Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              const Expanded(child: _SuggestionSkeletonCard()),
            ],
          ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Container(height: 12, width: 120, color: tone),
            const SizedBox(height: 8),
            Container(height: 12, width: 80, color: tone),
            const Spacer(),
            Container(
              height: 40,
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
