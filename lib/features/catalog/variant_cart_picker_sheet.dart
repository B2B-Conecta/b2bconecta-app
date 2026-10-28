import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/features/cart/cart_product_actions.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'catalog_service.dart';
import 'part_model.dart';
import 'product_variants.dart';

/// Resultado al confirmar el modal de variantes.
class VariantCartPickerResult {
  const VariantCartPickerResult({
    required this.addedLines,
    required this.totalUnits,
  });

  final int addedLines;
  final int totalUnits;
}

/// Abre el selector de cantidades por variante (uno o varios ejes).
///
/// El MOQ se valida sobre el **acumulado** de la familia, no por cada SKU.
Future<VariantCartPickerResult?> showVariantCartPickerSheet({
  required BuildContext context,
  required PartModel part,
  required ProfileModel profile,
  CartService? cart,
}) {
  return showModalBottomSheet<VariantCartPickerResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => VariantCartPickerSheet(
      part: part,
      profile: profile,
      cart: cart ?? CartService.instance,
    ),
  );
}

class VariantCartPickerSheet extends StatefulWidget {
  const VariantCartPickerSheet({
    super.key,
    required this.part,
    required this.profile,
    required this.cart,
  });

  final PartModel part;
  final ProfileModel profile;
  final CartService cart;

  @override
  State<VariantCartPickerSheet> createState() => _VariantCartPickerSheetState();
}

class _VariantCartPickerSheetState extends State<VariantCartPickerSheet> {
  late List<PartModel> _options = sortVariantOptions(
    widget.part.variantChoices.isNotEmpty
        ? widget.part.variantChoices
        : [widget.part],
  );
  late final Map<String, int> _quantities = {
    for (final option in _options)
      option.id: CartProductActions.lineFor(option, widget.cart)?.quantity ?? 0,
  };
  bool _loadingFamily = false;
  String? _bannerError;

  @override
  void initState() {
    super.initState();
    _ensureFamily();
  }

  Future<void> _ensureFamily() async {
    if (!widget.part.hasVariantFamily || _options.length > 1) return;
    setState(() => _loadingFamily = true);
    try {
      final family = await CatalogService.fetchVariantFamily(widget.part);
      if (!mounted || family.length < 2) return;
      setState(() {
        _options = sortVariantOptions(family);
        for (final option in _options) {
          _quantities.putIfAbsent(
            option.id,
            () =>
                CartProductActions.lineFor(option, widget.cart)?.quantity ?? 0,
          );
        }
      });
    } catch (_) {
      // Se queda con las opciones de la tarjeta.
    } finally {
      if (mounted) setState(() => _loadingFamily = false);
    }
  }

  /// MOQ del producto maestro / familia (máximo entre opciones y la ficha abierta).
  int get _familyMoq {
    var moq = widget.part.minOrderQtyEffective;
    for (final option in _options) {
      final candidate = option.minOrderQtyEffective;
      if (candidate > moq) moq = candidate;
    }
    return moq;
  }

  int get _selectedCount =>
      _quantities.values.where((quantity) => quantity > 0).length;

  int get _selectedUnits => _quantities.values
      .where((quantity) => quantity > 0)
      .fold<int>(0, (sum, quantity) => sum + quantity);

  bool get _meetsFamilyMoq => _selectedUnits >= _familyMoq;

  String? _rowIssue(PartModel option, int quantity) {
    if (quantity <= 0) return null;
    final blocked = CartProductActions.blockReasonForFamilyLine(
      part: option,
      profile: widget.profile,
      cart: widget.cart,
    );
    if (blocked != null) return blocked;
    if (quantity > option.stockForSale) {
      return 'Solo hay ${option.stockForSale} uds disponibles.';
    }
    return null;
  }

  bool get _canConfirm {
    if (_selectedCount == 0 || !_meetsFamilyMoq) return false;
    for (final option in _options) {
      final quantity = _quantities[option.id] ?? 0;
      if (quantity <= 0) continue;
      if (_rowIssue(option, quantity) != null) return false;
    }
    return true;
  }

  void _setQuantity(PartModel option, int raw) {
    final max = option.stockForSale;
    var next = raw;
    if (next < 0) next = 0;
    if (max < 1) {
      next = 0;
    } else if (next > max) {
      next = max;
    }
    setState(() {
      _quantities[option.id] = next;
      _bannerError = null;
    });
  }

  void _confirm() {
    if (!_canConfirm) {
      setState(() {
        if (_selectedCount == 0) {
          _bannerError = 'Elige al menos una opción con cantidad mayor a 0.';
        } else if (!_meetsFamilyMoq) {
          _bannerError =
              'Mínimo $_familyMoq uds en total entre todas las opciones '
              '(vas $_selectedUnits).';
        } else {
          _bannerError = 'Revisa cantidades y stock de cada opción.';
        }
      });
      return;
    }

    var lines = 0;
    var units = 0;
    for (final option in _options) {
      final quantity = _quantities[option.id] ?? 0;
      if (quantity <= 0) {
        // Si había línea en carrito y el aliado bajó a 0, quítala.
        if (CartProductActions.lineFor(option, widget.cart) != null) {
          CartProductActions.upsertQuantity(
            part: option,
            profile: widget.profile,
            cart: widget.cart,
            quantity: 0,
            enforceLineMinOrder: false,
          );
        }
        continue;
      }
      final applied = CartProductActions.upsertQuantity(
        part: option,
        profile: widget.profile,
        cart: widget.cart,
        quantity: quantity,
        enforceLineMinOrder: false,
      );
      if (applied > 0) {
        lines += 1;
        units += applied;
      }
    }

    if (lines == 0) {
      setState(() {
        _bannerError = 'No se pudo agregar ninguna opción al carrito.';
      });
      return;
    }

    Navigator.of(context).pop(
      VariantCartPickerResult(addedLines: lines, totalUnits: units),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    final familyMoq = _familyMoq;
    final units = _selectedUnits;
    final progress =
        familyMoq <= 0 ? 1.0 : (units / familyMoq).clamp(0.0, 1.0);
    final meetsMoq = _meetsFamilyMoq;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.part.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Combina cantidades entre opciones. El mínimo es '
                    '$familyMoq uds en total (no por cada variante).',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  if (_loadingFamily) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                  if (_bannerError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _bannerError!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final option = _options[index];
                  final quantity = _quantities[option.id] ?? 0;
                  return _VariantQuantityRow(
                    option: option,
                    quantity: quantity,
                    issue: _rowIssue(option, quantity),
                    onChanged: (value) => _setQuantity(option, value),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          units == 0
                              ? 'Seleccionadas: 0/$familyMoq unidades'
                              : 'Seleccionadas: $units/$familyMoq unidades'
                                  '${_selectedCount > 0 ? ' · $_selectedCount opción(es)' : ''}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: meetsMoq
                                ? AppColors.brandBlue
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (meetsMoq)
                        const Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: AppColors.brandBlue,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.borderSubtle,
                      color: meetsMoq
                          ? AppColors.brandBlue
                          : AppColors.warningAmber,
                    ),
                  ),
                  if (!meetsMoq && units > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Faltan ${familyMoq - units} uds para el mínimo del producto.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          key: const Key('variant-cart-confirm'),
                          // Siempre tappable: si no cumple MOQ global, _confirm
                          // muestra el mensaje guía y no muta el carrito.
                          onPressed: _confirm,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            backgroundColor: _canConfirm
                                ? null
                                : AppColors.brandBlue.withOpacity(0.45),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add_shopping_cart_outlined),
                          label: const Text('Agregar al carrito'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantQuantityRow extends StatelessWidget {
  const _VariantQuantityRow({
    required this.option,
    required this.quantity,
    required this.onChanged,
    this.issue,
  });

  final PartModel option;
  final int quantity;
  final ValueChanged<int> onChanged;
  final String? issue;

  @override
  Widget build(BuildContext context) {
    final stock = option.stockForSale;
    final available = stock >= 1 && option.isActive;
    final unit = option.precioUnitarioParaAliado(
      quantity: quantity > 0 ? quantity : 1,
    );
    final attrs = variantAttributesOf(option);
    final subtitle = attrs.isEmpty
        ? option.variantOptionLabel
        : attrs.entries.map((e) => '${e.key}: ${e.value}').join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _VariantThumb(url: option.coverImageUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        available
                            ? 'REF ${unit.toStringAsFixed(2)} · Stock $stock'
                            : !option.isActive
                                ? 'Pausado por el proveedor'
                                : 'Sin stock disponible',
                        style: TextStyle(
                          fontSize: 12,
                          color: available
                              ? AppColors.textSecondary
                              : Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _QuantityStepper(
                  quantity: quantity,
                  enabled: available,
                  canDecrease: quantity > 0,
                  canIncrease: available && quantity < stock,
                  onDecrease: () => onChanged(quantity - 1),
                  onIncrease: () => onChanged(quantity + 1),
                ),
              ],
            ),
            if (issue != null) ...[
              const SizedBox(height: 8),
              Text(
                issue!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VariantThumb extends StatelessWidget {
  const _VariantThumb({this.url});

  final String? url;

  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    final trimmed = url?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: trimmed != null && trimmed.isNotEmpty
            ? Image.network(
                trimmed,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.fieldFill,
      child: Icon(
        Icons.image_outlined,
        size: 22,
        color: Colors.grey.shade500,
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.enabled,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final bool enabled;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Reducir',
            onPressed: enabled && canDecrease ? onDecrease : null,
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Aumentar',
            onPressed: enabled && canIncrease ? onIncrease : null,
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}
