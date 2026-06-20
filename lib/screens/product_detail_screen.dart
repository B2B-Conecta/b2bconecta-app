import 'package:flutter/material.dart';

import '../models/part_model.dart';
import '../models/profile_model.dart';
import '../services/cart_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_breakpoints.dart';
import '../utils/product_catalog_pricing.dart';
import '../widgets/catalog_product_price_display.dart';
import '../widgets/product_warranty_seal.dart';

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

  String get _importerLine => (part.ownerBusinessName ?? '').trim().toUpperCase();

  String? _ownerLocationLine() {
    final e = part.ownerEstado?.trim();
    final c = part.ownerCiudad?.trim();
    if ((e == null || e.isEmpty) && (c == null || c.isEmpty)) return null;
    if (e != null && e.isNotEmpty && c != null && c.isNotEmpty) {
      return '$e · $c';
    }
    return e?.isNotEmpty == true ? e : c;
  }

  bool get _cartActionsDisabled =>
      part.stock < 1 || _pedidosSuspendidosMorosidad;

  String? _cartBlockReason() {
    final ownerId = part.ownerId?.trim();
    if (ownerId == null || ownerId.isEmpty) {
      return 'No se pudo identificar al importador.';
    }
    if (_pedidosSuspendidosMorosidad) {
      return 'MotoLink suspendió nuevos pedidos en su cuenta por morosidad.';
    }
    if (part.stock < 1) return 'Sin stock disponible.';
    return null;
  }

  void _showCartBlock(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _addToCart() async {
    final block = _cartBlockReason();
    if (block != null) {
      _showCartBlock(block);
      return;
    }

    final maxQty = part.stock;
    var q = 1;

    final qtyCtrl = TextEditingController(text: '1');
    bool? ok;
    var qtyRaw = '1';
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Agregar al carrito'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Indique cuántas unidades desea añadir (disponibles: $maxQty).',
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
                child: const Text('Agregar'),
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

    q = requested;
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

    _putInCart(quantity: q);
    if (!mounted) return;

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

  void _putInCart({required int quantity}) {
    CartService.instance.addOrIncrement(
      part,
      precioUnitarioAliadoRef: _precioVentaUnit(quantity: quantity),
      delta: quantity,
    );
    CartService.instance.setQuantity(part.id, quantity);
  }

  Future<void> _solicitarItemViaCarrito() async {
    final block = _cartBlockReason();
    if (block != null) {
      _showCartBlock(block);
      return;
    }

    _putInCart(quantity: 1);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('1 unidad añadida al carrito.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.b2bDesktop;
    if (isDesktop) return _buildDesktopLayout(context);
    return _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeroImage(context)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ..._buildInfoSections(),
                      SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 100,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomActionBar(context, horizontal: false),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceTinted,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Detalle del producto'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.productDetailMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _buildDesktopImageCard(),
                ),
                const SizedBox(width: 32),
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._buildInfoSections(desktop: true),
                        const SizedBox(height: 20),
                        _buildActionAlerts(),
                        const SizedBox(height: 16),
                        _buildActionButtons(horizontal: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Material(
            color: Colors.white,
            child: _buildHeroImageContent(),
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
    );
  }

  Widget _buildDesktopImageCard() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: AppDecorations.cardShadow,
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: _buildHeroImageContent(),
        ),
      ),
    );
  }

  Widget _buildHeroImageContent() {
    return Hero(
      tag: ProductDetailScreen.heroImageTag(part),
      child: part.imagenUrl != null && part.imagenUrl!.isNotEmpty
          ? Image.network(
              part.imagenUrl!,
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (_, __, ___) => _imagePlaceholder(),
            )
          : _imagePlaceholder(),
    );
  }

  List<Widget> _buildInfoSections({bool desktop = false}) {
    final location = _ownerLocationLine();
    return [
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
      if (_importerLine.isNotEmpty) ...[
        Text(
          _importerLine,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
      ],
      if (location != null) ...[
        Row(
          children: [
            Icon(Icons.location_on_outlined,
                size: 15, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                location,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
      if (part.ownerRatingAvg != null && (part.ownerRatingCount ?? 0) > 0) ...[
        Row(
          children: [
            Icon(Icons.star, size: 16, color: Colors.amber.shade800),
            const SizedBox(width: 4),
            Text(
              '${part.ownerRatingAvg!.toStringAsFixed(1)} · '
              '${part.ownerRatingCount} valoraciones',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      Text(
        part.nombre,
        style: TextStyle(
          fontSize: desktop ? 28 : 22,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: AppColors.textPrimary,
          letterSpacing: desktop ? -0.3 : 0,
        ),
      ),
      SizedBox(height: desktop ? 16 : 8),
      Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: desktop ? Colors.white : AppColors.fieldFill.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
            border: desktop
                ? Border.all(color: Colors.grey.shade200)
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(desktop ? 16 : 0),
            child: CatalogProductPriceDisplay(
              listPriceUsd: part.precio,
              salePriceUsd: part.salePriceUsd,
              discountRules: part.discountRules,
              showPromotionChips: true,
              ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
            ),
          ),
        ),
      ),
      if (ProductCatalogPricing.volumeIncentiveBadgeEs(part.discountRules) !=
          null) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Text(
            ProductCatalogPricing.volumeIncentiveBadgeEs(part.discountRules)!,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Colors.teal.shade900,
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      _buildStockBadge(desktop: desktop),
      SizedBox(height: desktop ? 20 : 16),
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
      if ((part.descripcion ?? '').trim().isNotEmpty) const SizedBox(height: 12),
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
      if ((part.compatibilidad ?? '').trim().isNotEmpty) const SizedBox(height: 12),
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
      if (part.hasWarranty) ...[
        SizedBox(height: desktop ? 24 : 28),
        const Center(child: ProductWarrantySeal()),
      ],
    ];
  }

  Widget _buildStockBadge({bool desktop = false}) {
    final inStock = part.stock > 0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 14 : 0,
        vertical: desktop ? 10 : 0,
      ),
      decoration: desktop
          ? BoxDecoration(
              color: inStock ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: inStock ? Colors.green.shade200 : Colors.orange.shade200,
              ),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: inStock ? AppColors.successGreen : Colors.orange.shade700,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            inStock ? 'Stock: ${part.stock} uds' : 'Sin stock disponible',
            style: TextStyle(
              fontSize: desktop ? 15 : 14,
              fontWeight: FontWeight.w700,
              color: inStock ? Colors.green.shade800 : Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionAlerts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (part.stock < 1)
          _AlertBanner(
            text: 'Sin stock disponible',
            color: Colors.orange.shade900,
            background: Colors.orange.shade50,
            border: Colors.orange.shade200,
          ),
        if (_pedidosSuspendidosMorosidad)
          _AlertBanner(
            text:
                'Nuevos pedidos suspendidos por MotoLink (morosidad). Complete pagos en pedidos entregados.',
            color: Colors.red.shade900,
            background: Colors.red.shade50,
            border: Colors.red.shade200,
          ),
      ],
    );
  }

  Widget _buildActionButtons({required bool horizontal}) {
    if (horizontal) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _cartActionsDisabled ? null : _addToCart,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Agregar al carrito'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _cartActionsDisabled ? null : _solicitarItemViaCarrito,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Solicitar solo este ítem'),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: _cartActionsDisabled ? null : _addToCart,
          child: const Text('Agregar al carrito'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _cartActionsDisabled ? null : _solicitarItemViaCarrito,
          child: const Text('Solicitar solo este ítem'),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(BuildContext context, {required bool horizontal}) {
    return Container(
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
          _buildActionAlerts(),
          if (part.stock < 1 || _pedidosSuspendidosMorosidad)
            const SizedBox(height: 8),
          _buildActionButtons(horizontal: horizontal),
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

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.text,
    required this.color,
    required this.background,
    required this.border,
  });

  final String text;
  final Color color;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.3,
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
