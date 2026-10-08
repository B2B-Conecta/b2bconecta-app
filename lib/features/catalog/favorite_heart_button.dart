import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/aliado_favorites_service.dart';

/// Corazón de favorito sobre la foto del repuesto.
class FavoriteHeartButton extends StatelessWidget {
  const FavoriteHeartButton({
    super.key,
    required this.productId,
    this.compact = false,
  });

  final String productId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AliadoFavoritesService.instance,
      builder: (context, _) {
        final saved = AliadoFavoritesService.instance.contains(productId);
        final size = compact ? 28.0 : 36.0;
        return Material(
          color: AppColors.card.withOpacity(0.92),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _toggle(context),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                saved ? Icons.favorite : Icons.favorite_border,
                size: compact ? 16 : 20,
                color: saved ? AppColors.brand : AppColors.textSecondary,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final saved = await AliadoFavoritesService.instance.toggle(productId);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Guardado en Favoritos' : 'Quitado de Favoritos',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar el favorito: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
