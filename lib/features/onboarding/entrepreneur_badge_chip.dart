import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

/// Insignia discreta «Emprendedor» (solo mayorista/admin con pedido vinculado).
class EntrepreneurBadgeChip extends StatelessWidget {
  const EntrepreneurBadgeChip({
    super.key,
    this.compact = true,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Tooltip(
      message: 'Minorista-Emprendedor',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9,
          vertical: compact ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: theme.brandContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.brand.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon(
              LucideGlyph.rocket,
              size: compact ? 11 : 13,
              color: theme.brand,
            ),
            SizedBox(width: compact ? 4 : 5),
            Text(
              'Emprendedor',
              style: TextStyle(
                fontSize: compact ? 10.5 : 11.5,
                fontWeight: FontWeight.w800,
                color: theme.brand,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
