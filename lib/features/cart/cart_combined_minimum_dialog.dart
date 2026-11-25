import 'package:flutter/material.dart';

import '../../app/theme/b2b_theme_extension.dart';
import '../catalog/catalog_cart_price.dart';
import '../catalog/catalog_service.dart';
import '../catalog/part_model.dart';
import '../profile/profile_model.dart';
import 'cart_combined_minimum.dart';
import 'cart_product_actions.dart';
import 'cart_service.dart';

class CartCombinedMinimumProgress extends StatelessWidget {
  const CartCombinedMinimumProgress({
    super.key,
    required this.group,
    this.onBrowse,
  });

  final CartCombinedMinimum group;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceCard,
        border: Border.all(color: theme.borderSubtle),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.rule.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              group.meets
                  ? '${group.units} de ${group.rule.units} uds · Mínimo cubierto'
                  : '${group.units} de ${group.rule.units} uds · '
                      '${group.missing == 1 ? 'Falta 1 unidad' : 'Faltan ${group.missing} unidades'}',
              style: TextStyle(fontSize: 12, color: theme.textSecondary),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (group.units / group.rule.units).clamp(0.0, 1.0),
              semanticsLabel: 'Mínimo combinado de ${group.rule.name}',
            ),
            if (onBrowse != null)
              TextButton(
                onPressed: onBrowse,
                child: const Text('Ver referencias elegibles'),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class CartCombinedMinimumDialog extends StatefulWidget {
  const CartCombinedMinimumDialog({
    super.key,
    required this.group,
    required this.profile,
    required this.cart,
    this.bcvRate,
  });

  final CartCombinedMinimum group;
  final ProfileModel profile;
  final CartService cart;
  final double? bcvRate;

  @override
  State<CartCombinedMinimumDialog> createState() =>
      _CartCombinedMinimumDialogState();
}

class _CartCombinedMinimumDialogState extends State<CartCombinedMinimumDialog> {
  static const _pageSize = 30;
  final _parts = <PartModel>[];
  bool _hasMore = true;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final parts = await CatalogService.fetchCombinedMinimumProducts(
        ownerId: widget.group.ownerId,
        groupId: widget.group.rule.id,
        offset: _parts.length,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _parts.addAll(parts);
        _hasMore = parts.length == _pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Referencias elegibles'),
        content: SizedBox(
          width: 460,
          height: (MediaQuery.sizeOf(context).height * .62).clamp(180.0, 480.0),
          child: ListenableBuilder(
            listenable: widget.cart,
            builder: (context, _) {
              final progress = CartCombinedMinimum.forLines(widget.cart.lines)
                  .where((g) =>
                      g.ownerId == widget.group.ownerId &&
                      g.rule.id == widget.group.rule.id)
                  .firstOrNull;
              return ListView(
                children: [
                  CartCombinedMinimumProgress(group: progress ?? widget.group),
                  for (final part in _parts) _reference(part),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_failed)
                    TextButton(
                      onPressed: _load,
                      child: const Text('Reintentar cargar referencias'),
                    )
                  else if (_parts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child:
                          Text('Este grupo no tiene referencias disponibles.'),
                    )
                  else if (_hasMore)
                    TextButton(
                      onPressed: _load,
                      child: const Text('Cargar más referencias'),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver a la bolsa'),
          ),
        ],
      );

  Widget _reference(PartModel part) {
    final line = CartProductActions.lineFor(part, widget.cart);
    final quantity = line?.quantity ?? 0;
    final enabled = quantity < part.stockForSale &&
        CartProductActions.blockReason(
                part: part, profile: widget.profile, cart: widget.cart) ==
            null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(part.nombre),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (part.sku?.isNotEmpty == true) Text(part.sku!),
          CatalogCartPrice(
              part: part, cart: widget.cart, bcvRate: widget.bcvRate),
          if (quantity > 0) Text('$quantity en tu bolsa'),
        ],
      ),
      trailing: IconButton.filledTonal(
        tooltip: 'Agregar 1 unidad de ${part.nombre}',
        onPressed: enabled
            ? () {
                if (line == null) {
                  CartProductActions.addMinimum(
                      part: part, profile: widget.profile, cart: widget.cart);
                } else {
                  CartProductActions.setQuantity(
                      part: part,
                      profile: widget.profile,
                      cart: widget.cart,
                      quantity: quantity + 1);
                }
              }
            : null,
        icon: const Icon(Icons.add),
      ),
    );
  }
}
