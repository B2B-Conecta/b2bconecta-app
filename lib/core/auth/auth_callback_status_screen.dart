import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';

/// Pantalla intermedia al canjear enlace de correo (confirmación / recovery).
class AuthCallbackStatusScreen extends StatelessWidget {
  const AuthCallbackStatusScreen({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  const AuthCallbackStatusScreen.verifyingSignup({super.key})
      : title = 'Verificando correo…',
        subtitle = 'Un momento, estamos confirmando tu cuenta.';

  const AuthCallbackStatusScreen.verifyingLink({super.key})
      : title = 'Abriendo enlace…',
        subtitle = 'Validando tu acceso de forma segura.';

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Scaffold(
      backgroundColor: theme.surfaceSubtle,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const B2bConectaMark(size: 72),
                  const SizedBox(height: 28),
                  LucideIcon(
                    LucideGlyph.shieldCheck,
                    size: 28,
                    color: theme.brand,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                  if ((subtitle ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle!.trim(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
