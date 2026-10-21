import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/admin_list_skeleton.dart';
import 'aliado_catalog_layout.dart';

/// Rejilla de fichas en carga. Misma columna que el catálogo aliado.
class CatalogGridSkeleton extends StatelessWidget {
  const CatalogGridSkeleton({
    super.key,
    required this.maxWidth,
    required this.horizontalPadding,
  });

  final double maxWidth;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final cols = AliadoCatalogLayout.crossAxisCount(maxWidth);
    final spacing = AliadoCatalogLayout.gridSpacing(maxWidth);
    final inner = (maxWidth - horizontalPadding * 2).clamp(1.0, maxWidth);
    final tile = cols <= 1
        ? inner
        : (inner - spacing * (cols - 1)) / cols;
    return Semantics(
      label: 'Cargando repuestos',
      child: GridView.builder(
        primary: false,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          8,
          horizontalPadding,
          16,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: AliadoCatalogLayout.childAspectRatio(
            tileWidth: tile,
          ),
        ),
        itemCount: cols * 2,
        itemBuilder: (_, __) => const _CatalogSkeletonCard(),
      ),
    );
  }
}

class _CatalogSkeletonCard extends StatelessWidget {
  const _CatalogSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final border = AppColors.brightness == Brightness.dark
        ? AppColors.borderSubtle
        : const Color(0xFFE2E8F0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AliadoCatalogLayout.cardRadius),
        border: Border.all(color: border),
        boxShadow: AppDecorations.cardShadow,
      ),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(
          AliadoCatalogLayout.cardPadH,
          AliadoCatalogLayout.cardPadTop,
          AliadoCatalogLayout.cardPadH,
          AliadoCatalogLayout.cardPadBottom,
        ),
        child: Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SkeletonBox(radius: 10),
              ),
              SizedBox(height: 8),
              SkeletonBox(height: 12),
              SizedBox(height: 6),
              SkeletonBox(width: 72, height: 10),
              SizedBox(height: 8),
              SkeletonBox(width: 88, height: 14),
              SizedBox(height: 4),
              SkeletonBox(width: 64, height: 10),
              SizedBox(height: 6),
              SkeletonBox(width: 96, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
