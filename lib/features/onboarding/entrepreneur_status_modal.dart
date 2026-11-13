import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/onboarding/entrepreneur_retailer.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Modal / sheet con plazos del programa Minorista-Emprendedor.
Future<void> showEntrepreneurStatusModal({
  required BuildContext context,
  required ProfileModel profile,
}) {
  final mobile = MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
  if (mobile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: B2BThemeExtension.of(context).dialogSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
          ),
          child: _EntrepreneurStatusBody(profile: profile),
        ),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: B2BThemeExtension.of(ctx).dialogSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: _EntrepreneurStatusBody(profile: profile),
      ),
    ),
  );
}

class _EntrepreneurStatusBody extends StatelessWidget {
  const _EntrepreneurStatusBody({required this.profile});

  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final status = profile.entrepreneurStatus?.trim().toLowerCase();
    final purchaseDays = _daysLeft(profile.firstPurchaseDeadline);
    final kycDays = _daysLeft(profile.kycCompletionDeadline);
    final warning = EntrepreneurStatus.isFirstPurchaseWarning(status);
    final day = profile.entrepreneurFirstPurchaseDayOfEight;
    final stageA = status == EntrepreneurStatus.activeTrial ||
        warning ||
        (status == null || status.isEmpty);
    final stageB = status == EntrepreneurStatus.kycInProgress ||
        (status == EntrepreneurStatus.expiredLocked &&
            profile.kycCompletionDeadline != null) ||
        status == EntrepreneurStatus.reactivationRequested ||
        status == EntrepreneurStatus.verifiedStandard ||
        profile.kycCompletionDeadline != null;

    final String? ctaLabel;
    if (warning) {
      ctaLabel = null;
    } else if (stageB || status == EntrepreneurStatus.kycInProgress) {
      ctaLabel = 'Completar mis documentos';
    } else {
      ctaLabel = 'Ir a verificación KYC';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Programa Minorista-Emprendedor',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                    letterSpacing: -0.2,
                  ),
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
          const SizedBox(height: 6),
          Text(
            warning
                ? 'Te quedan 3 días hábiles para realizar tu primera compra. '
                    'De lo contrario, tu cuenta será bloqueada temporalmente.'
                : 'Mantén tu cuenta activa completando estos hitos a tiempo.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          if (stageA) ...[
            _InfoBlock(
              icon: LucideGlyph.shoppingBag,
              title: warning
                  ? 'Cuenta regresiva · día $day de 8 hábiles'
                  : 'Plazo de primera compra (8 días hábiles)',
              body: warning
                  ? 'Ya transcurrieron 5 días hábiles sin una compra confirmada. '
                      'Completa tu primer pedido en los 3 días hábiles restantes '
                      'para evitar el bloqueo temporal.'
                  : (purchaseDays == null
                      ? 'Confirma tu primer pedido dentro de los 8 días hábiles '
                          'para mantener la cuenta activa.'
                      : 'Día $day de 8. Te quedan $purchaseDays '
                          '${purchaseDays == 1 ? 'día' : 'días'} de calendario '
                          'hasta el vencimiento del plazo hábil.'),
            ),
            const SizedBox(height: 12),
          ],
          if (stageB || !stageA) ...[
            _InfoBlock(
              icon: LucideGlyph.fileText,
              title: 'Plazo de documentación (8 semanas)',
              body: kycDays == null
                  ? 'Tras tu primera compra dispones de 8 semanas para completar '
                      'el expediente comercial: Registro Mercantil, 2 referencias '
                      'bancarias y Registro Comercial / Carta de Crédito.'
                  : 'Tienes $kycDays ${kycDays == 1 ? 'día' : 'días'} para '
                      'completar el expediente (Registro Mercantil, 2 referencias '
                      'bancarias y Registro Comercial / Carta de Crédito).',
            ),
            const SizedBox(height: 12),
          ],
          if (status == EntrepreneurStatus.expiredLocked ||
              status == EntrepreneurStatus.reactivationRequested)
            const _InfoBlock(
              icon: LucideGlyph.shieldOff,
              title: 'Cuenta en pausa / reactivación',
              body:
                  'Puedes seguir subiendo o reemplazando los documentos comerciales '
                  'mientras se gestiona la reactivación.',
            ),
          if (ctaLabel != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).maybePop();
                  MainShellTabController.navigateToProfileKycDocumentation();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: theme.brand,
                  foregroundColor: theme.surfaceCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: LucideIcon(
                  LucideGlyph.clipboardCheck,
                  size: 18,
                  color: theme.surfaceCard,
                ),
                label: Text(
                  ctaLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static int? _daysLeft(DateTime? deadline) {
    if (deadline == null) return null;
    final days = deadline.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  final LucideGlyph icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LucideIcon(icon, size: 22, color: theme.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
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
