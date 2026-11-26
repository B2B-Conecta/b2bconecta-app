import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:motolink_pro_app/core/widgets/desktop_workflow.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/widgets/aliado_header_search.dart';
import 'package:motolink_pro_app/core/widgets/b2b_header_title.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';
import 'importer_catalog_seals.dart';
import 'catalog_taxonomy.dart';
import 'importer_store_profile_screen.dart';
import 'mobile_supplier_chrome.dart';
import 'mobile_supplier_visuals.dart';
import 'supplier_directory_service.dart';

class SupplierDirectoryScreen extends StatefulWidget {
  const SupplierDirectoryScreen(
      {super.key, required this.viewer, this.loader, this.onOpenStore});
  final ProfileModel viewer;
  final SupplierDirectoryLoader? loader;
  final ValueChanged<String>? onOpenStore;

  @override
  State<SupplierDirectoryScreen> createState() =>
      _SupplierDirectoryScreenState();
}

class _SupplierDirectoryScreenState extends State<SupplierDirectoryScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  final _items = <SupplierDirectoryEntry>[];
  SupplierDirectoryFilter _filter = SupplierDirectoryFilter.all;
  String? _state, _category;
  List<String> _states = const [], _categories = const [];
  int _generation = 0, _total = 0;
  bool _loading = true, _failed = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_queueSearch);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _queueSearch() {
    _debounce?.cancel();
    // Invalida también la respuesta que llegue durante la pausa de escritura.
    _generation++;
    setState(() {
      _items.clear();
      _loading = true;
      _failed = false;
    });
    _debounce = Timer(const Duration(milliseconds: 320), () => _load());
  }

  Future<void> _load({bool more = false}) async {
    _debounce?.cancel();
    final generation = ++_generation;
    if (!more && _scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _loading = true;
      _failed = false;
      if (!more) _items.clear();
    });
    try {
      final page = await (widget.loader ?? SupplierDirectoryService.load)(
          query: _search.text.trim(),
          filter: _filter,
          state: _state,
          category: _category,
          offset: _items.length);
      if (!mounted || generation != _generation) return;
      setState(() {
        final ids = _items.map((e) => e.profile.id).toSet();
        _items.addAll(page.items.where((e) => ids.add(e.profile.id)));
        _total = page.total;
        _states = page.states;
        _categories = page.categories;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _filters() async {
    var state = _state, category = _category;
    final apply = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => SafeArea(
                child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 0, 20,
                        20 + MediaQuery.viewInsetsOf(context).bottom),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Filtrar proveedores',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                              value: state,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Estado'),
                              items: [
                                const DropdownMenuItem(
                                    value: null,
                                    child: Text('Todos los estados')),
                                for (final e in _states)
                                  DropdownMenuItem(value: e, child: Text(e))
                              ],
                              onChanged: (v) => update(() => state = v)),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                              value: category,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Categoría'),
                              items: [
                                const DropdownMenuItem(
                                    value: null,
                                    child: Text('Todas las categorías')),
                                for (final e in _categories)
                                  DropdownMenuItem(
                                      value: e, child: Text(e, maxLines: 2))
                              ],
                              onChanged: (v) => update(() => category = v)),
                          const SizedBox(height: 20),
                          FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Aplicar filtros')),
                          TextButton(
                              onPressed: () => update(() {
                                    state = category = null;
                                  }),
                              child: const Text('Limpiar filtros')),
                        ])))));
    if (!mounted || apply != true) return;
    setState(() {
      _state = state;
      _category = category;
    });
    await _load();
  }

  void _open(SupplierDirectoryEntry entry) {
    if (widget.onOpenStore != null) {
      widget.onOpenStore!(entry.profile.id);
      return;
    }
    ImporterStoreProfileScreen.open(context,
        importerId: entry.profile.id, viewer: widget.viewer);
  }

  Future<void> _openSearch() async {
    if (_scroll.hasClients) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(0);
      } else {
        await _scroll.animateTo(0,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic);
      }
    }
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) _searchFocus.requestFocus();
  }

  AppBar _directoryHeader(double progress, {double? brandedToolbarHeight}) {
    final compact = progress > .3;
    final opacity = MediaQuery.disableAnimationsOf(context)
        ? (compact ? 0.0 : 1.0)
        : 1 - Curves.easeOut.transform((progress / .7).clamp(0.0, 1.0));
    return mobileSupplierAppBar(context,
        title: 'Proveedores',
        viewer: widget.viewer,
        brandedToolbarHeight: brandedToolbarHeight,
        leadingActions: [
          if (compact)
            IconButton(
                tooltip: 'Abrir búsqueda de proveedores',
                onPressed: _openSearch,
                icon: const LucideIcon(LucideGlyph.search,
                    size: 21, color: Colors.white))
        ],
        bottom: PreferredSize(
            preferredSize: Size.fromHeight(70 * (1 - progress)),
            child: ClipRect(
                child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 1 - progress,
                    child: SizedBox(
                        height: 70,
                        child: ExcludeFocus(
                            excluding: compact,
                            child: ExcludeSemantics(
                                excluding: compact,
                                child: IgnorePointer(
                                    ignoring: compact,
                                    child: Opacity(
                                        key: const Key('supplier-search-fade'),
                                        opacity: opacity,
                                        child: AliadoHeaderSearch(
                                            controller: _search,
                                            focusNode: _searchFocus,
                                            hint: 'Nombre, marca o repuesto…',
                                            searchLabel: 'Buscar proveedores',
                                            filterLabel:
                                                'Filtros de proveedores',
                                            onSearch: () => _load(),
                                            onFilters: _filters,
                                            filterCount:
                                                (_state == null ? 0 : 1) +
                                                    (_category == null
                                                        ? 0
                                                        : 1)))))))))));
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 768;
    final toolbarHeight = B2bHeaderTitle.singleLineToolbarHeight(
      context,
      titleFontSize: supplierHeaderTitleSize,
    );
    final showNavigation = mobile &&
        widget.viewer.isAliado &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: mobile
          ? null
          : desktopWorkflowAppBar(context, 'Proveedores', actions: [
              IconButton(
                  onPressed: _filters,
                  tooltip: 'Filtros de proveedores',
                  icon: const LucideIcon(LucideGlyph.slidersHorizontal)),
            ]),
      extendBody: showNavigation,
      bottomNavigationBar:
          showNavigation ? const SupplierMobileNavigation() : null,
      body: mobile
          ? NestedScrollView(
              controller: _scroll,
              headerSliverBuilder: (context, _) => [
                    SliverPersistentHeader(
                        pinned: true,
                        delegate: _SupplierDirectoryHeader(
                            toolbarHeight: toolbarHeight +
                                MediaQuery.paddingOf(context).top,
                            builder: (_, progress) => _directoryHeader(progress,
                                brandedToolbarHeight: toolbarHeight))),
                    PinnedHeaderSliver(
                      child: ColoredBox(
                        color: AppColors.background,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _directoryFilters(),
                            if (!_loading && !_failed) _directoryCount(),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
              body: Builder(
                  builder: (context) => _directoryBody(
                      stickyFilters: true,
                      navigationInset: showNavigation
                          ? MediaQuery.paddingOf(context).bottom
                          : 0)))
          : Center(
              child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      controller: _search,
                      focusNode: _searchFocus,
                      onSubmitted: (_) => _load(),
                      decoration: const InputDecoration(
                          hintText: 'Busca por negocio, marca, SKU o repuesto…',
                          prefixIcon: Icon(Icons.search)),
                    )),
                Expanded(child: _directoryBody()),
              ]),
            )),
    );
  }

  Widget _directoryFilters() => Column(children: [
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              for (final filter in SupplierDirectoryFilter.values)
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SupplierFilterChip(
                        label: switch (filter) {
                          SupplierDirectoryFilter.all => 'Todos',
                          SupplierDirectoryFilter.purchased =>
                            'Donde compraste',
                          SupplierDirectoryFilter.rated => 'Mejor valorados',
                        },
                        selected: _filter == filter,
                        onSelected: (_) {
                          setState(() => _filter = filter);
                          _load();
                        })),
            ])),
        if (_state != null || _category != null)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 8, children: [
                if (_state != null)
                  InputChip(
                      label: Text(_state!),
                      onDeleted: () {
                        setState(() => _state = null);
                        _load();
                      }),
                if (_category != null)
                  InputChip(
                      label: Text(_category!),
                      onDeleted: () {
                        setState(() => _category = null);
                        _load();
                      }),
              ])),
      ]);

  Widget _directoryCount() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Text(
          '$_total ${_total == 1 ? 'proveedor' : 'proveedores'}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      );

  Widget _directoryBody({
    bool stickyFilters = false,
    double navigationInset = 0,
  }) =>
      Column(children: [
        if (!stickyFilters) _directoryFilters(),
        Expanded(
            child: RefreshIndicator(
                onRefresh: () => _load(),
                child: CustomScrollView(
                    controller: stickyFilters ? null : _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (!stickyFilters && !_loading && !_failed)
                        SliverToBoxAdapter(child: _directoryCount()),
                      SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                              delegate:
                                  SliverChildBuilderDelegate((context, index) {
                            final entry = _items[index];
                            final groupStart = index == 0 ||
                                _items[index - 1].purchased != entry.purchased;
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_filter == SupplierDirectoryFilter.all &&
                                      groupStart)
                                    Padding(
                                        padding: const EdgeInsets.only(
                                            top: 20, bottom: 10),
                                        child: Text(
                                            entry.purchased
                                                ? 'Donde ya compraste'
                                                : 'Explora otros proveedores',
                                            style: const TextStyle(
                                                fontSize: 21,
                                                fontWeight: FontWeight.w800))),
                                  Padding(
                                      padding: const EdgeInsets.only(
                                          top: 8, bottom: 4),
                                      child: _SupplierCard(
                                          entry: entry,
                                          onTap: () => _open(entry))),
                                ]);
                          }, childCount: _items.length))),
                      if (_loading)
                        const SliverToBoxAdapter(
                            child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                    child: CircularProgressIndicator()))),
                      if (_failed)
                        SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                              'No pudimos cargar los proveedores.',
                                              textAlign: TextAlign.center),
                                          const SizedBox(height: 12),
                                          FilledButton(
                                              onPressed: () => _load(
                                                  more: _items.isNotEmpty),
                                              child: const Text('Reintentar'))
                                        ])))),
                      if (!_loading && !_failed && _items.isEmpty)
                        SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                        _filter ==
                                                    SupplierDirectoryFilter
                                                        .purchased &&
                                                _search.text.trim().isEmpty &&
                                                _state == null &&
                                                _category == null
                                            ? 'Aquí aparecerán los proveedores de tus compras confirmadas.'
                                            : 'No encontramos proveedores con estos filtros.',
                                        textAlign: TextAlign.center)))),
                      if (!_loading && !_failed && _items.length < _total)
                        SliverToBoxAdapter(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: OutlinedButton(
                                    onPressed: () => _load(more: true),
                                    child: const Text('Ver más proveedores')))),
                      SliverToBoxAdapter(
                          child: SizedBox(height: 24 + navigationInset)),
                    ]))),
      ]);
}

/// Colapsa dentro del desplazamiento: no cambia el tamaño del viewport al medir
/// el offset, evitando saltos o rebotes cuando hay pocos proveedores.
class _SupplierDirectoryHeader extends SliverPersistentHeaderDelegate {
  const _SupplierDirectoryHeader(
      {required this.toolbarHeight, required this.builder});
  final double toolbarHeight;
  final Widget Function(BuildContext context, double progress) builder;
  @override
  double get minExtent => toolbarHeight;
  @override
  double get maxExtent => toolbarHeight + 70;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      builder(context, (shrinkOffset / 70).clamp(0.0, 1.0));
  @override
  bool shouldRebuild(covariant _SupplierDirectoryHeader oldDelegate) =>
      toolbarHeight != oldDelegate.toolbarHeight ||
      builder != oldDelegate.builder;
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({required this.entry, required this.onTap});
  final SupplierDirectoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = entry.profile;
    final colors = Theme.of(context).colorScheme;
    final categories = entry.categories.map(categoryFamily).toSet().toList();
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final categoryLabels = Wrap(spacing: 6, runSpacing: 5, children: [
      for (final category in categories.take(2))
        SupplierCategoryPill(label: catalogCategoryDisplayLabel(category)),
      if (categories.length > 2)
        SupplierCategoryPill(label: '+${categories.length - 2}'),
    ]);
    final storeLink = Row(mainAxisSize: MainAxisSize.min, children: [
      Text('Ver tienda',
          style: TextStyle(
              fontSize: 14,
              height: 1.2,
              color: colors.primary,
              fontWeight: FontWeight.w700)),
      const SizedBox(width: 4),
      SvgPicture.asset('assets/angulo/angulo-pequeno-derecho.svg',
          width: 16,
          height: 16,
          excludeFromSemantics: true,
          colorFilter: ColorFilter.mode(colors.primary, BlendMode.srcIn)),
    ]);
    return Material(
      color: supplierPanelColor(context),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          mobileSupplierLogo(context,
                              path: profile.logoStoragePath,
                              size: scale > 1.3 ? 62 : 78),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(profile.displayName,
                                    style: TextStyle(
                                        fontSize: 20,
                                        height: 1.15,
                                        fontWeight: FontWeight.w800,
                                        color: colors.onSurface)),
                                if (profile.locationLine.isNotEmpty)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.location_on_outlined,
                                                size: 17,
                                                color: colors.onSurfaceVariant),
                                            const SizedBox(width: 3),
                                            Expanded(
                                                child: Text(
                                                    profile.locationLine,
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        height: 1.2,
                                                        color: colors
                                                            .onSurfaceVariant))),
                                          ])),
                                const SizedBox(height: 5),
                                SupplierRating(
                                    average: profile.ratingAvg,
                                    count: profile.ratingCount),
                                if (profile.isCatalogVerified ||
                                    profile.isCatalogFeatured)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: ImporterCatalogSealsRow(
                                          verified: profile.isCatalogVerified,
                                          featured: profile.isCatalogFeatured,
                                          compact: true)),
                              ])),
                        ]),
                    const SizedBox(height: 6),
                    LayoutBuilder(builder: (context, constraints) {
                      if (categories.isEmpty) {
                        return Align(
                            alignment: Alignment.centerRight, child: storeLink);
                      }
                      if (constraints.maxWidth >= 316 && scale <= 1.2) {
                        return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(child: categoryLabels),
                              const SizedBox(width: 10),
                              storeLink,
                            ]);
                      }
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            categoryLabels,
                            const SizedBox(height: 5),
                            Align(
                                alignment: Alignment.centerRight,
                                child: storeLink),
                          ]);
                    }),
                  ]))),
    );
  }
}
