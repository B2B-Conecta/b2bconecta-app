import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/adaptive_admin_sheet.dart';
import 'product_delete_result.dart';

/// Acción elegida tras un borrado parcial o bloqueado.
enum ProductDeleteOutcomeAction {
  dismiss,
  pauseBlocked,
}

/// Muestra el desglose amigable (eliminados vs bloqueados por historial).
Future<ProductDeleteOutcomeAction> showProductDeleteOutcomeSheet({
  required BuildContext context,
  required ProductDeleteBatchResult result,
  bool offerPause = true,
}) async {
  if (!result.hasBlocked) return ProductDeleteOutcomeAction.dismiss;

  final action = await showAdaptiveAdminSheet<ProductDeleteOutcomeAction>(
    context: context,
    builder: (ctx, _) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      final blockedPreview = result.blocked.take(8).toList();
      final extraBlocked = result.blockedCount - blockedPreview.length;
      final title = result.allBlocked
          ? (result.blockedCount == 1
              ? 'No se pudo eliminar'
              : 'No se pudieron eliminar')
          : 'Eliminación parcial';

      return Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (result.hasDeleted) ...[
              Text(
                result.deletedCount == 1
                    ? '1 producto se eliminó correctamente.'
                    : '${result.deletedCount} productos se eliminaron correctamente.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              result.blockedCount == 1
                  ? 'Este producto no se puede borrar porque forma parte del '
                      'historial de postventa (pedidos de reemplazo). Ese '
                      'historial debe conservarse.'
                  : '${result.blockedCount} productos no se pueden borrar '
                      'porque forman parte del historial de postventa '
                      '(pedidos de reemplazo). Ese historial debe conservarse.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in blockedPreview)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.link_off_rounded,
                      size: 16,
                      color: Colors.orange.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            ProductDeleteErrors.reasonLabel(item.reason),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (extraBlocked > 0)
              Text(
                'y $extraBlocked más',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceTinted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Text(
                  'Alternativa recomendada: pausa u oculta el producto '
                  '(estado inactivo). Deja de mostrarse en el catálogo y '
                  'conservas la trazabilidad comercial.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (offerPause) ...[
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  ctx,
                  ProductDeleteOutcomeAction.pauseBlocked,
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.pause_circle_outline, size: 20),
                label: Text(
                  result.blockedCount == 1
                      ? 'Pausar este producto'
                      : 'Pausar los ${result.blockedCount} bloqueados',
                ),
              ),
              const SizedBox(height: 4),
            ],
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, ProductDeleteOutcomeAction.dismiss),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    },
  );

  return action ?? ProductDeleteOutcomeAction.dismiss;
}
