import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_breakpoints.dart';

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
                      color: Colors.white,
                      elevation: 0,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
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
            Color(0xFF0D47A1),
            AppColors.brandBlue,
            Color(0xFF1976D2),
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
              const Text(
                'Complete su perfil B2B',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Registre su negocio, verifique documentos y acceda al catálogo, '
                'pedidos y operaciones de MotoLink.',
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.5,
                  color: Colors.white.withOpacity(0.88),
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
                label: 'Acceso al panel cuando MotoLink apruebe',
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
