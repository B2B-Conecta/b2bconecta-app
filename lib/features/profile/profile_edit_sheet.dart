import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/profile/profile_b2b_form.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Edición de datos del negocio: diálogo en desktop, sheet en móvil.
Future<void> showProfileEditSheet({
  required BuildContext context,
  required ProfileModel profile,
  required VoidCallback onSaved,
  VoidCallback? onRelatedDataChanged,
}) {
  final theme = B2BThemeExtension.of(context);
  final mobile =
      MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;

  Widget body({ScrollController? scroll}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Editar mi negocio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Actualiza RIF, contacto y ubicación fiscal.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: LucideIcon(
                  LucideGlyph.close,
                  size: 20,
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.borderSubtle),
        Expanded(
          child: SingleChildScrollView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ProfileB2BForm(
                  editingOnly: true,
                  initial: profile,
                  onSaved: () {
                    onSaved();
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                  onRelatedDataChanged: onRelatedDataChanged,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  if (mobile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.dialogSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.92,
          child: body(),
        ),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    barrierColor: theme.textPrimary.withOpacity(0.35),
    builder: (ctx) => Dialog(
      backgroundColor: theme.dialogSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
        ),
        child: body(),
      ),
    ),
  );
}
