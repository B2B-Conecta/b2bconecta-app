import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'part_model.dart';

/// The same stock meaning and contrast in a catalog card and a product detail.
class ProductStockSummary extends StatelessWidget {
  const ProductStockSummary(
      {super.key, required this.part, this.inline = false});
  final PartModel part;
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
    final stock = Text(label,
        style: TextStyle(
            fontSize: inline ? 12.5 : 12,
            height: inline ? 1.3 : 1.2,
            fontWeight: FontWeight.w600,
            color: color));
    final minimum = Text(
        inline
            ? 'Mín. ${part.minOrderQtyEffective} unidades'
            : part.minOrderQtyLabelEs,
        style: TextStyle(
            fontSize: inline ? 12.5 : 12,
            height: inline ? 1.3 : 1.2,
            color: short ? color : AppColors.textSecondary));
    if (!inline) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [stock, const SizedBox(height: 3), minimum]);
    }
    return Wrap(spacing: 16, runSpacing: 6, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(short ? Icons.info_outline_rounded : Icons.inventory_2_outlined,
            size: 15, color: color),
        const SizedBox(width: 5),
        stock,
      ]),
      minimum,
    ]);
  }
}
