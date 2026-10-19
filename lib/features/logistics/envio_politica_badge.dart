import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'envio_politica.dart';

/// Chip de flete. Vacío cuando la política no está definida.
class EnvioPoliticaBadge extends StatelessWidget {
  const EnvioPoliticaBadge({
    super.key,
    required this.tipo,
    this.compact = false,
  });

  final String? tipo;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!EnvioPolitica.muestraBadge(tipo)) return const SizedBox.shrink();
    final code = EnvioPolitica.normalize(tipo);
    final colors = _colors(code);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.$3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(code), size: compact ? 12 : 15, color: colors.$2),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              compact
                  ? EnvioPolitica.badgeCorto(code)
                  : EnvioPolitica.badgeLargo(code),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w800,
                color: colors.$2,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _icon(String code) {
    switch (code) {
      case EnvioPolitica.incluido:
        return Icons.local_shipping_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  static (Color, Color, Color) _colors(String code) {
    switch (code) {
      case EnvioPolitica.incluido:
        return (
          AppColors.successGreen.withOpacity(0.14),
          AppColors.successGreen,
          AppColors.successGreen.withOpacity(0.35),
        );
      default:
        return (
          AppColors.brandBlueContainer,
          AppColors.brandBlue,
          AppColors.brand.withOpacity(0.28),
        );
    }
  }
}

/// Nota de flete en la confirmación, una por proveedor con política definida.
class EnvioPoliticaNotas extends StatelessWidget {
  const EnvioPoliticaNotas({super.key, required this.notas});

  final List<String> notas;

  @override
  Widget build(BuildContext context) {
    if (notas.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final nota in notas) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.brandBlueContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 16,
                  color: AppColors.brandBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nota,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
