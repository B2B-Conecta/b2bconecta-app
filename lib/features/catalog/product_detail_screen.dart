import 'package:flutter/material.dart';

import 'aliado_catalog_categories.dart';
import 'catalog_filters.dart';
import 'catalog_service.dart';
import 'favorite_heart_button.dart';
import 'part_model.dart';
import 'product_detail_extras.dart';
import 'related_products.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'product_catalog_pricing.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields.dart';
import 'catalog_product_price_display.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields_section.dart';
import 'product_warranty_seal.dart';
import 'importer_catalog_seals.dart';
import 'importer_store_profile_screen.dart';
import 'product_share_sheet.dart';
import 'store_supplier_chat.dart';

/// Ficha de producto (aliado): imagen, specs, solicitud de pedido vía broker.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.part,
    this.guestPreview = false,
    this.onRegisterToOrder,
    this.onOpenStore,
  });

  final PartModel part;

  /// Enlace abierto sin sesión: se ve la ficha y la vitrina, sin pedido.
  final bool guestPreview;

  final VoidCallback? onRegisterToOrder;
  final VoidCallback? onOpenStore;

  static String heroImageTag(PartModel p) => 'product-image-${p.id}';

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProfileModel? _profile;
  List<PartModel> _related = const [];
  final PageController _imagePageController = PageController();
  int _imagePageIndex = 0;

  PartModel get part => widget.part;

  List<String> get _galleryUrls {
    if (part.imageUrls.isNotEmpty) return part.imageUrls;
    final cover = part.coverImageUrl;
    if (cover != null && cover.isNotEmpty) return [cover];
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadRelated();
  }

  Future<void> _loadRelated() async {
    final category = part.category?.trim();
    final owner = part.ownerId?.trim();
    final CatalogFilters filters;
    if (category != null && category.isNotEmpty) {
      filters = CatalogFilters(category: category);
    } else if (owner != null && owner.isNotEmpty) {
      filters = CatalogFilters(ownerId: owner);
    } else {
      return;
    }
    try {
      final rows = await CatalogService.fetchParts(limit: 24, filters: filters);
      if (!mounted) return;
      setState(() {
        _related = pickRelatedProducts(current: part, candidates: rows);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (widget.guestPreview) return;
    try {
      final p = await SupabaseService.fetchMyProfile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
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

  bool get _canShareProduct {
    final viewer = _profile;
    if (viewer == null) return false;
    return viewer.isImportador || viewer.isAdministrador;
  }

  bool get _canOpenImporterStore {
    final owner = part.ownerId?.trim();
    if (owner == null || owner.isEmpty) return false;
    if (widget.onOpenStore != null) return true;
    final viewer = _profile;
    if (viewer == null) return false;
    return viewer.isAliado || viewer.isAdministrador;
  }

  bool get _canOrder {
    if (widget.guestPreview) return false;
    return _profile?.isAliado == true;
  }

  bool get _canAskAboutProduct {
    final owner = part.ownerId?.trim() ?? '';
    final viewer = _profile;
    if (viewer == null || owner.isEmpty || part.id.trim().isEmpty) {
      return false;
    }
    return showStoreSupplierChatButton(
      viewerRole: viewer.role,
      viewerId: viewer.id,
      importerId: owner,
    );
  }

  Future<void> _askAboutProduct() async {
    if (!_canAskAboutProduct) return;
    final owner = part.ownerId!.trim();
    try {
      final threadId = await StoreSupplierChatService.openOrCreate(
        importadorId: owner,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => StoreSupplierChatScreen(
            threadId: threadId,
            aboutProduct: StoreSupplierProductContext(
              id: part.id,
              name: part.nombre,
              sku: part.sku,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la pregunta: $e')),
      );
    }
  }

  void _openImporterStore() {
    if (widget.onOpenStore != null) {
      widget.onOpenStore!();
      return;
    }
    if (!_canOpenImporterStore) return;
    final owner = part.ownerId?.trim();
    if (owner == null || owner.isEmpty) return;
    final viewer = _profile;
    if (viewer == null) return;
    ImporterStoreProfileScreen.open(
      context,
      importerId: owner,
      viewer: viewer,
    );
  }

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
      !part.isActive ||
      !part.stockCoversMinOrder ||
      _pedidosSuspendidosMorosidad;

  String? _cartBlockReason() {
    final ownerId = part.ownerId?.trim();
    if (ownerId == null || ownerId.isEmpty) {
      return 'No se pudo identificar al importador.';
    }
    if (_pedidosSuspendidosMorosidad) {
      return 'B2B Conecta suspendió nuevos pedidos en su cuenta por morosidad.';
    }
    if (!part.isActive) return 'Este producto está pausado por el proveedor.';
    if (part.stock < 1) return 'Sin stock disponible.';
    if (!part.stockCoversMinOrder) {
      return 'Stock insuficiente para el mínimo de pedido (${part.minOrderQtyLabelEs}).';
    }
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

  void _addToCart() {
    final block = _cartBlockReason();
    if (block != null) {
      _showCartBlock(block);
      return;
    }

    final minQty = part.minOrderQtyEffective;
    final alreadyInCart =
        CartService.instance.lines.any((line) => line.part.id == part.id);
    if (!alreadyInCart) {
      CartService.instance.addOrIncrement(
        part,
        precioUnitarioAliadoRef: _precioVentaUnit(quantity: minQty),
        delta: minQty,
      );
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          alreadyInCart
              ? 'Ya está en el carrito. Ajusta la cantidad allí.'
              : '$minQty unidades añadidas al carrito.',
        ),
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
      backgroundColor: AppColors.background,
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
                      _buildCommerceExtras(),
                      SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 100,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          if (_showsOrderBar) _buildBottomActionBar(context),
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
        leadingWidth: 112,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 24),
          label: const Text(
            'Atrás',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        title: const Text('Detalle del producto'),
        actions: [
          if (_canShareProduct)
            IconButton(
              tooltip: 'Compartir producto',
              onPressed: () => showProductShareSheet(context, part),
              icon: const Icon(Icons.ios_share_rounded),
            ),
        ],
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
                        _buildActionButtons(),
                        const SizedBox(height: 20),
                        _buildCommerceExtras(),
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
            color: AppColors.surfaceTinted,
            child: _buildHeroImageContent(),
          ),
        ),
        if (_profile?.isAliado == true)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 12,
            child: FavoriteHeartButton(
              productId: part.id,
              prominent: true,
            ),
          ),
        if (_canShareProduct)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 12,
            child: _ProductBackButton(
              label: 'Compartir',
              icon: Icons.ios_share_rounded,
              onPressed: () => showProductShareSheet(context, part),
            ),
          ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 10,
          right: 12,
          child: _ProductBackButton(
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopImageCard() {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
          boxShadow: AppDecorations.cardShadow,
        ),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _buildHeroImageContent(),
            ),
            if (_profile?.isAliado == true)
              Positioned(
                top: 12,
                right: 12,
                child: FavoriteHeartButton(
                  productId: part.id,
                  prominent: true,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImageContent() {
    final urls = _galleryUrls;
    if (urls.isEmpty) {
      return _imagePlaceholder();
    }

    if (urls.length == 1) {
      return Hero(
        tag: ProductDetailScreen.heroImageTag(part),
        child: Image.network(
          urls.first,
          fit: BoxFit.contain,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _imagePlaceholderInner(),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _imagePageController,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _imagePageIndex = i),
            itemBuilder: (context, index) {
              return Image.network(
                urls[index],
                fit: BoxFit.contain,
                width: double.infinity,
                errorBuilder: (_, __, ___) => _imagePlaceholderInner(),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(urls.length, (i) {
              final active = i == _imagePageIndex;
              return Container(
                width: active ? 8 : 6,
                height: active ? 8 : 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.brand
                      : Colors.grey.shade400,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildInfoSections({bool desktop = false}) {
    final location = _ownerLocationLine();
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'SKU: $_skuDisplay',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      if ((part.category ?? '').trim().isNotEmpty) ...[
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Categoría: ${formatCatalogCategoryLabel(part.category!)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.brandBlue,
            ),
          ),
        ),
      ],
      const SizedBox(height: 8),
      if (_importerLine.isNotEmpty) ...[
        InkWell(
            onTap: _canOpenImporterStore ? _openImporterStore : null,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              _importerLine,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: _canOpenImporterStore
                    ? AppColors.brandBlue
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        if (part.isCatalogVerified || part.isCatalogFeatured) ...[
          const SizedBox(height: 6),
          ImporterCatalogSealsRow(
            verified: part.isCatalogVerified,
            featured: part.isCatalogFeatured,
          ),
        ],
        const SizedBox(height: 4),
      ],
      if (location != null) ...[
        Row(
          children: [
            Icon(Icons.location_on_outlined,
                size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                location,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
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
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      if (_canShareProduct) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => showProductShareSheet(context, part),
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('Compartir producto'),
          ),
        ),
        if (_profile?.isAdministrador == true) ...[
          const SizedBox(height: 8),
          Text(
            'Solo lectura. Comparte el enlace para que el proveedor promocione este producto.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 12),
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: CatalogProductPriceDisplay(
              listPriceUsd: part.precio,
              salePriceUsd: part.salePriceUsd,
              discountRules: part.discountRules,
              campaignDiscountPercent: part.activeCampaignDiscountPercent,
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
            color: AppColors.brandBlueContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Text(
            ProductCatalogPricing.volumeIncentiveBadgeEs(part.discountRules)!,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      _buildStockBadge(desktop: desktop),
      if (part.hasOwnerMinOrderAmount) ...[
        const SizedBox(height: 8),
        Text(
          '${part.ownerMinOrderAmountLabelEs} por despacho.',
          style: TextStyle(
            fontSize: desktop ? 13 : 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
      SizedBox(height: desktop ? 20 : 16),
      if ((part.descripcion ?? '').trim().isNotEmpty)
        _SpecBlock(
          label: 'Descripción',
          child: Text(
            part.descripcion!.trim(),
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textPrimary,
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
              color: AppColors.textPrimary,
            ),
          ),
        ),
      if ((part.compatibilidad ?? '').trim().isNotEmpty) const SizedBox(height: 12),
      ProductCustomFieldsAliadoSpecs(customFields: part.customFields),
      if (productCustomFieldsDisplayEntries(
        part.customFields,
        aliadoView: true,
      ).isNotEmpty)
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
            color: AppColors.textPrimary,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Puedes copiar el ID para soporte o seguimiento interno.',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
      if (part.hasWarranty) ...[
        SizedBox(height: desktop ? 24 : 28),
        const Center(child: ProductWarrantySeal()),
      ],
    ];
  }

  Widget _buildCommerceExtras() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        SupplierRatingBlock(
          part: part,
          onOpenStore: _canOpenImporterStore ? _openImporterStore : null,
        ),
        if (_related.isNotEmpty) ...[
          const SizedBox(height: 20),
          RelatedProductsSection(
            current: part,
            products: _related,
            profile: _profile,
          ),
        ],
      ],
    );
  }

  Widget _buildStockBadge({bool desktop = false}) {
    final inStock = part.stockCoversMinOrder;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 14 : 0,
        vertical: desktop ? 10 : 0,
      ),
      decoration: desktop
          ? BoxDecoration(
              color: inStock ? Colors.green.shade50 : AppColors.brandBlueContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: inStock ? Colors.green.shade200 : AppColors.brandAccent.withOpacity(0.35),
              ),
            )
          : null,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: inStock ? AppColors.successGreen : AppColors.brandAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            inStock
                ? 'Stock: ${part.stock} uds · ${part.minOrderQtyLabelEs}'
                : part.stock < 1
                    ? 'Sin stock disponible'
                    : 'Stock ${part.stock} uds · ${part.minOrderQtyLabelEs}',
            style: TextStyle(
              fontSize: desktop ? 15 : 14,
              fontWeight: FontWeight.w700,
              color: inStock ? Colors.green.shade800 : AppColors.brandBlue,
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
            color: AppColors.brandBlue,
            background: AppColors.brandBlueContainer,
            border: AppColors.brandAccent.withOpacity(0.35),
          )
        else if (!part.stockCoversMinOrder)
          _AlertBanner(
            text:
                'Stock insuficiente para el mínimo de pedido (${part.minOrderQtyLabelEs}).',
            color: AppColors.brandBlue,
            background: AppColors.brandBlueContainer,
            border: AppColors.brandAccent.withOpacity(0.35),
          ),
        if (_pedidosSuspendidosMorosidad)
          _AlertBanner(
            text:
                'Nuevos pedidos suspendidos por B2B Conecta (morosidad). Complete pagos en pedidos entregados.',
            color: Colors.red.shade900,
            background: Colors.red.shade50,
            border: Colors.red.shade200,
          ),
      ],
    );
  }

  bool get _showsOrderBar => widget.guestPreview || _profile == null || _canOrder;

  Widget _buildActionButtons() {
    if (widget.guestPreview) {
      return FilledButton(
        onPressed: widget.onRegisterToOrder,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text('Regístrate para pedir'),
      );
    }
    if (_profile == null) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!_canOrder) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_canAskAboutProduct) ...[
          OutlinedButton.icon(
            key: const Key('ask-about-product'),
            onPressed: _askAboutProduct,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Preguntar sobre este producto'),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: _cartActionsDisabled ? null : _addToCart,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Agregar al carrito'),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.12),
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
          if (!part.stockCoversMinOrder || _pedidosSuspendidosMorosidad)
            const SizedBox(height: 8),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Hero(
      tag: ProductDetailScreen.heroImageTag(part),
      child: _imagePlaceholderInner(),
    );
  }

  Widget _imagePlaceholderInner() {
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
        color: AppColors.card,
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: AppColors.borderSubtle),
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
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ProductBackButton extends StatelessWidget {
  const _ProductBackButton({
    required this.onPressed,
    this.label = 'Atrás',
    this.icon = Icons.arrow_back_rounded,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card.withOpacity(0.94),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
