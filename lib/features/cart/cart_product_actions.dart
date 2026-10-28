import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'cart_service.dart';

/// Shared by the detail and catalog so quick add keeps purchase restrictions.
abstract final class CartProductActions {
  static CartLine? lineFor(PartModel part, CartService cart) {
    for (final line in cart.lines) {
      if (line.part.id == part.id) return line;
    }
    return null;
  }

  /// Uses the same limits and repricing as the cart screen.
  static void setQuantity(
      {required PartModel part,
      required ProfileModel profile,
      required CartService cart,
      required int quantity}) {
    final line = lineFor(part, cart);
    if (line == null ||
        blockReason(part: part, profile: profile, cart: cart) != null) return;
    final minimum = part.minOrderQtyEffective > line.part.minOrderQtyEffective
        ? part.minOrderQtyEffective
        : line.part.minOrderQtyEffective;
    final maximum = part.stockForSale < line.part.stockForSale
        ? part.stockForSale
        : line.part.stockForSale;
    if (maximum < minimum) return;
    cart.setQuantity(part.id, quantity.clamp(minimum, maximum));
  }

  static String? blockReason(
      {required PartModel part,
      required ProfileModel? profile,
      required CartService cart}) {
    if (profile == null || !profile.isAliado) {
      return 'Inicia sesión como tienda minorista para agregar productos.';
    }
    if (!profile.hasActiveAccountAccess) {
      return 'Tu cuenta debe estar habilitada para realizar compras.';
    }
    if (!cart.canEdit) {
      return 'Estamos recuperando tu carrito. Espera o reintenta desde el carrito.';
    }
    if (profile.pedidosSuspendidosMorosidad) {
      return 'B2B Conecta suspendió nuevos pedidos en su cuenta por morosidad.';
    }
    if (part.ownerId?.trim().isNotEmpty != true) {
      return 'No se pudo identificar al importador.';
    }
    if (!part.isActive) return 'Este producto está pausado por el proveedor.';
    if (part.stockForSale < 1) return 'Sin stock disponible.';
    if (part.stockForSale < part.minOrderQtyEffective) {
      return 'Stock insuficiente para el mínimo de pedido (${part.minOrderQtyLabelEs}).';
    }
    return null;
  }

  /// Returns the newly added quantity. A second tap never duplicates the line.
  static int addMinimum(
          {required PartModel part,
          required ProfileModel profile,
          required CartService cart}) =>
      addQuantity(
          part: part,
          profile: profile,
          cart: cart,
          quantity: part.minOrderQtyEffective);

  /// Adds an explicitly selected quantity once, using the usual buying guards.
  static int addQuantity(
      {required PartModel part,
      required ProfileModel profile,
      required CartService cart,
      required int quantity}) {
    if (blockReason(part: part, profile: profile, cart: cart) != null ||
        cart.lines.any((line) => line.part.id == part.id)) return 0;
    final selected =
        quantity.clamp(part.minOrderQtyEffective, part.stockForSale);
    cart.addOrIncrement(part,
        delta: selected,
        precioUnitarioAliadoRef:
            part.precioUnitarioParaAliado(quantity: selected));
    return selected;
  }

  /// Sets the cart line to [quantity], creating it when missing.
  /// Used by the multi-variant picker so confirming can refresh existing lines.
  ///
  /// Con [enforceLineMinOrder] en false (familia de variantes) se permite
  /// cantidad por SKU bajo el MOQ de línea; el modal valida el acumulado.
  static int upsertQuantity(
      {required PartModel part,
      required ProfileModel profile,
      required CartService cart,
      required int quantity,
      bool enforceLineMinOrder = true}) {
    final blocked = enforceLineMinOrder
        ? blockReason(part: part, profile: profile, cart: cart)
        : blockReasonForFamilyLine(
            part: part, profile: profile, cart: cart);
    if (blocked != null) return 0;

    final maximum = part.stockForSale;
    if (maximum < 1) return 0;
    if (quantity < 1) {
      if (lineFor(part, cart) != null) {
        cart.setQuantity(part.id, 0, enforceLineMinOrder: false);
      }
      return 0;
    }

    final minimum =
        enforceLineMinOrder ? part.minOrderQtyEffective : 1;
    if (enforceLineMinOrder &&
        (maximum < minimum || quantity < minimum)) {
      return 0;
    }
    final selected = quantity.clamp(minimum, maximum);
    if (lineFor(part, cart) != null) {
      cart.setQuantity(
        part.id,
        selected,
        enforceLineMinOrder: enforceLineMinOrder,
      );
      return selected;
    }
    cart.addOrIncrement(
      part,
      delta: selected,
      precioUnitarioAliadoRef:
          part.precioUnitarioParaAliado(quantity: selected),
      enforceLineMinOrder: enforceLineMinOrder,
    );
    return selected;
  }

  /// Como [blockReason], pero sin exigir stock ≥ MOQ de la línea (MOQ familiar).
  static String? blockReasonForFamilyLine(
      {required PartModel part,
      required ProfileModel? profile,
      required CartService cart}) {
    if (profile == null || !profile.isAliado) {
      return 'Inicia sesión como tienda minorista para agregar productos.';
    }
    if (!profile.hasActiveAccountAccess) {
      return 'Tu cuenta debe estar habilitada para realizar compras.';
    }
    if (!cart.canEdit) {
      return 'Estamos recuperando tu carrito. Espera o reintenta desde el carrito.';
    }
    if (profile.pedidosSuspendidosMorosidad) {
      return 'B2B Conecta suspendió nuevos pedidos en su cuenta por morosidad.';
    }
    if (part.ownerId?.trim().isNotEmpty != true) {
      return 'No se pudo identificar al importador.';
    }
    if (!part.isActive) return 'Este producto está pausado por el proveedor.';
    if (part.stockForSale < 1) return 'Sin stock disponible.';
    return null;
  }
}
