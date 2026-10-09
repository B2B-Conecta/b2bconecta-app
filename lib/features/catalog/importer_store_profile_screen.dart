import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_categories.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_layout.dart';
import 'package:motolink_pro_app/features/catalog/catalog_route_lock.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/catalog_product_price_display.dart';
import 'package:motolink_pro_app/features/catalog/favorite_heart_button.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_logo.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_seals.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_profile.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_screen.dart';
import 'package:motolink_pro_app/features/catalog/product_warranty_seal.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields.dart';
import 'package:motolink_pro_app/features/inventory/product_custom_fields_section.dart';
import 'package:motolink_pro_app/features/catalog/store_supplier_chat.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

/// Acceso a datos de la vitrina. En la app usa [SupabaseService]; en tests se inyecta.
class ImporterStoreCatalogSource {
  const ImporterStoreCatalogSource({
    required this.fetchProfile,
    required this.fetchCategories,
    required this.fetchParts,
    this.fetchVisibleProduct,
  });

  final Future<ImporterStoreProfile?> Function(String importerId) fetchProfile;
  final Future<List<String>> Function(String importerId) fetchCategories;
  final Future<List<PartModel>> Function({
    required int limit,
    required int offset,
    required CatalogFilters filters,
  }) fetchParts;
  final Future<PartModel?> Function({
    required String importerId,
    required String productId,
  })? fetchVisibleProduct;

  static ImporterStoreCatalogSource app() => ImporterStoreCatalogSource(
        fetchProfile: SupabaseService.fetchImporterStoreProfile,
        fetchCategories: SupabaseService.fetchImporterStoreCategories,
        fetchParts: ({
          required int limit,
          required int offset,
          required CatalogFilters filters,
        }) =>
            SupabaseService.fetchParts(
          limit: limit,
          offset: offset,
          filters: filters,
        ),
        fetchVisibleProduct: ({
          required String importerId,
          required String productId,
        }) =>
            SupabaseService.fetchVisibleImporterStoreProduct(
          importerId: importerId,
          productId: productId,
        ),
      );
}

/// Vitrina de un mayorista: ficha comercial y catálogo solo de ese negocio.
class ImporterStoreProfileScreen extends StatefulWidget {
  const ImporterStoreProfileScreen({
    super.key,
    required this.importerId,
    required this.viewer,
    this.initialCategory,
    this.catalogSource,
    this.onOpenSupplierChat,
  });

  final String importerId;
  final ProfileModel viewer;
  final String? initialCategory;
  final ImporterStoreCatalogSource? catalogSource;

  /// Sustituye la apertura real en pruebas. No recarga la vitrina.
  final Future<void> Function(BuildContext context)? onOpenSupplierChat;

  static Future<void> open(
    BuildContext context, {
    required String importerId,
    required ProfileModel viewer,
    String? initialCategory,
  }) {
    final id = importerId.trim();
    if (id.isEmpty) return Future<void>.value();
    return CatalogRouteLock.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ImporterStoreProfileScreen(
          importerId: id,
          viewer: viewer,
          initialCategory: initialCategory,
        ),
      ),
    );
  }

  @override
  State<ImporterStoreProfileScreen> createState() =>
      _ImporterStoreProfileScreenState();
}

class _ImporterStoreProfileScreenState
    extends State<ImporterStoreProfileScreen> {
  final _scrollController = ScrollController();
  late final ImporterStoreCatalogSource _source;
  ImporterStoreProfile? _profile;
  List<String> _categories = const [];
  final List<PartModel> _parts = [];
  bool _loadingProfile = true;
  bool _notFound = false;
  String? _error;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _selectedCategory;
  int _viewPage = 0;
  int _viewPageSize = listPageSizeOptions.first;
  int _loadGen = 0;

  CatalogFilters get _filters => CatalogFilters.importerStore(
        importerId: widget.importerId,
        category: _selectedCategory,
      );

  @override
  void initState() {
    super.initState();
    _source = widget.catalogSource ?? ImporterStoreCatalogSource.app();
    final initial = widget.initialCategory?.trim();
    if (initial != null && initial.isNotEmpty) {
      _selectedCategory = initial;
    }
    _loadProfile();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _error = null;
      _notFound = false;
    });
    try {
      final profile = await _source.fetchProfile(widget.importerId);
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _profile = null;
          _notFound = true;
          _loadingProfile = false;
        });
        return;
      }
      List<String> cats = const [];
      try {
        cats = await _source.fetchCategories(widget.importerId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _categories = cats;
        _loadingProfile = false;
        _parts.clear();
        _hasMore = true;
        _viewPage = 0;
      });
      await _loadMore(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingProfile = false;
      });
    }
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (!reset && (_loadingMore || !_hasMore)) return;
    final gen = ++_loadGen;
    setState(() => _loadingMore = true);
    try {
      if (reset) {
        _parts.clear();
        _hasMore = true;
        _viewPage = 0;
      }
      final page = await _source.fetchParts(
        limit: _viewPageSize,
        offset: _parts.length,
        filters: _filters,
      );
      if (!mounted || gen != _loadGen) return;
      final kept = retainImporterStoreCatalogParts(
        importerId: widget.importerId,
        parts: page,
        category: _selectedCategory,
      );
      setState(() {
        _parts.addAll(kept);
        _hasMore = page.length >= _viewPageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _loadingMore = false;
        if (_parts.isEmpty) _error = e.toString();
      });
    }
  }

  Future<void> _openViewPage(int index) async {
    final need = (index + 1) * _viewPageSize;
    while (mounted && _parts.length < need && _hasMore) {
      final before = _parts.length;
      await _loadMore();
      if (!mounted || _parts.length == before) break;
    }
    if (!mounted) return;
    setState(() => _viewPage = index);
  }

  void _selectCategory(String? category) {
    final next = category?.trim();
    final normalized = (next == null || next.isEmpty) ? null : next;
    if (normalized == _selectedCategory) return;
    setState(() {
      _selectedCategory = normalized;
      _viewPage = 0;
    });
    _loadMore(reset: true);
  }

  Future<void> _openProduct(PartModel part) async {
    if (!CatalogRouteLock.tryHold()) return;
    var handedOff = false;
    try {
      handedOff = await _pushProduct(part);
    } finally {
      if (!handedOff) CatalogRouteLock.release();
    }
  }

  Future<bool> _pushProduct(PartModel part) async {
    if (!catalogPartBelongsToImporterStore(
      importerId: widget.importerId,
      ownerId: part.ownerId,
      isActive: part.isActive,
    )) {
      final checked = await (_source.fetchVisibleProduct ??
              SupabaseService.fetchVisibleImporterStoreProduct)(
        importerId: widget.importerId,
        productId: part.id,
      );
      if (!mounted) return false;
      if (checked == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ese producto no pertenece a este mayorista.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
      await CatalogRouteLock.pushHeld(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(part: checked),
        ),
      );
      return true;
    }
    await CatalogRouteLock.pushHeld(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(part: part),
      ),
    );
    return true;
  }

  bool get _canMessageSupplier => showStoreSupplierChatButton(
        viewerRole: widget.viewer.role,
        viewerId: widget.viewer.id,
        importerId: widget.importerId,
      );

  Future<void> _openSupplierChat() async {
    final custom = widget.onOpenSupplierChat;
    if (custom != null) {
      await custom(context);
      return;
    }
    try {
      final threadId = await StoreSupplierChatService.openOrCreate(
        importadorId: widget.importerId,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => StoreSupplierChatScreen(threadId: threadId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el mensaje: $e')),
      );
    }
  }

  Future<void> _openMaps(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPad = AliadoCatalogLayout.horizontalPadding(width);
    const maxW = AppBreakpoints.adminContentMaxWidth;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_profile?.displayName ?? 'Mayorista'),
        actions: [
          if (_profile != null && _canMessageSupplier)
            IconButton(
              key: const Key('store-supplier-chat'),
              tooltip: 'Mensaje al proveedor',
              onPressed: _openSupplierChat,
              icon: const Icon(Icons.chat_bubble_outline),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: _body(hPad),
        ),
      ),
    );
  }

  Widget _body(double hPad) {
    if (_loadingProfile) {
      return const Center(
        key: Key('importer-store-loading'),
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }
    if (_notFound) {
      return Center(
        key: const Key('importer-store-not-found'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No encontramos este mayorista.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
        ),
      );
    }
    if (_error != null && _profile == null) {
      return Center(
        key: const Key('importer-store-error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No se pudo cargar el perfil.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadProfile,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;
    final visibleParts = sliceListPage(
      items: _parts,
      pageIndex: _viewPage,
      pageSize: _viewPageSize,
    );
    return CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
            sliver: SliverToBoxAdapter(child: _header(profile)),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 8),
            sliver: SliverToBoxAdapter(child: _categoryChips()),
          ),
          if (_error != null && _parts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No se pudo cargar el catálogo.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => _loadMore(reset: true),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          else if (!_loadingMore && _parts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                key: const Key('importer-store-empty'),
                child: Text(
                  _selectedCategory == null
                      ? 'Este mayorista aún no tiene productos en vitrina.'
                      : 'No hay productos en esta categoría.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
              sliver: SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, gridConstraints) {
                    return AliadoCatalogCardWrap(
                      maxWidth: gridConstraints.maxWidth,
                      itemCount: visibleParts.length,
                      itemBuilder: (context, index) {
                        final part = visibleParts[index];
                        return _StoreProductCard(
                          part: part,
                          showHeart: widget.viewer.isAliado,
                          onTap: () => _openProduct(part),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 24),
              sliver: SliverToBoxAdapter(
                child: ListPageBar(
                  total: _parts.length,
                  hasMore: _hasMore,
                  pageIndex: _viewPage,
                  pageSize: _viewPageSize,
                  alwaysShow: true,
                  onPageIndex: (index) {
                    _openViewPage(index);
                  },
                  onPageSize: (size) {
                    setState(() {
                      _viewPageSize = size;
                      _viewPage = 0;
                    });
                    if (_parts.length < size && _hasMore) {
                      _openViewPage(0);
                    }
                  },
                ),
              ),
            ),
          ],
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ),
            ),
        ],
    );
  }

  Widget _header(ImporterStoreProfile profile) {
    final rating = profile.ratingAvg;
    final count = profile.ratingCount ?? 0;
    final metodos = profile.pagoMetodoLabelsEs;
    final address = profile.direccion?.trim() ?? '';
    final rif = profile.rif?.trim() ?? '';
    final phone = profile.phone?.trim() ?? '';
    final maps = profile.fiscalMapsUrl?.trim() ?? '';
    final logo = profile.logoStoragePath?.trim() ?? '';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (logo.isNotEmpty) ...[
                  ImporterCatalogLogo(
                    storagePath: logo,
                    size: 64,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (profile.locationLine.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile.locationLine,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (profile.isCatalogVerified ||
                          profile.isCatalogFeatured) ...[
                        const SizedBox(height: 8),
                        ImporterCatalogSealsRow(
                          verified: profile.isCatalogVerified,
                          featured: profile.isCatalogFeatured,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if ((rating != null && count > 0) || profile.hasMinOrder) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (rating != null && count > 0)
                    _StoreFactChip(
                      icon: Icons.star_rounded,
                      iconColor: Colors.amber.shade800,
                      label:
                          '${rating.toStringAsFixed(1)} · $count valoración${count == 1 ? '' : 'es'}',
                    ),
                  if (profile.hasMinOrder)
                    _StoreFactChip(
                      icon: Icons.inventory_2_outlined,
                      label: profile.minOrderLabelEs,
                    ),
                ],
              ),
            ],
            if (address.isNotEmpty || rif.isNotEmpty || phone.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (address.isNotEmpty)
                _StoreDetailRow(icon: Icons.place_outlined, text: address),
              if (rif.isNotEmpty)
                _StoreDetailRow(icon: Icons.badge_outlined, text: 'RIF $rif'),
              if (phone.isNotEmpty)
                _StoreDetailRow(
                  icon: Icons.phone_outlined,
                  text: phone,
                  onTap: () => _openPhone(phone),
                ),
            ],
            if (metodos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                profile.pagoSoloDivisas ? 'Pago en divisas' : 'Métodos de pago',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final metodo in metodos)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandBlueContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        metodo,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (maps.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openMaps(maps),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Ver ubicación'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  Widget _categoryChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catálogo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Todos'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => _selectCategory(null),
                ),
              ),
              for (final c in _categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c.trim()),
                    selected: _selectedCategory == c,
                    onSelected: (_) => _selectCategory(c),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreFactChip extends StatelessWidget {
  const _StoreFactChip({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceTinted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor ?? AppColors.brand),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreDetailRow extends StatelessWidget {
  const _StoreDetailRow({
    required this.icon,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: onTap == null ? AppColors.textSecondary : AppColors.brand,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _StoreProductCard extends StatelessWidget {
  const _StoreProductCard({
    required this.part,
    required this.onTap,
    required this.showHeart,
  });

  final PartModel part;
  final VoidCallback onTap;
  final bool showHeart;

  @override
  Widget build(BuildContext context) {
    final cover = part.coverImageUrl;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.7,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        cover != null && cover.isNotEmpty
                            ? Image.network(
                                cover,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const _StoreImagePlaceholder(),
                              )
                            : const _StoreImagePlaceholder(),
                        if (part.hasWarranty)
                          const Positioned(
                            top: 6,
                            left: 6,
                            child: ProductWarrantySeal(compact: true),
                          ),
                        if (showHeart)
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: FavoriteHeartButton(
                              productId: part.id,
                              compact: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  part.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                if ((part.category ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    formatCatalogCategoryLabel(part.category!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                      height: 1.1,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                CatalogProductPriceDisplay(
                  listPriceUsd: part.precio,
                  salePriceUsd: part.salePriceUsd,
                  discountRules: part.discountRules,
                  campaignDiscountPercent: part.activeCampaignDiscountPercent,
                  catalogGrid: true,
                  compact: true,
                  showPromotionChips: false,
                  ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${part.stock} en stock',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.successGreen,
                        ),
                      ),
                      TextSpan(
                        text: ' · ${part.minOrderQtyLabelEs}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (productCustomFieldsDisplayEntries(
                  part.customFields,
                  aliadoView: true,
                ).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ProductCustomFieldsAliadoChips(
                    customFields: part.customFields,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoreImagePlaceholder extends StatelessWidget {
  const _StoreImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceTinted,
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: AppColors.textMuted,
      ),
    );
  }
}
