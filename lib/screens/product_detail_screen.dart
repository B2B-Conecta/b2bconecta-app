import 'package:flutter/material.dart';

import '../models/part_model.dart';
import '../models/profile_model.dart';
import '../services/cart_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/product_catalog_pricing.dart';
import '../widgets/catalog_product_price_display.dart';
import 'cart_screen.dart';

/// Ficha de producto (aliado): imagen, specs, solicitud de pedido vía broker.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.part});

  final PartModel part;

  static String heroImageTag(PartModel p) => 'product-image-${p.id}';

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProfileModel? _profile;

  PartModel get part => widget.part;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await SupabaseService.fetchMyProfile();
    if (mounted) setState(() => _profile = p);
  }

  bool get _pedidosSuspendidosMorosidad =>
      _profile?.pedidosSuspendidosMorosidad ?? false;

  double _precioVentaUnit({int quantity = 1}) =>
      part.precioUnitarioParaAliado(quantity: quantity);

  String get _skuDisplay {
    final sku = part.sku?.trim();
    if (sku != null && sku.isNotEmpty) return sku;
    final id = part.id;
    if (id.length <= 14) return id;
    return id.substring(0, 12);
  }

  Future<void> _openCartScreen() async {
    var profile = _profile;
    if (profile == null) {
      profile = await SupabaseService.fetchMyProfile();
      if (mounted) setState(() => _profile = profile);
    }
    if (!mounted) return;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete su perfil para confirmar el pedido.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CartScreen(profile: profile!, liveTasaBcv: null),
      ),
    );
  }

  Future<void> _addToCart({bool navigateToCartAfter = false}) async {
    final ownerId = part.ownerId?.trim();
    if (ownerId == null || ownerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar al importador.')),
      );
      return;
    }
    if (_pedidosSuspendidosMorosidad) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'MotoLink suspendió nuevos pedidos en su cuenta por morosidad.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (part.stock < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin stock disponible.')),
      );
      return;
    }

    final maxQty = part.stock;
    final qtyCtrl = TextEditingController(text: '1');
    bool? ok;
    var qtyRaw = '1';
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(
              navigateToCartAfter
                  ? 'Solicitar este ítem'
                  : 'Agregar al carrito',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    navigateToCartAfter
                        ? 'Indique la cantidad; luego revisará el carrito antes de confirmar el pedido (disponibles: $maxQty).'
                        : 'Indique cuántas unidades desea añadir (disponibles: $maxQty).',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Cantidad',
                      hintText: '1',
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: AppDecorations.radius12,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(navigateToCartAfter ? 'Ir al carrito' : 'Agregar'),
              ),
            ],
          );
        },
      );
      qtyRaw = qtyCtrl.text.trim();
    } finally {
      qtyCtrl.dispose();
    }

    if (ok != true || !mounted) return;

    var requested = int.tryParse(qtyRaw) ?? 1;
    if (requested < 1) requested = 1;

    var q = requested;
    if (requested > maxQty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stock limitado'),
          content: Text(
            'Actualmente hay $maxQty unidad(es) disponible(s). '
            'Indicó $requested. ¿Desea agregar $maxQty al carrito?',
            style: const TextStyle(height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Agregar $maxQty'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      q = maxQty;
    }

    CartService.instance.addOrIncrement(
      part,
      precioUnitarioAliadoRef: _precioVentaUnit(quantity: q),
      delta: q,
    );
    if (!mounted) return;

    if (navigateToCartAfter) {
      await _openCartScreen();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          q == 1
              ? '1 unidad añadida al carrito.'
              : '$q unidades añadidas al carrito.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _solicitarItemViaCarrito() => _addToCart(navigateToCartAfter: true);

  @override
  Widget build(BuildContext context) {
    final importer = (part.ownerBusinessName ?? '').trim().toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Material(
                          color: Colors.white,
                          child: Hero(
                            tag: ProductDetailScreen.heroImageTag(part),
                            child: part.imagenUrl != null &&
                                    part.imagenUrl!.isNotEmpty
                                ? Image.network(
                                    part.imagenUrl!,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    errorBuilder: (_, __, ___) =>
                                        _imagePlaceholder(),
                                  )
                                : _imagePlaceholder(),
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 4,
                        right: 8,
                        child: Material(
                          color: Colors.white.withOpacity(0.92),
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.close),
                            color: AppColors.textPrimary,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'SKU: $_skuDisplay',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (importer.isNotEmpty)
                        Text(
                          importer,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (importer.isNotEmpty) const SizedBox(height: 6),
                      Text(
                        part.nombre,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CatalogProductPriceDisplay(
                        listPriceUsd: part.precio,
                        salePriceUsd: part.salePriceUsd,
                        discountRules: part.discountRules,
                        showPromotionChips: false,
                        ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
                      ),
                      if (ProductCatalogPricing.volumeIncentiveBadgeEs(
                            part.discountRules,
                          ) !=
                          null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Text(
                            ProductCatalogPricing.volumeIncentiveBadgeEs(
                              part.discountRules,
                            )!,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade900,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E7D32),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Stock: ${part.stock} uds',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if ((part.descripcion ?? '').trim().isNotEmpty)
                        _SpecBlock(
                          label: 'Descripción',
                          child: Text(
                            part.descripcion!.trim(),
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      if ((part.descripcion ?? '').trim().isNotEmpty)
                        const SizedBox(height: 12),
                      if ((part.compatibilidad ?? '').trim().isNotEmpty)
                        _SpecBlock(
                          label: 'Compatibilidad',
                          child: Text(
                            part.compatibilidad!.trim(),
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      if ((part.compatibilidad ?? '').trim().isNotEmpty)
                        const SizedBox(height: 12),
                      _SpecBlock(
                        label: 'Referencia interna (ID)',
                        child: SelectableText(
                          part.id,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Puedes copiar el ID para soporte o seguimiento interno.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ServicePill(
                            icon: Icons.inventory_2_outlined,
                            label: 'Envío B2B',
                          ),
                          _ServicePill(
                            icon: Icons.local_shipping_outlined,
                            label: 'Despacho 24h',
                          ),
                          _ServicePill(
                            icon: Icons.verified_user_outlined,
                            label: 'Garantía',
                          ),
                        ],
                      ),
                      SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 100,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.paddingOf(context).bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (part.stock < 1) ...[
                  Text(
                    'Sin stock disponible',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_pedidosSuspendidosMorosidad) ...[
                  Text(
                    'Nuevos pedidos suspendidos por MotoLink (morosidad). Complete pagos en pedidos entregados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade900,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton(
                  onPressed: (part.stock < 1 || _pedidosSuspendidosMorosidad)
                      ? null
                      : _addToCart,
                  child: const Text('Agregar al carrito'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: (part.stock < 1 || _pedidosSuspendidosMorosidad)
                      ? null
                      : _solicitarItemViaCarrito,
                  child: const Text('Solicitar solo este ítem'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return ColoredBox(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(
          Icons.precision_manufacturing_outlined,
          size: 72,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

class _SpecBlock extends StatelessWidget {
  const _SpecBlock({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: AppDecorations.radius12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ServicePill extends StatelessWidget {
  const _ServicePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 26, color: AppColors.textSecondary),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
