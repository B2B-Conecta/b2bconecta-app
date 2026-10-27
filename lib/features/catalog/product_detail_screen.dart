import 'package:flutter/material.dart';

import 'catalog_filters.dart';
import 'catalog_service.dart';
import 'favorite_heart_button.dart';
import 'part_model.dart';
import 'product_detail_extras.dart';
import 'related_products.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'package:motolink_pro_app/features/cart/cart_screen.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'product_detail_commerce.dart';
import 'product_detail_purchase_controls.dart';
import 'product_detail_information.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica.dart';
import 'package:motolink_pro_app/features/logistics/envio_politica_badge.dart';
import 'product_warranty_seal.dart';
import 'importer_catalog_seals.dart';
import 'importer_store_profile_screen.dart';
import 'product_share_sheet.dart';
import 'store_supplier_chat.dart';
import 'product_photo_gallery.dart';
import 'package:motolink_pro_app/features/inventory/product_images.dart';

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

  PartModel get part => widget.part;

  List<String> get _galleryUrls =>
      parseProductImageUrlsJson(part.imageUrls, legacyImageUrl: part.imagenUrl);

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

  Future<void> _loadProfile() async {
    if (widget.guestPreview) return;
    try {
      final p = await SupabaseService.fetchMyProfile();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  bool get _pedidosSuspendidosMorosidad =>
      _profile?.pedidosSuspendidosMorosidad ?? false;

  bool get _canShareProduct {
    final viewer = _profile;
    if (viewer == null) return false;
    return viewer.isImportador || viewer.isAdministrador;
  }

  void _shareProduct() {
    showProductShareSheet(
      context,
      part,
      includeDevLink: _profile?.isAdministrador == true,
    );
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

  void _openCart() {
    final profile = _profile;
    if (profile == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CartScreen(profile: profile),
    ));
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
            tooltip: 'Atrás',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded)),
        title:
            const Text('Detalle del repuesto', style: TextStyle(fontSize: 16)),
        actions: [
          if (_profile?.isAliado == true)
            FavoriteHeartButton(productId: part.id),
          if (_canShareProduct)
            IconButton(
                tooltip: 'Compartir producto',
                onPressed: _shareProduct,
                icon: const Icon(Icons.ios_share_rounded)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeroImage(context)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ..._buildInfoSections(),
                      _buildCommerceExtras(),
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
              onPressed: _shareProduct,
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
    final size = MediaQuery.sizeOf(context);
    final height = _galleryUrls.isEmpty
        ? (128 * MediaQuery.textScalerOf(context).scale(14) / 14)
            .clamp(128.0, 220.0)
        : size.width > size.height
            ? (size.height * 0.5).clamp(140.0, 220.0)
            : (size.height * 0.30).clamp(220.0, 300.0);
    return SizedBox(
        height: height,
        child:
            Material(color: AppColors.white, child: _buildHeroImageContent()));
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

  Widget _buildHeroImageContent() => ProductPhotoGallery(
      urls: _galleryUrls,
      productName: part.nombre,
      heroTag: ProductDetailScreen.heroImageTag(part));

  List<Widget> _buildInfoSections({bool desktop = false}) => [
        ProductDetailHeading(part: part, desktop: desktop),
        const SizedBox(height: 12),
        ProductDetailPurchaseSummary(part: part),
        if (part.hasOwnerMinOrderAmount) ...[
          const SizedBox(height: 8),
          Text('${part.ownerMinOrderAmountLabelEs} por despacho.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
        if (EnvioPolitica.muestraBadge(part.ownerEnvioTipo)) ...[
          const SizedBox(height: 8),
          Align(
              alignment: Alignment.centerLeft,
              child: EnvioPoliticaBadge(tipo: part.ownerEnvioTipo)),
          if (part.ownerTransportistas.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Transportistas: ${part.ownerTransportistas.join(', ')}',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
        if (desktop) ...[
          const SizedBox(height: 12),
          _buildActionAlerts(),
          _buildActionButtons(),
        ],
        const SizedBox(height: 6),
        ProductDetailSupplier(
            part: part,
            onOpen: _canOpenImporterStore ? _openImporterStore : null),
        if (part.isCatalogVerified || part.isCatalogFeatured) ...[
          const SizedBox(height: 4),
          ImporterCatalogSealsRow(
              verified: part.isCatalogVerified,
              featured: part.isCatalogFeatured),
        ],
        const SizedBox(height: 12),
        Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 16),
        ProductDetailInformation(
            part: part,
            showInternalReference: _profile?.isAdministrador == true ||
                _profile?.isImportador == true),
        if (part.hasWarranty) ...[
          const SizedBox(height: 16),
          const Align(
              alignment: Alignment.centerLeft, child: ProductWarrantySeal()),
        ],
      ];

  Widget _buildCommerceExtras() => _related.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 20),
          child: RelatedProductsSection(
              current: part, products: _related, profile: _profile));
  Widget _buildActionAlerts() {
    final warning = Theme.of(context).brightness == Brightness.dark
        ? AppColors.warningAmberOnDark
        : AppColors.warningAmber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (part.stockForSale < 1)
          _AlertBanner(
            text: 'Sin stock disponible',
            color: AppColors.textSecondary,
            background: AppColors.surfaceTinted,
            border: AppColors.borderSubtle,
          )
        else if (part.stockForSale < part.minOrderQtyEffective)
          _AlertBanner(
            text:
                'Stock insuficiente para el mínimo de pedido (${part.minOrderQtyLabelEs}).',
            color: warning,
            background:
                Color.alphaBlend(warning.withOpacity(0.08), AppColors.card),
            border: warning.withOpacity(0.25),
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

  bool get _showsOrderBar =>
      widget.guestPreview || _profile == null || _canOrder;

  Widget _buildActionButtons({bool compact = false}) {
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
    return ProductDetailPurchaseControls(
        part: part,
        profile: _profile!,
        compact: compact,
        onOpenCart: _openCart,
        onAsk: _canAskAboutProduct ? _askAboutProduct : null);
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.paddingOf(context).bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActionAlerts(),
          if (part.stockForSale < part.minOrderQtyEffective ||
              _pedidosSuspendidosMorosidad)
            const SizedBox(height: 8),
          _buildActionButtons(compact: true),
        ],
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
