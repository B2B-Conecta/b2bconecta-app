import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/config/brand_copy.dart';
import 'package:motolink_pro_app/core/auth/auth_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/motolink_pro_logo.dart';

/// Cuenta bloqueada o con baja lógica: no entra al panel.
class AccountLockedScreen extends StatelessWidget {
  const AccountLockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MotoLinkProLogo(height: 48),
                  const SizedBox(height: 28),
                  const Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: AppColors.brand,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cuenta sin acceso',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Esta cuenta está deshabilitada en ${BrandCopy.name}. '
                    'Si cree que es un error, contacte a B2B Conecta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextButton(
                    onPressed: () => AuthService.signOut(),
                    child: const Text('Cerrar sesión'),
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
