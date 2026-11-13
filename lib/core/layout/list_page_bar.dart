import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/widgets/lucide_icon.dart';

/// Opciones de filas por vista. El máximo es 20.
const listPageSizeOptions = <int>[10, 20];

/// Total del paginador: el conteo real [matching] si ya llegó; si no, lo cargado.
int listPagerTotal({required int loaded, int? matching}) {
  if (matching == null || matching < loaded) return loaded;
  return matching;
}

/// Hay filas más allá del lote en memoria.
bool listPagerHasMore({
  required int loaded,
  required int batchLength,
  required int fetchSize,
  int? matching,
}) {
  if (matching != null) return loaded < matching;
  return fetchSize > 0 && batchLength >= fetchSize;
}

int clampListPageIndex({
  required int pageIndex,
  required int total,
  required int pageSize,
}) {
  if (total <= 0 || pageSize <= 0) return 0;
  final last = ((total - 1) / pageSize).floor();
  if (pageIndex < 0) return 0;
  if (pageIndex > last) return last;
  return pageIndex;
}

List<T> sliceListPage<T>({
  required List<T> items,
  required int pageIndex,
  required int pageSize,
}) {
  if (items.isEmpty) return const [];
  final index = clampListPageIndex(
    pageIndex: pageIndex,
    total: items.length,
    pageSize: pageSize,
  );
  final start = index * pageSize;
  final end = math.min(start + pageSize, items.length);
  return items.sublist(start, end);
}

/// Ejecuta [action] sin resetear el scroll del ancestro más cercano.
///
/// Evita el salto a `scrollTop = 0` al paginar tablas embebidas en
/// [ListView] / [CustomScrollView] (p. ej. tras `setState`).
void invokeKeepingScrollOffset(
  BuildContext context,
  VoidCallback action,
) {
  final scrollable = Scrollable.maybeOf(context);
  final position = scrollable?.position;
  final saved = (position != null && position.hasPixels) ? position.pixels : null;
  final primary = PrimaryScrollController.maybeOf(context);
  final primarySaved =
      (primary != null && primary.hasClients) ? primary.offset : null;

  action();

  if (saved == null && primarySaved == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final nextScrollable = Scrollable.maybeOf(context);
    final nextPos = nextScrollable?.position;
    if (nextPos != null && nextPos.hasPixels && saved != null) {
      nextPos.jumpTo(saved.clamp(0.0, nextPos.maxScrollExtent));
      return;
    }
    final nextPrimary = PrimaryScrollController.maybeOf(context);
    if (nextPrimary != null &&
        nextPrimary.hasClients &&
        primarySaved != null) {
      nextPrimary.jumpTo(
        primarySaved.clamp(0.0, nextPrimary.position.maxScrollExtent),
      );
    }
  });
}

/// Paginador estándar B2B Conecta (pie de listado):
/// `Mostrando 1–10 de N` a la izquierda · `< 1 / 3 >` a la derecha.
class ListPageBar extends StatelessWidget {
  const ListPageBar({
    super.key,
    required this.total,
    required this.pageIndex,
    required this.pageSize,
    required this.onPageIndex,
    this.onPageSize,
    this.hasMore = false,
    this.pageSizeOptions = listPageSizeOptions,
    this.showPageSizeControls = false,
    this.alwaysShow = false,
    this.entityLabel,
    this.topPadding = 12,
    this.bottomPadding = 10,
    this.busy = false,
    this.keepScrollOffset = true,
  });

  final int total;
  final int pageIndex;
  final int pageSize;
  final ValueChanged<int> onPageIndex;

  /// Opcional; solo se usa si [showPageSizeControls] es true.
  final ValueChanged<int>? onPageSize;

  /// Hay filas que todavía no están en [total]. Mantiene activa la flecha siguiente.
  final bool hasMore;

  final List<int> pageSizeOptions;

  /// Chips «Por vista» (ocultos por defecto; el estándar visual es el pie Mostrando).
  final bool showPageSizeControls;

  /// Muestra la barra aunque la lista quepa en una página.
  final bool alwaysShow;

  /// Sufijo opcional: «Mostrando 1–8 de 8 eventos».
  final String? entityLabel;

  final double topPadding;
  final double bottomPadding;

  /// Indicador inline sutil mientras se carga otra página (fetch remoto).
  final bool busy;

  /// Si es true (default), el cambio de página no resetea el scroll del viewport.
  final bool keepScrollOffset;

  void _goToPage(BuildContext context, int next) {
    if (!keepScrollOffset) {
      onPageIndex(next);
      return;
    }
    invokeKeepingScrollOffset(context, () => onPageIndex(next));
  }

  void _changePageSize(BuildContext context, int size) {
    final cb = onPageSize;
    if (cb == null) return;
    if (!keepScrollOffset) {
      cb(size);
      return;
    }
    invokeKeepingScrollOffset(context, () => cb(size));
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final options =
        pageSizeOptions.isEmpty ? listPageSizeOptions : pageSizeOptions;
    // Pie estándar visible con datos (o alwaysShow / hasMore).
    if (total <= 0 && !alwaysShow && !hasMore) {
      return const SizedBox.shrink();
    }

    final size = options.contains(pageSize)
        ? pageSize
        : (options.isEmpty ? pageSize : options.first);
    final index = clampListPageIndex(
      pageIndex: pageIndex,
      total: total <= 0 ? 1 : total,
      pageSize: size <= 0 ? 10 : size,
    );
    final start = total == 0 ? 0 : index * size + 1;
    final end = total == 0 ? 0 : math.min(start + size - 1, total);
    final lastPage = total <= 0 ? 0 : ((total - 1) / size).floor();
    final pageCount = total <= 0 ? 1 : lastPage + 1;
    final noun = (entityLabel ?? '').trim();
    final showing = total == 0
        ? (noun.isEmpty ? 'Mostrando 0' : 'Mostrando 0 $noun')
        : (noun.isEmpty
            ? 'Mostrando $start–$end de $total'
            : 'Mostrando $start–$end de $total $noun');

    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (busy)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: theme.surfaceSubtle,
                  color: theme.brand,
                ),
              ),
            ),
          if (showPageSizeControls &&
              onPageSize != null &&
              options.length > 1) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: _sizeChoices(context, theme, size, options),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  showing,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textSecondary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Anterior',
                visualDensity: VisualDensity.compact,
                onPressed: index > 0 && !busy
                    ? () => _goToPage(context, index - 1)
                    : null,
                icon: LucideIcon(
                  LucideGlyph.chevronLeft,
                  size: 16,
                  color: index > 0 && !busy
                      ? theme.textPrimary
                      : theme.textMuted,
                ),
              ),
              Text(
                '${index + 1} / $pageCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
              IconButton(
                tooltip: 'Siguiente',
                visualDensity: VisualDensity.compact,
                onPressed: !busy && (index < lastPage || hasMore)
                    ? () => _goToPage(context, index + 1)
                    : null,
                icon: LucideIcon(
                  LucideGlyph.chevronRight,
                  size: 16,
                  color: !busy && (index < lastPage || hasMore)
                      ? theme.textPrimary
                      : theme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sizeChoices(
    BuildContext context,
    B2BThemeExtension theme,
    int size,
    List<int> options,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Por vista',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        for (final option in options) ...[
          _SizeChip(
            label: '$option',
            selected: option == size,
            onTap: busy ? null : () => _changePageSize(context, option),
          ),
          if (option != options.last) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return Material(
      color: selected ? theme.brand : theme.brandContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? theme.surfaceCard : theme.brand,
            ),
          ),
        ),
      ),
    );
  }
}

/// Listado de 10 en 10, con tope de 20 por vista.
class PagedItems<T> extends StatefulWidget {
  const PagedItems({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.itemKey,
    this.resetKey,
    this.padding = EdgeInsets.zero,
    this.separator = 0,
    this.embedded = false,
    this.hasMore = false,
    this.totalCount,
    this.onNeedMore,
    this.onRefresh,
    this.pageSizeOptions = listPageSizeOptions,
    this.alwaysShow = false,
    this.pagerAtBottom = true,
    this.pageBarBuilder,
    this.pageBarBottomPadding = 10,
    this.entityLabel,
  });

  final List<T> items;
  final Widget Function(T item) itemBuilder;

  /// Id estable por fila: conserva el estado de cada tarjeta al filtrar.
  final Object Function(T item)? itemKey;
  final Object? resetKey;
  final EdgeInsetsGeometry padding;
  final double separator;

  /// Dentro de otro scroll. No crea un [ListView] propio.
  final bool embedded;
  final bool hasMore;

  /// Conteo total almacenado/filtrado. Si es null, se usa [items.length].
  final int? totalCount;
  final Future<void> Function()? onNeedMore;
  final Future<void> Function()? onRefresh;

  final List<int> pageSizeOptions;

  final bool alwaysShow;

  /// Por defecto el pie estándar va abajo.
  final bool pagerAtBottom;
  final Widget Function(Widget bar)? pageBarBuilder;
  final double pageBarBottomPadding;
  final String? entityLabel;

  @override
  State<PagedItems<T>> createState() => _PagedItemsState<T>();
}

class _PagedItemsState<T> extends State<PagedItems<T>> {
  int _pageIndex = 0;
  late int _pageSize;
  bool _pagingBusy = false;

  @override
  void initState() {
    super.initState();
    _pageSize = widget.pageSizeOptions.isEmpty
        ? listPageSizeOptions.first
        : widget.pageSizeOptions.first;
  }

  @override
  void didUpdateWidget(PagedItems<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetKey != oldWidget.resetKey) _pageIndex = 0;
  }

  Future<void> _setPage(int index) async {
    final targetTotal = listPagerTotal(
      loaded: widget.items.length,
      matching: widget.totalCount,
    );
    final next = clampListPageIndex(
      pageIndex: index,
      total: targetTotal,
      pageSize: _pageSize,
    );
    final needed = (next + 1) * _pageSize;
    final needsFetch = widget.onNeedMore != null &&
        widget.hasMore &&
        widget.items.length < needed;
    if (needsFetch && mounted) setState(() => _pagingBusy = true);
    try {
      while (widget.onNeedMore != null &&
          widget.hasMore &&
          widget.items.length < needed) {
        final before = widget.items.length;
        await widget.onNeedMore!();
        if (!mounted) return;
        if (widget.items.length <= before) break;
      }
    } finally {
      if (mounted && _pagingBusy) setState(() => _pagingBusy = false);
    }
    if (!mounted) return;
    setState(() {
      _pageIndex = clampListPageIndex(
        pageIndex: next,
        total: listPagerTotal(
          loaded: widget.items.length,
          matching: widget.totalCount,
        ),
        pageSize: _pageSize,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = sliceListPage(
      items: widget.items,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );
    final bar = ListPageBar(
      total: listPagerTotal(
        loaded: widget.items.length,
        matching: widget.totalCount,
      ),
      hasMore: widget.hasMore,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
      onPageIndex: (index) => _setPage(index),
      onPageSize: (size) => setState(() {
        _pageSize = size;
        _pageIndex = 0;
      }),
      pageSizeOptions: widget.pageSizeOptions,
      alwaysShow: widget.alwaysShow,
      entityLabel: widget.entityLabel,
      bottomPadding: widget.pageBarBottomPadding,
      busy: _pagingBusy,
    );
    Widget buildItem(int i) {
      final item = page[i];
      final child = widget.itemBuilder(item);
      final keyOf = widget.itemKey;
      return KeyedSubtree(
        key: keyOf == null ? null : ValueKey<Object>(keyOf(item)),
        child: i > 0 && widget.separator > 0
            ? Padding(
                padding: EdgeInsets.only(top: widget.separator),
                child: child,
              )
            : child,
      );
    }

    final resolved = widget.padding.resolve(Directionality.of(context));
    final inset = Padding(
      padding: EdgeInsets.only(left: resolved.left, right: resolved.right),
      child: bar,
    );
    final barInset = widget.pageBarBuilder?.call(inset) ?? inset;
    if (widget.embedded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.pagerAtBottom) barInset,
          for (var i = 0; i < page.length; i++) buildItem(i),
          if (widget.pagerAtBottom) barInset,
        ],
      );
    }
    Widget list = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: widget.padding,
      itemCount: page.length,
      findChildIndexCallback: widget.itemKey == null
          ? null
          : (key) {
              if (key is! ValueKey<Object>) return null;
              final index =
                  page.indexWhere((e) => widget.itemKey!(e) == key.value);
              return index < 0 ? null : index;
            },
      itemBuilder: (context, i) => buildItem(i),
    );
    if (widget.onRefresh != null) {
      list = RefreshIndicator(onRefresh: widget.onRefresh!, child: list);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.pagerAtBottom) barInset,
        Expanded(child: list),
        if (widget.pagerAtBottom) barInset,
      ],
    );
  }
}
