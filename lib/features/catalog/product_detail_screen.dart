import 'package:flutter/material.dart';

import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'catalog_service.dart';
import 'favorite_heart_button.dart';
import 'part_model.dart';
import 'product_detail_extras.dart';
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
import 'importer_catalog_seals.dart';
import 'importer_store_profile_screen.dart';
import 'product_share_sheet.dart';
import 'store_supplier_chat.dart';
import 'product_photo_gallery.dart';
import 'product_variants.dart';
import 'product_variant_selector.dart';
import 'recent_product_views.dart';

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
  late PartModel _selected;
  late List<PartModel> _family;
  final GlobalKey<ProductPhotoGalleryState> _galleryKey =
      GlobalKey<ProductPhotoGalleryState>();

  PartModel get part => _selected;

  List<String> get _galleryUrls =>
      variantGalleryUrls(selected: part, opened: widget.part, family: _family);

  @override
  void initState() {
    super.initState();
    _selected = widget.part;
    _family = widget.part.variantChoices;
    _loadProfile();
    _loadRelated();
    _loadVariantFamily();
  }

  Future<void> _loadVariantFamily() async {
    if (!widget.part.hasVariantFamily) return;
    try {
      final family = await CatalogService.fetchVariantFamily(widget.part);
      if (!mounted || family.length < 2) return;
      final selected = family.where((option) => option.id == _selected.id);
      setState(() {
        _family = family;
        _selected = selected.isEmpty ? family.first : selected.first;
      });
    } catch (_) {}
  }

  void _selectVariant(PartModel option) {
    if (option.id == _selected.id) return;
    setState(() => _selected = option);
  }

  Future<void> _loadRelated() async {
    if (part.id.trim().isEmpty) return;
    try {
      final rows = await CatalogService.fetchRelatedProducts(
        current: part,
        limit: 6,
      );
      if (!mounted) return;
      setState(() => _related = rows);
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    if (widget.guestPreview) return;
    try {
      final p = await SupabaseService.fetchMyProfile();
      if (!mounted) return;
      setState(() => _profile = p);
      if (p?.isAliado == true) RecentProductViews.record(p!.id, widget.part.id);
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
    // Umbral propio de ficha: en web ancha no debe verse como móvil apilado.
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.productDetailDesktop;
    if (isDesktop) return _buildDesktopLayout(context);
    return _buildMobileLayout(context);
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
            tooltip: 'Atrás',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded)),
        title: const Text('Detalle del repuesto',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: _detailAppBarActions(),
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeroImage(context)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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

  List<Widget> _detailAppBarActions() => [
        if (_profile?.isAliado == true)
          FavoriteHeartButton(productId: part.id),
        if (_canShareProduct)
          IconButton(
            tooltip: 'Compartir producto',
            onPressed: _shareProduct,
            icon: const Icon(Icons.ios_share_rounded),
          ),
      ];

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
        title: const Text('Detalle del repuesto'),
        actions: _detailAppBarActions(),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.productDetailMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _buildDesktopImageCard(),
                  ),
                ),
                const SizedBox(width: 36),
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
      child: Material(
        color: AppColors.white,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildHeroImageContent(),
            if (_galleryUrls.isNotEmpty)
              Positioned(
                right: 12,
                bottom: 12,
                child: Material(
                  color: const Color(0xFF004BDD),
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    tooltip: 'Ampliar foto',
                    onPressed: () =>
                        _galleryKey.currentState?.openFullscreen(),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.white,
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const LucideIcon(LucideGlyph.maximize2,
                        size: 18, color: AppColors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopImageCard() {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: AspectRatio(
                aspectRatio: 1,
                child: _buildHeroImageContent(),
              ),
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
      key: _galleryKey,
      urls: _galleryUrls,
      productName: part.nombre,
      heroTag: ProductDetailScreen.heroImageTag(widget.part));

  List<Widget> _buildInfoSections({bool desktop = false}) {
    return [
      ProductDetailHeading(
        part: part,
        desktop: desktop,
      ),
      if (_family.length > 1) ...[
        const SizedBox(height: 14),
        ProductVariantSelector(
            options: _family, selected: part, onSelected: _selectVariant),
      ],
      const SizedBox(height: 14),
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
        const SizedBox(height: 14),
        _buildActionAlerts(),
        _buildActionButtons(),
      ],
      const SizedBox(height: 16),
      ProductDetailSupplier(
          part: part,
          onOpen: _canOpenImporterStore ? _openImporterStore : null),
      if (part.isCatalogVerified || part.isCatalogFeatured) ...[
        const SizedBox(height: 8),
        ImporterCatalogSealsRow(
            verified: part.isCatalogVerified,
            featured: part.isCatalogFeatured),
      ],
      const SizedBox(height: 18),
      ProductDetailInformation(
          part: part,
          showInternalReference: _profile?.isAdministrador == true ||
              _profile?.isImportador == true),
    ];
  }

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
        key: ValueKey(part.id),
        part: part,
        profile: _profile!,
        compact: compact,
        variantFamily: _family,
        onOpenCart: _openCart,
        onAsk: _canAskAboutProduct ? _askAboutProduct : null);
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Material(
      color: AppColors.white,
      elevation: 8,
      shadowColor: AppColors.black.withOpacity(0.12),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          MediaQuery.paddingOf(context).bottom + 10,
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
