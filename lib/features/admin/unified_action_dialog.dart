import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/admin/admin_users_chrome.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

enum UnifiedActionTone { info, warning, danger }

/// Shell visual compartido por las acciones de Cuentas (confirmación / edición).
class UnifiedActionDialog extends StatelessWidget {
  const UnifiedActionDialog({
    super.key,
    required this.title,
    required this.glyph,
    required this.tone,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.profile,
    this.subtitle,
    this.maxWidth = 440,
    this.busy = false,
    this.primaryEnabled = true,
    this.cancelLabel = 'Cancelar',
    this.onCancel,
  });

  final String title;
  final String? subtitle;
  final LucideGlyph glyph;
  final UnifiedActionTone tone;
  final ProfileModel? profile;
  final Widget body;
  final String primaryLabel;
  final String cancelLabel;
  final VoidCallback? onPrimary;

  /// Si se define, sustituye el cierre por defecto del botón secundario
  /// (p. ej. «Restaurar» sin cerrar el diálogo).
  final VoidCallback? onCancel;
  final double maxWidth;
  final bool busy;
  final bool primaryEnabled;

  static const _amber = Color(0xFFD97706);
  static const _red = Color(0xFFDC2626);

  Color _accent(B2BThemeExtension theme) => switch (tone) {
        UnifiedActionTone.info => theme.brand,
        UnifiedActionTone.warning => _amber,
        UnifiedActionTone.danger => _red,
      };

  Color _pastel(B2BThemeExtension theme, bool dark) => switch (tone) {
        UnifiedActionTone.info =>
          dark ? theme.brandContainer : const Color(0xFFEFF6FF),
        UnifiedActionTone.warning =>
          dark ? const Color(0x26F59E0B) : const Color(0xFFFFFBEB),
        UnifiedActionTone.danger =>
          dark ? const Color(0x26DC2626) : const Color(0xFFFEF2F2),
      };

  Color _ring(B2BThemeExtension theme, bool dark) => switch (tone) {
        UnifiedActionTone.info =>
          dark ? theme.brand.withOpacity(0.35) : const Color(0xFFBFDBFE),
        UnifiedActionTone.warning =>
          dark ? const Color(0x66FBBF24) : const Color(0xFFFDE68A),
        UnifiedActionTone.danger =>
          dark ? const Color(0x66F87171) : const Color(0xFFFECACA),
      };

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    final theme = B2BThemeExtension.of(context);
    final mobile =
        MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
    final barrier = theme.textPrimary.withOpacity(0.45);
    if (mobile) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        barrierColor: barrier,
        backgroundColor: theme.dialogSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AdminUsersChrome.sheetRadius),
          ),
        ),
        builder: (ctx) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
              ),
              child: builder(ctx),
            ),
          );
        },
      );
    }
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierColor: barrier,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accent(theme);
    final pastel = _pastel(theme, dark);
    final ring = _ring(theme, dark);
    final mq = MediaQuery.of(context);
    final mobile = mq.size.width < AppBreakpoints.mobileMenu;
    final isSheet = ModalRoute.of(context) is ModalBottomSheetRoute;
    final maxH = mq.size.height * 0.9;

    final panel = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxH,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          isSheet ? 12 : 18,
          16,
          isSheet ? 12 : 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isSheet) ...[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: theme.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: pastel,
                    shape: BoxShape.circle,
                    border: Border.all(color: ring),
                  ),
                  alignment: Alignment.center,
                  child: LucideIcon(glyph, size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: theme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      busy ? null : () => Navigator.of(context).maybePop(),
                  icon: LucideIcon(
                    LucideGlyph.close,
                    size: 16,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
            if (profile != null) ...[
              const SizedBox(height: 14),
              UnifiedUserContextCard(profile: profile!),
            ],
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(child: body),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : (onCancel ??
                            () => Navigator.of(context).maybePop()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.textPrimary,
                      side: BorderSide(color: theme.borderStrong),
                      minimumSize: const Size.fromHeight(40),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      cancelLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: busy || !primaryEnabled || onPrimary == null
                        ? null
                        : onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      disabledBackgroundColor: accent.withOpacity(0.55),
                      foregroundColor: theme.surfaceCard,
                      minimumSize: const Size.fromHeight(40),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: theme.surfaceCard,
                            ),
                          )
                        : Text(
                            primaryLabel,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!busy) Navigator.of(context).maybePop();
        },
      },
      child: Focus(
        autofocus: true,
        child: isSheet
            ? Material(
                color: theme.dialogSurface,
                child: panel,
              )
            : Dialog(
                backgroundColor: theme.dialogSurface,
                elevation: 10,
                insetPadding: EdgeInsets.fromLTRB(
                  mobile ? 12 : 40,
                  24,
                  mobile ? 12 : 40,
                  24 + mq.viewInsets.bottom,
                ),
                shadowColor: theme.textPrimary.withOpacity(0.28),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AdminUsersChrome.sheetRadius),
                  side: BorderSide(color: theme.borderStrong),
                ),
                child: panel,
              ),
      ),
    );
  }
}

class UnifiedUserContextCard extends StatelessWidget {
  const UnifiedUserContextCard({super.key, required this.profile});

  final ProfileModel profile;

  String get _name {
    final name = profile.businessName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = profile.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'Cuenta sin nombre';
  }

  String get _email {
    final email = profile.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return profile.id;
  }

  String get _initials {
    final parts =
        _name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length >= 2 ? 2 : 1).toUpperCase();
    }
    return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.brandContainer,
              child: Text(
                _initials,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: theme.brand,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chips rápidos para motivos de suspensión / desactivación.
class UnifiedReasonChips extends StatelessWidget {
  const UnifiedReasonChips({
    super.key,
    required this.options,
    required this.onSelected,
  });

  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final option in options)
          Material(
            color: theme.brandContainer,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onSelected(option),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.brand,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
