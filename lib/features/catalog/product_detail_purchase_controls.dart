import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/app_notice_message.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/cart/cart_product_actions.dart';
import 'package:motolink_pro_app/features/cart/cart_quantity_field.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'part_model.dart';
import 'variant_cart_picker_sheet.dart';

/// Adding reveals the quantity control and changes the action to open the cart.
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
    final selected = _quantityKey.currentState?.commit() ?? _quantity;
    CartProductActions.addQuantity(
        part: widget.part,
        profile: widget.profile,
        cart: _cart,
        quantity: selected);
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
    messenger.showSnackBar(appActionNotice(
      content: Text(
        '${result.totalUnits} unidades (${result.addedLines} opción(es)) '
        'añadidas al carrito.',
      ),
      actionLabel: 'Ver carrito',
      onAction: widget.onOpenCart,
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

  Widget _compactPurchase({
    required Widget selector,
    required Widget action,
    required bool inCart,
    required int quantity,
  }) {
    final chat = widget.onAsk == null
        ? null
        : OutlinedButton(
            key: const Key('ask-about-product'),
            onPressed: widget.onAsk,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              side: BorderSide(color: AppColors.borderSubtle),
              foregroundColor: AppColors.textPrimary,
            ),
            child: const LucideIcon(LucideGlyph.messageCircle, size: 22),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            inCart
                ? 'En tu carrito: $quantity unidades'
                : 'Añadirás $quantity unidades',
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              fontWeight: inCart ? FontWeight.w600 : FontWeight.w400,
              color: inCart
                  ? Theme.of(context).colorScheme.primary
                  : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 330 ||
              MediaQuery.textScalerOf(context).scale(14) >= 21;
          final actionRow = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (chat != null) ...[chat, const SizedBox(width: 8)],
              if (!stacked)
                _revealQuantity(selector, inCart: inCart, horizontal: true),
              Expanded(
                child: SizedBox(
                  key: const Key('compact-purchase-slot'),
                  height: 48,
                  child: action,
                ),
              ),
            ],
          );
          if (!stacked) return actionRow;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                  alignment: Alignment.centerLeft,
                  child: _revealQuantity(selector, inCart: inCart)),
              actionRow,
            ],
          );
        }),
      ],
    );
  }

  Widget _revealQuantity(Widget selector,
      {required bool inCart, bool horizontal = false}) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedSwitcher(
      duration:
          reducedMotion ? Duration.zero : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axis: horizontal ? Axis.horizontal : Axis.vertical,
        axisAlignment: -1,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: inCart
          ? Padding(
              key: ValueKey('quantity-${widget.part.id}'),
              padding: horizontal
                  ? const EdgeInsets.only(right: 10)
                  : const EdgeInsets.only(bottom: 8),
              child: selector,
            )
          : const SizedBox.shrink(key: ValueKey('no-quantity')),
    );
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
                color: AppColors.white,
                border: Border.all(color: AppColors.borderSubtle),
                borderRadius: BorderRadius.circular(14)),
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
    final addAction = hasMultiVariants ? _openMultiVariantPicker : _add;
    final addLabel = enabled
        ? (widget.compact ? 'Agregar' : 'Agregar al carrito')
        : unavailable;
    final showOpenCart = line != null;

    final action = FilledButton.icon(
        key: const Key('product-purchase-action'),
        onPressed: showOpenCart
            ? _openCart
            : enabled
                ? addAction
                : null,
        style: FilledButton.styleFrom(
            backgroundColor: widget.compact ? const Color(0xFF004BDD) : null,
            foregroundColor: widget.compact ? AppColors.white : null,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.compact ? 14 : 12),
            ),
            textStyle: TextStyle(
                fontSize: widget.compact ? 14 : 15,
                fontWeight: FontWeight.w700)),
        icon: const LucideIcon(LucideGlyph.handbag, size: 18),
        label: AnimatedSwitcher(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: Text(showOpenCart ? 'Ver carrito' : addLabel,
              key: ValueKey(showOpenCart ? 'open-cart' : addLabel),
              textAlign: TextAlign.center),
        ));

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
                quantity: quantity),
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
                    icon: const LucideIcon(LucideGlyph.messageCircle, size: 18),
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
                        Align(
                            alignment: Alignment.centerLeft,
                            child: _revealQuantity(selector,
                                inCart: line != null)),
                        action,
                      ]);
                }
                return Row(children: [
                  _revealQuantity(selector,
                      inCart: line != null, horizontal: true),
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
