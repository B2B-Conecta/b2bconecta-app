import 'package:flutter/material.dart';

import '../gen/motolink_pro_logo_bytes.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Alturas recomendadas del logo horizontal en auth.
abstract final class MotoLinkProLogoHeights {
  static const double login = 112;
}

bool _useWhiteLogo({required bool forceWhite}) {
  if (forceWhite) return true;
  // Una sola fuente de verdad: el modo elegido (claro/oscuro).
  return ThemeController.instance.isDark;
}

/// Logo horizontal B2B Conecta.
/// Claro → logo color; Oscuro → logo blanco (legible sobre fondos oscuros).
class MotoLinkProLogo extends StatelessWidget {
  const MotoLinkProLogo({
    super.key,
    required this.height,
    this.fit = BoxFit.contain,
    this.forceWhite = false,
  });

  final double height;
  final BoxFit fit;
  final bool forceWhite;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final white = _useWhiteLogo(forceWhite: forceWhite);
        final bytes = white
            ? decodeB2bConectaLogoWhitePng()
            : decodeB2bConectaLogoColorPng();
        return Image.memory(
          bytes,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => Icon(
            Icons.hub_outlined,
            size: height * 0.65,
            color: white ? AppColors.white : AppColors.brand,
          ),
        );
      },
    );
  }
}

/// Isotipo «B» (sin wordmark).
class B2bConectaMark extends StatelessWidget {
  const B2bConectaMark({
    super.key,
    required this.size,
    this.forceWhite = false,
  });

  final double size;
  final bool forceWhite;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final white = _useWhiteLogo(forceWhite: forceWhite);
        final asset = white
            ? 'assets/isotipo-b2b-conecta-white.png'
            : 'assets/isotipo-b2b-conecta-blue.png';
        return Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => Icon(
            Icons.hub_outlined,
            size: size * 0.85,
            color: white ? AppColors.white : AppColors.brand,
          ),
        );
      },
    );
  }
}

/// Placeholder de logo de negocio (nunca el logo de plataforma).
/// Se actualiza al cambiar claro/oscuro vía [ThemeController].
class BusinessLogoPlaceholder extends StatelessWidget {
  const BusinessLogoPlaceholder({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final dark = ThemeController.instance.isDark;
        // Claro: azul marca oscuro sobre tinte suave. Oscuro: acento legible.
        final iconColor = dark ? AppColors.brandAccent : AppColors.brandBlue;
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brandBlueContainer,
            borderRadius: BorderRadius.circular(size * 0.16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Icon(
            Icons.storefront_outlined,
            size: size * 0.48,
            color: iconColor,
          ),
        );
      },
    );
  }
}
