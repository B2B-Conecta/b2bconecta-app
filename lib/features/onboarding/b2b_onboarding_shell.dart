import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';

/// Layout onboarding / registro B2B: panel de marca en escritorio + formulario centrado.
class B2bOnboardingShell extends StatelessWidget {
  const B2bOnboardingShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= AppBreakpoints.authDesktop;

        if (!isDesktop) {
          return ColoredBox(
            color: theme.background,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppBreakpoints.formMaxWidth,
                    ),
                    child: Material(
                      color: theme.surfaceCard,
                      elevation: 0,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.borderSubtle),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return ColoredBox(
          color: theme.background,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(flex: 5, child: _B2bOnboardingBrandingPanel()),
              Expanded(
                flex: 5,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 28,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppBreakpoints.formMaxWidth,
                      ),
                      child: Material(
                        color: theme.surfaceCard,
                        elevation: 0,
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: theme.borderSubtle),
                            boxShadow: [
                              BoxShadow(
                                color: theme.textPrimary.withOpacity(0.06),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _B2bOnboardingBrandingPanel extends StatelessWidget {
  const _B2bOnboardingBrandingPanel();

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final onBrand = theme.surfaceCard;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.brand,
            Color.lerp(theme.brand, theme.textPrimary, 0.35)!,
            theme.brand,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MotoLinkProLogo(height: 64, forceWhite: true),
              const SizedBox(height: 28),
              Text(
                'Complete su perfil B2B',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: onBrand,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Registre su negocio, verifique documentos y acceda al catálogo, '
                'pedidos y operaciones. Los emprendedores pueden empezar hoy y '
                'completar el expediente en 8 semanas.',
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.5,
                  color: onBrand.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 32),
              _BrandingBullet(
                glyph: LucideGlyph.store,
                label: 'Datos fiscales y ubicación del negocio',
                color: onBrand,
              ),
              const SizedBox(height: 12),
              _BrandingBullet(
                glyph: LucideGlyph.sparkles,
                label: 'Opción Minorista-Emprendedor con acceso inmediato',
                color: onBrand,
              ),
              const SizedBox(height: 12),
              _BrandingBullet(
                glyph: LucideGlyph.shieldCheck,
                label: 'Verificación documental segura',
                color: onBrand,
              ),
              const SizedBox(height: 12),
              _BrandingBullet(
                glyph: LucideGlyph.layoutDashboard,
                label: 'Acceso al panel según su modalidad',
                color: onBrand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandingBullet extends StatelessWidget {
  const _BrandingBullet({
    required this.glyph,
    required this.label,
    required this.color,
  });

  final LucideGlyph glyph;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LucideIcon(glyph, size: 20, color: color.withOpacity(0.95)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: color.withOpacity(0.92),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
