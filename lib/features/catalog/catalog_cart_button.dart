import 'package:flutter/material.dart';
import 'package:motolink_pro_app/features/cart/cart_product_actions.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/cart/cart_quantity_field.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'part_model.dart';
import 'variant_cart_picker_sheet.dart';

class CatalogCartButton extends StatelessWidget {
  const CatalogCartButton(
      {super.key,
      required this.part,
      required this.profile,
      this.cart,
      this.onChooseVariant});
  final PartModel part;
  final ProfileModel profile;
  final CartService? cart;

  /// Override for tests or custom flows. Default opens the multi-qty sheet.
  final VoidCallback? onChooseVariant;

  Future<void> _openVariantPicker(
      BuildContext context, CartService service) async {
    if (onChooseVariant != null) {
      onChooseVariant!();
      return;
    }
    await showVariantCartPickerSheet(
      context: context,
      part: part,
      profile: profile,
      cart: service,
    );
  }

  void _activate(CartService service) {
    if (service.lines.any((line) => line.part.id == part.id)) {
      return;
    }
    CartProductActions.addMinimum(part: part, profile: profile, cart: service);
  }

  @override
  Widget build(BuildContext context) {
    final service = cart ?? CartService.instance;
    return ListenableBuilder(
        listenable: service,
        builder: (context, _) {
          const ctaBlue = Color(0xFF004BDD);
          final ctaShape = RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999));
          final ctaStyle = FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              backgroundColor: ctaBlue,
              foregroundColor: AppColors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              shape: ctaShape,
              textStyle: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800));
          if (part.variantChoices.isNotEmpty) {
            return FilledButton.icon(
                onPressed: () => _openVariantPicker(context, service),
                style: ctaStyle,
                icon: const Icon(Icons.shopping_cart_outlined, size: 17),
                label: const Text('Agregar'));
          }
          final line = CartProductActions.lineFor(part, service);
          final blocked = CartProductActions.blockReason(
              part: part, profile: profile, cart: service);
          if (line != null) {
            final minimum =
                part.minOrderQtyEffective > line.part.minOrderQtyEffective
                    ? part.minOrderQtyEffective
                    : line.part.minOrderQtyEffective;
            final maximum = part.stockForSale < line.part.stockForSale
                ? part.stockForSale
                : line.part.stockForSale;
            final editable = blocked == null && maximum >= minimum;
            void update(int value) => CartProductActions.setQuantity(
                part: part, profile: profile, cart: service, quantity: value);
            final picker = Tooltip(
                message: blocked ?? '${line.quantity} unidades en tu carrito',
                child: Semantics(
                    container: true,
                    label: 'En carrito: ${part.nombre}',
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: AppColors.brandBlueContainer,
                            border: Border.all(color: AppColors.borderSubtle),
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          IconButton(
                              tooltip: 'Reducir cantidad de ${part.nombre}',
                              onPressed: editable && line.quantity > minimum
                                  ? () => update(line.quantity - 1)
                                  : null,
                              style: IconButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                  padding: EdgeInsets.zero),
                              icon: const Icon(Icons.remove, size: 18)),
                          Expanded(
                              child: CartQuantityField(
                                  key: ValueKey(
                                      '${service.accountRevision}:${part.id}'),
                                  quantity: line.quantity,
                                  minimum: minimum,
                                  maximum:
                                      maximum < minimum ? minimum : maximum,
                                  semanticLabel:
                                      'Cantidad en carrito de ${part.nombre}',
                                  embedded: true,
                                  onChanged: editable ? update : null)),
                          IconButton(
                              tooltip: 'Aumentar cantidad de ${part.nombre}',
                              onPressed: editable && line.quantity < maximum
                                  ? () => update(line.quantity + 1)
                                  : null,
                              style: IconButton.styleFrom(
                                  minimumSize: const Size(44, 44),
                                  padding: EdgeInsets.zero),
                              icon: const Icon(Icons.add, size: 18)),
                        ]))));
            return picker;
          }
          final label = service.restoring
              ? 'Recuperando…'
              : !part.isActive
                  ? 'Producto pausado'
                  : part.stockForSale < 1
                      ? 'Sin stock'
                      : part.stockForSale < part.minOrderQtyEffective
                          ? 'Stock insuficiente'
                          : profile.pedidosSuspendidosMorosidad
                              ? 'Pedidos suspendidos'
                              : blocked != null
                                  ? 'No disponible'
                                  : 'Agregar';
          final button = Tooltip(
              message: blocked ??
                  'Agregar el mínimo de ${part.minOrderQtyEffective} unidades',
              child: FilledButton(
                onPressed: blocked == null ? () => _activate(service) : null,
                style: ctaStyle,
                child: Semantics(
                    label: blocked == null
                        ? '$label: ${part.nombre}, ${part.minOrderQtyEffective} unidades'
                        : '$label: ${part.nombre}',
                    child: ExcludeSemantics(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.shopping_cart_outlined, size: 17),
                      const SizedBox(width: 6),
                      Flexible(child: Text(label, textAlign: TextAlign.center)),
                    ]))),
              ));
          return button;
        });
  }
}
