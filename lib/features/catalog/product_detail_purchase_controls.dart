import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/cart/cart_product_actions.dart';
import 'package:motolink_pro_app/features/cart/cart_quantity_field.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'part_model.dart';
import 'variant_cart_picker_sheet.dart';

/// Compact purchase becomes a quantity control; desktop also allows preselection.
class ProductDetailPurchaseControls extends StatefulWidget {
  const ProductDetailPurchaseControls(
      {super.key,
      required this.part,
      required this.profile,
      required this.onOpenCart,
      this.onAsk,
      this.cart,
      this.variantFamily = const [],
      this.compact = false});
  final PartModel part;
  final ProfileModel profile;
  final VoidCallback onOpenCart;
  final VoidCallback? onAsk;
  final CartService? cart;

  /// Hermanas del mismo `parent_sku`. Si hay 2+, se ofrece agregar varias.
  final List<PartModel> variantFamily;
  final bool compact;

  @override
  State<ProductDetailPurchaseControls> createState() =>
      _PurchaseControlsState();
}

class _PurchaseControlsState extends State<ProductDetailPurchaseControls> {
  CartService get _cart => widget.cart ?? CartService.instance;
  late int _quantity = widget.part.minOrderQtyEffective;
  late int _accountRevision = _cart.accountRevision;
  late bool _hadLine = CartProductActions.lineFor(widget.part, _cart) != null;
  bool _pointerTriggered = false;
  GlobalKey<CartQuantityFieldState> _quantityKey =
      GlobalKey<CartQuantityFieldState>();

  @override
  void initState() {
    super.initState();
    _cart.addListener(_changed);
  }

  void _changed() {
    final hasLine = CartProductActions.lineFor(widget.part, _cart) != null;
    if (hasLine != _hadLine) {
      _hadLine = hasLine;
      // A rapidly reversed transition must not reuse an outgoing GlobalKey.
      _quantityKey = GlobalKey<CartQuantityFieldState>();
    }
    if (_accountRevision != _cart.accountRevision) {
      _accountRevision = _cart.accountRevision;
      _hadLine = CartProductActions.lineFor(widget.part, _cart) != null;
      _quantity = widget.part.minOrderQtyEffective;
      _quantityKey = GlobalKey<CartQuantityFieldState>();
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ProductDetailPurchaseControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.cart ?? CartService.instance;
    if (previous != _cart) {
      previous.removeListener(_changed);
      _cart.addListener(_changed);
    }
    if (oldWidget.part.id != widget.part.id || previous != _cart) {
      _quantity = widget.part.minOrderQtyEffective;
      _accountRevision = _cart.accountRevision;
      _hadLine = CartProductActions.lineFor(widget.part, _cart) != null;
      _quantityKey = GlobalKey<CartQuantityFieldState>();
    }
  }

  @override
  void dispose() {
    _cart.removeListener(_changed);
    super.dispose();
  }

  void _update(int value) {
    if (CartProductActions.lineFor(widget.part, _cart) != null) {
      CartProductActions.setQuantity(
          part: widget.part,
          profile: widget.profile,
          cart: _cart,
          quantity: value);
    } else {
      setState(() => _quantity = value);
    }
  }

  void _add() {
    final selected = widget.compact
        ? widget.part.minOrderQtyEffective
        : _quantityKey.currentState?.commit() ?? _quantity;
    final amount = CartProductActions.addQuantity(
        part: widget.part,
        profile: widget.profile,
        cart: _cart,
        quantity: selected);
    if (amount == 0) return;
    if (widget.compact) {
      // The revealed control and its live region are the confirmation.
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      return;
    }
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
        content: Text('$amount unidades añadidas al carrito.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
            label: 'Ver carrito', onPressed: widget.onOpenCart)));
  }

  Future<void> _openMultiVariantPicker() async {
    final family = widget.variantFamily.length > 1
        ? widget.variantFamily
        : widget.part.variantChoices;
    if (family.length < 2) return;
    final seed = widget.part.copyWith(variants: family);
    final result = await showVariantCartPickerSheet(
      context: context,
      part: seed,
      profile: widget.profile,
      cart: _cart,
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(
        '${result.totalUnits} unidades (${result.addedLines} opción(es)) '
        'añadidas al carrito.',
      ),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
          label: 'Ver carrito', onPressed: widget.onOpenCart),
    ));
  }

  void _step(int delta) {
    final current = _quantityKey.currentState?.commit() ??
        CartProductActions.lineFor(widget.part, _cart)?.quantity ??
        _quantity;
    _update(current + delta);
  }

  void _openCart() {
    _quantityKey.currentState?.commit();
    widget.onOpenCart();
  }

  Widget _compactPurchase(
      {required Widget selector,
      required Widget action,
      required bool inCart,
      required int quantity,
      required String initialLabel}) {
    final chat = widget.onAsk == null
        ? null
        : IconButton.outlined(
            key: const Key('ask-about-product'),
            tooltip: 'Preguntar sobre este producto',
            onPressed: widget.onAsk,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20));
    return Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent) _pointerTriggered = false;
          return KeyEventResult.ignored;
        },
        child: Listener(
          onPointerDown: (_) => _pointerTriggered = true,
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (chat != null) ...[chat, const SizedBox(width: 10)],
            Expanded(child: LayoutBuilder(builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              final style = Theme.of(context).textTheme.labelLarge!.merge(
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
              final painter = TextPainter(
                  text: TextSpan(text: initialLabel, style: style),
                  textScaler: scaler,
                  textDirection: Directionality.of(context))
                ..layout(
                    maxWidth:
                        (constraints.maxWidth - 50).clamp(1, double.infinity));
              final buttonHeight = painter.height.ceilToDouble() + 24;
              painter.dispose();
              final height = buttonHeight
                  .clamp((scaler.scale(18) + 24).clamp(48, double.infinity),
                      double.infinity)
                  .toDouble();
              final reduceMotion = MediaQuery.disableAnimationsOf(context) ||
                  MediaQuery.accessibleNavigationOf(context) ||
                  !_pointerTriggered;
              final duration = reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 220);
              final content = inCart
                  ? Semantics(
                      key: const ValueKey('purchase-in-cart'),
                      container: true,
                      liveRegion: true,
                      label: 'En tu carrito: $quantity unidades',
                      child: Row(children: [
                        Expanded(child: selector),
                        const SizedBox(width: 10),
                        SizedBox(
                            width: 48,
                            height: height,
                            child: IconButton.filled(
                                key: const Key('product-purchase-action'),
                                tooltip: 'Ver carrito',
                                onPressed: _openCart,
                                icon: const Icon(Icons.shopping_cart_outlined,
                                    size: 21))),
                      ]))
                  : SizedBox(
                      key: const ValueKey('purchase-add'),
                      width: double.infinity,
                      height: height,
                      child: action);
              return SizedBox(
                  key: const Key('compact-purchase-slot'),
                  height: height,
                  child: ClipRect(
                      child: AnimatedSwitcher(
                    duration: duration,
                    reverseDuration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    switchInCurve: const Cubic(.23, 1, .32, 1),
                    switchOutCurve: Curves.easeOut,
                    layoutBuilder: (current, previous) =>
                        Stack(fit: StackFit.expand, children: [
                      for (final old in previous)
                        IgnorePointer(child: ExcludeSemantics(child: old)),
                      if (current != null) current,
                    ]),
                    transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                            position: Tween<Offset>(
                                    begin: reduceMotion
                                        ? Offset.zero
                                        : const Offset(.16, 0),
                                    end: Offset.zero)
                                .animate(animation),
                            child: child)),
                    child: content,
                  )));
            })),
          ]),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final part = widget.part;
    final line = CartProductActions.lineFor(part, _cart);
    final minimum = line != null &&
            line.part.minOrderQtyEffective > part.minOrderQtyEffective
        ? line.part.minOrderQtyEffective
        : part.minOrderQtyEffective;
    final maximum = line != null && line.part.stockForSale < part.stockForSale
        ? line.part.stockForSale
        : part.stockForSale;
    final blocked = CartProductActions.blockReason(
        part: part, profile: widget.profile, cart: _cart);
    final enabled = blocked == null && maximum >= minimum;
    final quantity = line?.quantity ??
        (maximum >= minimum ? _quantity.clamp(minimum, maximum) : minimum);
    final unavailable = _cart.restoring
        ? 'Recuperando…'
        : !part.isActive
            ? 'Producto pausado'
            : part.stockForSale == 0
                ? 'Sin stock'
                : maximum < minimum
                    ? 'Stock insuficiente'
                    : widget.profile.pedidosSuspendidosMorosidad
                        ? 'Pedidos suspendidos'
                        : 'No disponible';

    final selector = SizedBox(
        width: 88 + MediaQuery.textScalerOf(context).scale(56),
        child: DecoratedBox(
            decoration: BoxDecoration(
                color: AppColors.surfaceTinted,
                border: Border.all(color: AppColors.borderSubtle),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              IconButton(
                  tooltip: 'Reducir cantidad',
                  onPressed:
                      enabled && quantity > minimum ? () => _step(-1) : null,
                  style: IconButton.styleFrom(
                      minimumSize: const Size(44, 48),
                      padding: EdgeInsets.zero),
                  icon: const Icon(Icons.remove_rounded, size: 18)),
              Expanded(
                  child: CartQuantityField(
                      key: _quantityKey,
                      quantity: quantity,
                      minimum: minimum,
                      maximum: maximum < minimum ? minimum : maximum,
                      embedded: true,
                      semanticLabel: 'Cantidad de ${part.nombre}',
                      onChanged: enabled ? _update : null)),
              IconButton(
                  tooltip: 'Aumentar cantidad',
                  onPressed:
                      enabled && quantity < maximum ? () => _step(1) : null,
                  style: IconButton.styleFrom(
                      minimumSize: const Size(44, 48),
                      padding: EdgeInsets.zero),
                  icon: const Icon(Icons.add_rounded, size: 18)),
            ])));
    final multiFamily = widget.variantFamily.length > 1
        ? widget.variantFamily
        : widget.part.variantChoices;
    final hasMultiVariants = multiFamily.length > 1;
    final addAction =
        hasMultiVariants ? _openMultiVariantPicker : _add;
    final addLabel = enabled ? 'Agregar al carrito' : unavailable;

    final action = FilledButton.icon(
        key: const Key('product-purchase-action'),
        onPressed: line != null
            ? _openCart
            : enabled
                ? addAction
                : null,
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            textStyle: TextStyle(
                fontSize: widget.compact ? 13 : 15,
                fontWeight: FontWeight.w600)),
        icon: Icon(
            line != null
                ? Icons.shopping_cart_outlined
                : hasMultiVariants
                    ? Icons.tune_rounded
                    : Icons.add_shopping_cart_rounded,
            size: 18),
        label: Text(
            line != null ? 'Ver carrito' : addLabel,
            textAlign: TextAlign.center));

    final status = Semantics(
        liveRegion: true,
        child: Text(
            line != null
                ? 'En tu carrito: $quantity unidades'
                : !enabled
                    ? 'Cantidad'
                    : hasMultiVariants
                        ? 'Elige cantidades por opción al agregar'
                        : 'Añadirás $quantity unidades',
            style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: line != null ? FontWeight.w600 : FontWeight.w400,
                color: line != null
                    ? Theme.of(context).colorScheme.primary
                    : AppColors.textSecondary)));

    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.compact) ...[
            _compactPurchase(
                selector: selector,
                action: action,
                inCart: line != null,
                quantity: quantity,
                initialLabel: addLabel),
          ] else ...[
            Row(children: [
              Expanded(child: status),
              if (widget.onAsk != null)
                TextButton.icon(
                    key: const Key('ask-about-product'),
                    onPressed: widget.onAsk,
                    style: TextButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(fontSize: 12)),
                    icon:
                        const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                    label: const Text('Consultar')),
            ]),
            const SizedBox(height: 8),
            if (line != null || !hasMultiVariants)
              LayoutBuilder(builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(14) >= 21;
                if (constraints.maxWidth < 330 || largeText) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(alignment: Alignment.centerLeft, child: selector),
                        const SizedBox(height: 8),
                        action,
                      ]);
                }
                return Row(children: [
                  selector,
                  const SizedBox(width: 10),
                  Expanded(child: action)
                ]);
              })
            else
              action,
          ],
          if (blocked != null &&
              (line != null ||
                  (part.isActive &&
                      maximum >= minimum &&
                      !widget.profile.pedidosSuspendidosMorosidad))) ...[
            const SizedBox(height: 6),
            Text(blocked,
                style: TextStyle(
                    fontSize: 12, height: 1.4, color: AppColors.textSecondary)),
          ],
        ]);
  }
}
