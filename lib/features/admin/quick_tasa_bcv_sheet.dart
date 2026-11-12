import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/features/commissions/admin_tasa_bcv_card.dart';

/// Modal compacto para actualizar la tasa BCV (legacy / flujos auxiliares).
Future<void> showQuickTasaBcvSheet(
  BuildContext context, {
  bool canEdit = true,
}) {
  final sheetTheme = B2BThemeExtension.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: sheetTheme.dialogSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final theme = B2BThemeExtension.of(ctx);
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Actualizar tasa BCV',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sincroniza o fija la tasa oficial del día para toda la plataforma.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: theme.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            AdminTasaBcvCard(canEdit: canEdit),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
