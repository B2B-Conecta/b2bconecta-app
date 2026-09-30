import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/infinite_scroll.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_layout.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/catalog_product_price_display.dart';
import 'package:motolink_pro_app/features/catalog/importer_catalog_logo.dart';
import 'package:motolink_pro_app/features/catalog/importer_store_profile.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_screen.dart';
import 'package:motolink_pro_app/features/catalog/product_warranty_seal.dart';
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
  });

  final String importerId;
  final ProfileModel viewer;
  final String? initialCategory;
  final ImporterStoreCatalogSource? catalogSource;

  static Future<void> open(
    BuildContext context, {
    required String importerId,
    required ProfileModel viewer,
    String? initialCategory,
  }) {
    final id = importerId.trim();
    if (id.isEmpty) return Future<void>.value();
    return Navigator.of(context).push<void>(
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
  int _crossAxisCount = 2;
  int _loadGen = 0;

  int get _pageSize => AliadoCatalogLayout.pageSizeForCount(_crossAxisCount);

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
      }
      final page = await _source.fetchParts(
        limit: _pageSize,
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
        _hasMore = page.length >= _pageSize;
        _loadingMore = false;
      });
      scheduleLoadMoreIfViewportNotFilled(
        controller: _scrollController,
        hasMore: _hasMore,
        isLoading: _loadingMore,
        loadMore: () => _loadMore(),
      );
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _loadingMore = false;
        if (_parts.isEmpty) _error = e.toString();
      });
    }
  }

  void _selectCategory(String? category) {
    final next = category?.trim();
    final normalized = (next == null || next.isEmpty) ? null : next;
    if (normalized == _selectedCategory) return;
    setState(() => _selectedCategory = normalized);
    _loadMore(reset: true);
  }

  Future<void> _openProduct(PartModel part) async {
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
      if (!mounted) return;
      if (checked == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ese producto no pertenece a este mayorista.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProductDetailScreen(part: checked),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(part: part),
      ),
    );
  }

  Future<void> _openMaps(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    _crossAxisCount = AliadoCatalogLayout.crossAxisCount(width);
    final hPad = AliadoCatalogLayout.horizontalPadding(width);
    const maxW = AppBreakpoints.adminContentMaxWidth;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_profile?.displayName ?? 'Mayorista'),
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
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (infiniteScrollShouldLoadMore(notification)) {
          _loadMore();
        }
        return false;
      },
      child: CustomScrollView(
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
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _crossAxisCount,
                  mainAxisSpacing: AliadoCatalogLayout.gridSpacing(
                    MediaQuery.sizeOf(context).width,
                  ),
                  crossAxisSpacing: AliadoCatalogLayout.gridSpacing(
                    MediaQuery.sizeOf(context).width,
                  ),
                  childAspectRatio: AliadoCatalogLayout.childAspectRatio(
                    MediaQuery.sizeOf(context).width,
                    showDistance: false,
                  ),
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final part = _parts[index];
                    return _StoreProductCard(
                      part: part,
                      onTap: () => _openProduct(part),
                    );
                  },
                  childCount: _parts.length,
                ),
              ),
            ),
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
      ),
    );
  }

  Widget _header(ImporterStoreProfile profile) {
    final rating = profile.ratingAvg;
    final count = profile.ratingCount ?? 0;
    final metodos = profile.pagoMetodoLabelsEs;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ImporterCatalogLogo(
                  storagePath: profile.logoStoragePath,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (profile.locationLine.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile.locationLine,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (profile.direccion?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          profile.direccion!.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (rating != null && count > 0) ...[
              const SizedBox(height: 10),
              Text(
                '${rating.toStringAsFixed(1)} ★ · $count valoración${count == 1 ? '' : 'es'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
            if (profile.hasMinOrder) ...[
              const SizedBox(height: 6),
              Text(
                profile.minOrderLabelEs,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
            if (profile.rif?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                'RIF ${profile.rif!.trim()}',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
            if (profile.phone?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(
                profile.phone!.trim(),
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
            if (metodos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                profile.pagoSoloDivisas
                    ? 'Pago en divisas: ${metodos.join(', ')}'
                    : 'Métodos de pago: ${metodos.join(', ')}',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
            if (profile.fiscalMapsUrl?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _openMaps(profile.fiscalMapsUrl!),
                child: const Text('Ver ubicación'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryChips() {
    return SingleChildScrollView(
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
    );
  }
}

class _StoreProductCard extends StatelessWidget {
  const _StoreProductCard({
    required this.part,
    required this.onTap,
  });

  final PartModel part;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: part.coverImageUrl != null &&
                          part.coverImageUrl!.isNotEmpty
                      ? Image.network(
                          part.coverImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: AppColors.surfaceTinted,
                            child: Icon(
                              Icons.image_outlined,
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      : ColoredBox(
                          color: AppColors.surfaceTinted,
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.textMuted,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                part.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              if ((part.category ?? '').trim().isNotEmpty)
                Text(
                  part.category!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandBlue,
                  ),
                ),
              const SizedBox(height: 2),
              CatalogProductPriceDisplay(
                listPriceUsd: part.precio,
                salePriceUsd: part.salePriceUsd,
                discountRules: part.discountRules,
                catalogGrid: true,
                compact: true,
                ownerPagoSoloDivisas: part.ownerPagoSoloDivisas,
              ),
              if (part.hasWarranty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: ProductWarrantySeal(compact: true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
