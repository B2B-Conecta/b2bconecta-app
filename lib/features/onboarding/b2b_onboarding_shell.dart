import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';

/// Layout onboarding / registro B2B: panel de marca en escritorio + formulario centrado.
class B2bOnboardingShell extends StatelessWidget {
  const B2bOnboardingShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= AppBreakpoints.authDesktop;

        if (!isDesktop) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.formMaxWidth,
                  ),
                  child: child,
                ),
              ),
            ),
          );
        }

        return Row(
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
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.surfaceTinted
                          : AppColors.white,
                      elevation: 0,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderSubtle),
                          boxShadow: AppDecorations.cardShadow,
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
        );
      },
    );
  }
}

class _B2bOnboardingBrandingPanel extends StatelessWidget {
  const _B2bOnboardingBrandingPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.black,
            AppColors.brandBlue,
            AppColors.brandAccent,
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
              // Un solo logo de plataforma en el panel; el formulario no lo repite.
              const MotoLinkProLogo(height: 64, forceWhite: true),
              const SizedBox(height: 28),
              const Text(
                'Complete su perfil B2B',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Registre su negocio, verifique documentos y acceda al catálogo, '
                'pedidos y operaciones.',
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.5,
                  color: AppColors.white.withOpacity(0.88),
                ),
              ),
              const SizedBox(height: 32),
              const _BrandingBullet(
                icon: Icons.storefront_outlined,
                label: 'Datos fiscales y ubicación del taller',
              ),
              const SizedBox(height: 12),
              const _BrandingBullet(
                icon: Icons.folder_shared_outlined,
                label: 'Verificación documental segura',
              ),
              const SizedBox(height: 12),
              const _BrandingBullet(
                icon: Icons.dashboard_outlined,
                label: 'Acceso al panel cuando se apruebe su cuenta',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandingBullet extends StatelessWidget {
  const _BrandingBullet({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.white.withOpacity(0.92)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
