import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'cart_service.dart';

/// Banner flotante sobre la grilla: cápsula blanca con icono + texto + CTA.
class CatalogCartBar extends StatelessWidget {
  const CatalogCartBar({super.key, required this.onOpen});
  final VoidCallback onOpen;

  static const _ctaBlue = Color(0xFF004BDD);
  static const _subtitle = Color(0xFF5B5BD6);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: CartService.instance,
        builder: (context, _) {
          final cart = CartService.instance;
          if (cart.isEmpty && !cart.restoring && cart.storageMessage == null) {
            return const SizedBox.shrink();
          }
          final units = cart.itemCount;
          final lines = cart.lines.length;
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Material(
                color: AppColors.white,
                elevation: 6,
                shadowColor: AppColors.black.withOpacity(0.22),
                borderRadius: BorderRadius.circular(999),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                    child: Row(
                      children: [
                        const LucideIcon(
                          LucideGlyph.shoppingCart,
                          size: 22,
                          color: AppColors.black,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                cart.restoring
                                    ? 'Recuperando tu carrito…'
                                    : '$units ${units == 1 ? 'unidad' : 'unidades'} en tu carrito',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  color: AppColors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cart.storageMessage != null
                                    ? 'Revisa el estado de tu carrito'
                                    : '$lines ${lines == 1 ? 'repuesto' : 'repuestos'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                  color: _subtitle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: onOpen,
                          style: FilledButton.styleFrom(
                            backgroundColor: _ctaBlue,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: const Text('Ver carrito'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
