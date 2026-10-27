import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/catalog/aliado_favorites_service.dart';

/// Corazón de favorito sobre la foto del repuesto.
class FavoriteHeartButton extends StatelessWidget {
  const FavoriteHeartButton({
    super.key,
    required this.productId,
    this.compact = false,
    this.prominent = false,
  });

  final String productId;
  final bool compact;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AliadoFavoritesService.instance,
      builder: (context, _) {
        final saved = AliadoFavoritesService.instance.contains(productId);
        final size = prominent ? 52.0 : 44.0;
        return IconButton(
          onPressed: () => _toggle(context),
          tooltip: saved ? 'Quitar de favoritos' : 'Guardar en favoritos',
          isSelected: saved,
          icon: const Icon(Icons.favorite_border),
          selectedIcon: const Icon(Icons.favorite),
          style: IconButton.styleFrom(
            minimumSize: Size.square(size),
            maximumSize: Size.square(size),
            padding: const EdgeInsets.all(8),
            shape: const CircleBorder(),
            backgroundColor: AppColors.card.withOpacity(0.92),
            foregroundColor: saved
                ? Theme.of(context).colorScheme.primary
                : AppColors.textSecondary,
            iconSize: prominent ? 28 : (compact ? 20 : 24),
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
