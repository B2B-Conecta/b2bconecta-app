import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'part_model.dart';

/// The same stock meaning and contrast in a catalog card and a product detail.
class ProductStockSummary extends StatelessWidget {
  const ProductStockSummary(
      {super.key, required this.part, this.inline = false});
  final PartModel part;

  /// Detalle: Wrap suelto. Ficha catálogo: fila con divisor vertical (mock).
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enough =
        part.isActive && part.stockForSale >= part.minOrderQtyEffective;
    final short = part.isActive && part.stockForSale > 0 && !enough;
    final color = enough
        ? dark
            ? Color.lerp(AppColors.successGreen, AppColors.white, .55)!
            : AppColors.successGreen
        : short
            ? dark
                ? AppColors.warningAmberOnDark
                : AppColors.warningAmber
            : AppColors.textSecondary;
    final label = !part.isActive
        ? 'Producto pausado'
        : part.stockForSale == 0
            ? 'Sin stock'
            : short
                ? '${part.stockForSale} disponibles'
                : '${part.stockForSale} en stock';
    final showMin = part.hasSupplierMinOrderQty;
    final stock = Text(label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: inline ? 14.5 : 12,
            height: inline ? 1.3 : 1.2,
            fontWeight: FontWeight.w700,
            color: color));
    final minimum = Text(
        inline
            ? 'Mín. ${part.minOrderQtyEffective} unidades'
            : part.minOrderQtyLabelEs,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: inline ? 14.5 : 12,
            height: inline ? 1.3 : 1.2,
            fontWeight: FontWeight.w600,
            color: short ? color : const Color(0xFF0A1F44)));
    final stockGlyph = short
        ? LucideGlyph.package
        : enough
            ? LucideGlyph.circleCheck
            : LucideGlyph.package;
    if (inline) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LucideIcon(stockGlyph, size: 18, color: color),
              const SizedBox(width: 5),
              stock,
              if (showMin) ...[
                Container(
                  width: 1,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: AppColors.divider,
                ),
                minimum,
              ],
            ],
          ),
        ),
      );
    }
    // Ficha: ambos textos completos; si no caben, se escala el bloque.
    final cardStock = Text(label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
            fontSize: 11.5,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: color));
    final cardMin = Text(part.minOrderQtyLabelEs,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
            fontSize: 11.5,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: short ? color : const Color(0xFF0A1F44)));
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon(stockGlyph, size: 14, color: color),
            const SizedBox(width: 4),
            cardStock,
            if (showMin) ...[
              Container(
                width: 1,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: AppColors.divider,
              ),
              cardMin,
            ],
          ],
        ),
      ),
    );
  }
}
