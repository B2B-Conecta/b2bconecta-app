import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'cart_service.dart';

class CatalogCartBar extends StatelessWidget {
  const CatalogCartBar({super.key, required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: CartService.instance,
        builder: (context, _) {
          final cart = CartService.instance;
          if (cart.isEmpty && !cart.restoring && cart.storageMessage == null) {
            return const SizedBox.shrink();
          }
          return Material(
            color: AppColors.card,
            child: SafeArea(
                top: false,
                bottom: false,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      border:
                          Border(top: BorderSide(color: AppColors.divider))),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              cart.restoring
                                  ? 'Recuperando tu carrito…'
                                  : '${cart.itemCount} unidades en tu carrito',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          Text(
                              cart.storageMessage != null
                                  ? 'Revisa el estado de tu carrito'
                                  : '${cart.lines.length} ${cart.lines.length == 1 ? 'repuesto' : 'repuestos'} · revisa precios y entrega',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ])),
                    const SizedBox(width: 12),
                    FilledButton(
                        onPressed: onOpen, child: const Text('Ver carrito')),
                  ]),
                )),
          );
        },
      );
}
