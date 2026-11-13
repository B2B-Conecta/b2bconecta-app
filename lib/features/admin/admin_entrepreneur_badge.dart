import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

/// Píldora «Emprendedor» para la tabla de cuentas admin (ámbar discreto).
class AdminEntrepreneurBadge extends StatelessWidget {
  const AdminEntrepreneurBadge({
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
          vertical: compact ? 3 : 4,
        ),
        decoration: BoxDecoration(
          color: theme.warningBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.warningFg.withOpacity(0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon(
              LucideGlyph.sparkles,
              size: compact ? 11 : 13,
              color: theme.warningFg,
            ),
            SizedBox(width: compact ? 4 : 5),
            Text(
              'Emprendedor',
              style: TextStyle(
                fontSize: compact ? 10.5 : 11.5,
                fontWeight: FontWeight.w800,
                color: theme.warningFg,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
