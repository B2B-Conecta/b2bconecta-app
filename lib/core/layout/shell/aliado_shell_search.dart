import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:motolink_pro_app/app/main_shell_tab.dart';
import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';
import 'package:motolink_pro_app/features/cart/cart_product_actions.dart';
import 'package:motolink_pro_app/features/cart/cart_service.dart';
import 'package:motolink_pro_app/features/catalog/aliado_catalog_categories.dart';
import 'package:motolink_pro_app/features/catalog/catalog_filters.dart';
import 'package:motolink_pro_app/features/catalog/catalog_service.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/catalog/product_detail_screen.dart';
import 'package:motolink_pro_app/features/catalog/variant_cart_picker_sheet.dart';
import 'package:motolink_pro_app/features/profile/profile_model.dart';

import 'aliado_shell_search_model.dart';
import 'aliado_shell_search_panel.dart';

/// Abre el panel cuando ⌘K llega con el campo ya enfocado.
class AliadoShellSearchController {
  VoidCallback? _open;

  void attach(VoidCallback open) => _open = open;

  void detach(VoidCallback open) {
    if (identical(_open, open)) _open = null;
  }

  void open() => _open?.call();
}

/// Buscador del shell web de la tienda minorista. El panel móvil no lo usa.
class AliadoShellSearch extends StatefulWidget {
  const AliadoShellSearch({
    super.key,
    required this.focusNode,
    this.profile,
    this.controller,
    this.recentSearches,
    this.loadParts,
  });

  final FocusNode focusNode;

  final ProfileModel? profile;
  final AliadoShellSearchController? controller;
  final AliadoRecentSearchStore? recentSearches;

  /// Sustituye la consulta al catálogo. Las pruebas lo usan para no tocar la red.
  final Future<List<PartModel>> Function(String query)? loadParts;

  @override
  State<AliadoShellSearch> createState() => _AliadoShellSearchState();
}

class _AliadoShellSearchState extends State<AliadoShellSearch> {
  final _query = TextEditingController();
  final _anchor = LayerLink();
  final _anchorKey = GlobalKey();
  final _panelKey = GlobalKey();
  late final AliadoRecentSearchStore _recentsStore =
      widget.recentSearches ?? AliadoRecentSearchStore();

  OverlayEntry? _entry;
  Timer? _debounce;
  int _request = 0;
  bool _visible = false;
  bool _suppressed = false;
  bool _loading = false;
  bool _metaLoading = false;
  bool _listeningKeys = false;
  String? _error;
  int _highlight = -1;
  List<String> _recents = const [];
  List<PartModel> _parts = const [];
  List<ImporterOption> _importers = const [];
  List<AliadoCatalogCategoryGroup> _groups = const [];

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
    widget.controller?.attach(_openFromShortcut);
    _query.addListener(_onQuery);
    CartService.instance.addListener(_onCart);
    WidgetsBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  @override
  void didUpdateWidget(AliadoShellSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(_openFromShortcut);
      widget.controller?.attach(_openFromShortcut);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _stopKeys();
    WidgetsBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    widget.controller?.detach(_openFromShortcut);
    widget.focusNode.removeListener(_onFocus);
    _query.removeListener(_onQuery);
    CartService.instance.removeListener(_onCart);
    _query.dispose();
    super.dispose();
  }

  List<AliadoShellSearchItem> get _items {
    final query = _query.text;
    return buildAliadoShellSearchItems(
      query: query,
      recents: _recents,
      completions: aliadoShellCompletions(query: query, parts: _parts),
      parts: _parts,
      suppliers: aliadoShellSupplierHits(query, _importers),
      categories: aliadoShellCategoryHits(query: query, groups: _groups),
    );
  }

  void _onCart() {
    if (!mounted) return;
    _entry?.markNeedsBuild();
  }

  void _onFocus() {
    if (!widget.focusNode.hasFocus || _suppressed) return;
    _show();
  }

  void _onQuery() {
    _highlight = -1;
    if (!_visible) {
      if (mounted) setState(() {});
      return;
    }
    final query = _query.text.trim();
    if (query.isEmpty) {
      _debounce?.cancel();
      _loading = false;
      _error = null;
      _parts = const [];
    } else {
      _schedule(query);
    }
    if (mounted) setState(() {});
    _entry?.markNeedsBuild();
  }

  void _openFromShortcut() {
    _suppressed = false;
    widget.focusNode.requestFocus();
    _show();
  }

  void _show() {
    if (!mounted) return;
    _visible = true;
    _suppressed = false;
    _recents = _recentsStore.current;
    _listenKeys();
    _ensureOverlay();
    unawaited(_loadRecents());
    unawaited(_ensureMeta());
    final query = _query.text.trim();
    if (query.isNotEmpty) _schedule(query);
    setState(() {});
  }

  void _close({bool suppress = false}) {
    _visible = false;
    _suppressed = suppress;
    _debounce?.cancel();
    _loading = false;
    _highlight = -1;
    _stopKeys();
    _removeOverlay();
    if (mounted) setState(() {});
  }

  void _listenKeys() {
    if (_listeningKeys) return;
    HardwareKeyboard.instance.addHandler(_onKey);
    _listeningKeys = true;
  }

  void _stopKeys() {
    if (!_listeningKeys) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    _listeningKeys = false;
  }

  bool _onKey(KeyEvent event) {
    if (!_visible || !widget.focusNode.hasFocus) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _close(suppress: true);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return true;
    }
    return false;
  }

  void _move(int delta) {
    final items = _items;
    if (items.isEmpty) return;
    final current = _highlight < 0
        ? (delta > 0 ? -1 : items.length)
        : _highlight;
    setState(() {
      _highlight = (current + delta).clamp(0, items.length - 1);
    });
    _entry?.markNeedsBuild();
  }

  void _onPointer(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    final point = event.position;
    final field = _rect(_anchorKey);
    if (field != null && field.contains(point)) {
      if (_suppressed && widget.focusNode.hasFocus) _show();
      return;
    }
    if (!_visible) return;
    final panel = _rect(_panelKey);
    if (panel != null && panel.contains(point)) return;
    _close(suppress: true);
  }

  Rect? _rect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _ensureOverlay() {
    if (_entry != null) {
      _entry!.markNeedsBuild();
      return;
    }
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _entry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_entry!);
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  Widget _buildOverlay(BuildContext context) {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final width = (box?.size.width ?? 560).clamp(320.0, 620.0);
    final top = box == null
        ? 72.0
        : box.localToGlobal(Offset.zero).dy + box.size.height + 8;
    final available = MediaQuery.sizeOf(context).height - top - 16;
    final maxHeight = available.clamp(180.0, 460.0);
    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _anchor,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 8),
        child: KeyedSubtree(
          key: _panelKey,
          child: AliadoShellSearchPanel(
            query: _query.text,
            items: _items,
            highlight: _highlight,
            loading: _loading,
            error: _error,
            profile: widget.profile,
            maxHeight: maxHeight,
            onActivate: _activate,
            onClearRecents: _clearRecents,
            onAdd: _addPart,
          ),
        ),
      ),
    );
  }

  void _schedule(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_loadParts(query));
    });
  }

  Future<void> _loadRecents() async {
    final values = await _recentsStore.read();
    if (!mounted || !_visible) return;
    setState(() => _recents = values);
    _entry?.markNeedsBuild();
  }

  Future<void> _ensureMeta() async {
    if (_metaLoading || _importers.isNotEmpty || _groups.isNotEmpty) return;
    _metaLoading = true;
    try {
      final results = await Future.wait<Object>([
        CatalogService.fetchImporterOptions(),
        CatalogService.fetchPublishedCatalogOwnerIds(),
        CatalogService.fetchAliadoCatalogCategories(),
      ]);
      if (!mounted) return;
      final published = results[1] as Set<String>;
      final importers = [
        for (final importer in results[0] as List<ImporterOption>)
          if (published.contains(importer.id)) importer,
      ];
      final groups = catalogCategoryFamilies(results[2] as List<String>);
      setState(() {
        _importers = importers;
        _groups = groups;
      });
      _entry?.markNeedsBuild();
    } catch (_) {
      // Los atajos de taxonomía siguen disponibles sin el catálogo remoto.
    } finally {
      _metaLoading = false;
    }
  }

  Future<void> _loadParts(String query) async {
    final token = ++_request;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
      _entry?.markNeedsBuild();
    }
    try {
      final parts = widget.loadParts != null
          ? await widget.loadParts!(query)
          : await _catalogParts(query);
      if (!mounted || token != _request || !_visible) return;
      setState(() {
        _parts = parts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _request || !_visible) return;
      setState(() {
        _parts = const [];
        _loading = false;
        _error = 'No se pudo cargar la vista previa. Puedes abrir el catálogo.';
      });
    }
    _entry?.markNeedsBuild();
  }

  Future<List<PartModel>> _catalogParts(String query) async {
    final primary = await CatalogService.fetchParts(
      limit: 5,
      filters: CatalogFilters(searchQuery: query),
    );
    if (primary.length >= 5) return primary;
    final exact = aliadoShellCategoryHits(query: query, groups: _groups)
        .where((hit) =>
            foldAliadoSearch(hit.label) == foldAliadoSearch(query) ||
            foldAliadoSearch(hit.family) == foldAliadoSearch(query))
        .toList();
    if (exact.isEmpty) return primary;
    final extra = await CatalogService.fetchParts(
      limit: 5,
      filters: CatalogFilters(
        category: exact.first.family,
        categoryAnyOf: exact.first.values,
      ),
    );
    final seen = {for (final part in primary) part.id};
    return [
      ...primary,
      for (final part in extra)
        if (seen.add(part.id)) part,
    ].take(5).toList();
  }

  Future<void> _remember(String query) async {
    await _recentsStore.remember(query);
    if (!mounted) return;
    setState(() => _recents = _recentsStore.current);
  }

  void _search({bool openFilters = false, String? query}) {
    final text = (query ?? _query.text).trim();
    if (query != null && query != _query.text) {
      _query.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    if (text.isNotEmpty) unawaited(_remember(text));
    _close(suppress: true);
    MainShellTabController.navigateToAliadoCatalog(
      filters: CatalogFilters(searchQuery: text.isEmpty ? null : text),
      openFilters: openFilters,
    );
  }

  void _activate(int index) {
    final items = _items;
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    switch (item.kind) {
      case AliadoShellSearchKind.recent:
      case AliadoShellSearchKind.suggested:
      case AliadoShellSearchKind.seeAll:
        _search(query: item.label);
      case AliadoShellSearchKind.completion:
        _query.value = TextEditingValue(
          text: item.label,
          selection: TextSelection.collapsed(offset: item.label.length),
        );
        widget.focusNode.requestFocus();
        _highlight = -1;
        _schedule(item.label);
        _entry?.markNeedsBuild();
      case AliadoShellSearchKind.product:
        final part = item.part;
        if (part == null) return;
        unawaited(_remember(_query.text));
        _close(suppress: true);
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => ProductDetailScreen(part: part)),
        );
      case AliadoShellSearchKind.supplier:
        final supplier = item.supplier;
        if (supplier == null) return;
        unawaited(_remember(_query.text));
        _close(suppress: true);
        MainShellTabController.navigateToAliadoCatalog(
          filters: CatalogFilters(ownerIds: [supplier.id]),
        );
      case AliadoShellSearchKind.category:
        final category = item.category;
        if (category == null) return;
        unawaited(_remember(_query.text));
        _close(suppress: true);
        MainShellTabController.navigateToAliadoCatalog(
          filters: CatalogFilters(
            category: category.family,
            categoryAnyOf: category.values,
          ),
        );
    }
  }

  void _clearRecents() {
    unawaited(_recentsStore.clear());
    setState(() => _recents = const []);
    _entry?.markNeedsBuild();
  }

  void _addPart(PartModel part) {
    final profile = widget.profile;
    if (profile == null) return;
    if (part.variantChoices.isNotEmpty) {
      unawaited(showVariantCartPickerSheet(
        context: context,
        part: part,
        profile: profile,
      ));
      return;
    }
    final added = CartProductActions.addMinimum(
      part: part,
      profile: profile,
      cart: CartService.instance,
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    if (added > 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Agregado a la bolsa')),
      );
      return;
    }
    final reason = CartProductActions.blockReason(
      part: part,
      profile: profile,
      cart: CartService.instance,
    );
    if (reason != null) {
      messenger.showSnackBar(SnackBar(content: Text(reason)));
    }
  }

  void _clearText() {
    _query.clear();
    widget.focusNode.requestFocus();
    _highlight = -1;
    _parts = const [];
    _error = null;
    _loading = false;
    _debounce?.cancel();
    setState(() {});
    _entry?.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final isApple = Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.iOS;
    final shortcut = isApple ? '⌘K' : 'Ctrl+K';
    final radius = BorderRadius.circular(12);
    final border = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.borderSubtle),
    );
    final hasText = _query.text.trim().isNotEmpty;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 600,
        maxHeight: 44,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
        Expanded(
          child: CompositedTransformTarget(
            link: _anchor,
            child: KeyedSubtree(
              key: _anchorKey,
              child: TextField(
                controller: _query,
                focusNode: widget.focusNode,
                onSubmitted: (_) {
                  if (_highlight >= 0) {
                    _activate(_highlight);
                  } else {
                    _search();
                  }
                },
                textInputAction: TextInputAction.search,
                style: TextStyle(color: theme.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar repuestos, bujías, cauchos…',
                  hintStyle: TextStyle(color: theme.textMuted, fontSize: 13.5),
                  filled: true,
                  fillColor: theme.inputFill,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: LucideIcon(
                      LucideGlyph.search,
                      size: 18,
                      color: theme.textSecondary,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                    maxWidth: 40,
                    maxHeight: 40,
                  ),
                  suffixIcon: hasText
                      ? IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: _clearText,
                          icon: LucideIcon(
                            LucideGlyph.close,
                            size: 16,
                            color: theme.textSecondary,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Center(
                            widthFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.surfaceSubtle,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                child: Text(
                                  shortcut,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: theme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 28,
                  ),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: radius,
                    borderSide: const BorderSide(color: B2BBrandHero.start),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
      ),
    );
  }
}
