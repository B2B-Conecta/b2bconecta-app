import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';

/// Sellos de proveedor en vitrina / catálogo (admin).
enum ImporterCatalogSealKind { verified, featured }

class ImporterCatalogSealChip extends StatelessWidget {
  const ImporterCatalogSealChip({
    super.key,
    required this.kind,
    this.compact = false,
  });

  final ImporterCatalogSealKind kind;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final isVerified = kind == ImporterCatalogSealKind.verified;
    final bg = isVerified ? theme.brand : theme.surfaceSubtle;
    final fg = isVerified ? theme.surfaceCard : theme.textPrimary;
    final icon = isVerified ? Icons.verified : Icons.star_rounded;
    final label = isVerified ? 'Verificado' : 'Destacado';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: isVerified ? null : Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 13, color: fg),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila de sellos (Verificado en marca, Destacado en superficie sutil).
class ImporterCatalogSealsRow extends StatelessWidget {
  const ImporterCatalogSealsRow({
    super.key,
    this.verified = false,
    this.featured = false,
    this.compact = false,
    this.spacing = 6,
  });

  final bool verified;
  final bool featured;
  final bool compact;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (!verified && !featured) return const SizedBox.shrink();
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        if (verified)
          ImporterCatalogSealChip(
            kind: ImporterCatalogSealKind.verified,
            compact: compact,
          ),
        if (featured)
          ImporterCatalogSealChip(
            kind: ImporterCatalogSealKind.featured,
            compact: compact,
          ),
      ],
    );
  }
}
