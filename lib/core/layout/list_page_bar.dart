import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/app_theme.dart';

/// Opciones de filas por vista. El máximo es 20.
const listPageSizeOptions = <int>[10, 20];

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

/// Barra de página para listados de usuarios. No se muestra si caben en 10.
class ListPageBar extends StatelessWidget {
  const ListPageBar({
    super.key,
    required this.total,
    required this.pageIndex,
    required this.pageSize,
    required this.onPageIndex,
    required this.onPageSize,
    this.hasMore = false,
    this.pageSizeOptions = listPageSizeOptions,
    this.alwaysShow = false,
  });

  final int total;
  final int pageIndex;
  final int pageSize;
  final ValueChanged<int> onPageIndex;
  final ValueChanged<int> onPageSize;

  /// Hay filas que todavía no están en [total]. Mantiene activa la flecha siguiente.
  final bool hasMore;

  /// Si solo hay un tamaño, se ocultan los chips y queda el rango.
  final List<int> pageSizeOptions;

  /// Muestra la barra aunque la lista quepa en una página.
  final bool alwaysShow;

  @override
  Widget build(BuildContext context) {
    final options = pageSizeOptions.isEmpty
        ? listPageSizeOptions
        : pageSizeOptions;
    final smallest = options.reduce(math.min);
    if (total <= 0 ||
        (!alwaysShow && total <= smallest && !hasMore)) {
      return const SizedBox.shrink();
    }

    final size = options.contains(pageSize) ? pageSize : options.first;
    final index = clampListPageIndex(
      pageIndex: pageIndex,
      total: total,
      pageSize: size,
    );
    final start = index * size + 1;
    final end = math.min(start + size - 1, total);
    final lastPage = total <= 0 ? 0 : ((total - 1) / size).floor();
    final showSizes = options.length > 1;
    final pager = _pager(
      label: '$start–$end de $total',
      canBack: index > 0,
      canForward: index < lastPage || hasMore,
      onBack: () => onPageIndex(index - 1),
      onForward: () => onPageIndex(index + 1),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (showSizes) _sizeChoices(size, options),
          const Spacer(),
          pager,
        ],
      ),
    );
  }

  Widget _sizeChoices(int size, List<int> options) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Por vista',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        for (final option in options) ...[
          _SizeChip(
            label: '$option',
            selected: option == size,
            onTap: () => onPageSize(option),
          ),
          if (option != options.last) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _pager({
    required String label,
    required bool canBack,
    required bool canForward,
    required VoidCallback onBack,
    required VoidCallback onForward,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.chevron_left,
          tooltip: 'Anterior',
          onPressed: canBack ? onBack : null,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        _StepButton(
          icon: Icons.chevron_right,
          tooltip: 'Siguiente',
          onPressed: canForward ? onForward : null,
        ),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brand : AppColors.brandBlueContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.white : AppColors.brand,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: Icon(icon, size: 20, color: AppColors.brand),
    );
  }
}

/// Listado de 10 en 10, con tope de 20 por vista.
class PagedItems<T> extends StatefulWidget {
  const PagedItems({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.resetKey,
    this.padding = EdgeInsets.zero,
    this.separator = 0,
    this.embedded = false,
    this.hasMore = false,
    this.onNeedMore,
    this.onRefresh,
    this.pageSizeOptions = listPageSizeOptions,
    this.alwaysShow = false,
  });

  final List<T> items;
  final Widget Function(T item) itemBuilder;
  final Object? resetKey;
  final EdgeInsetsGeometry padding;
  final double separator;

  /// Dentro de otro scroll. No crea un [ListView] propio.
  final bool embedded;
  final bool hasMore;
  final Future<void> Function()? onNeedMore;
  final Future<void> Function()? onRefresh;

  /// Tamaños ofrecidos. Con uno solo no se muestran los chips.
  final List<int> pageSizeOptions;

  /// Muestra «Por vista» aunque la lista quepa en una página.
  final bool alwaysShow;

  @override
  State<PagedItems<T>> createState() => _PagedItemsState<T>();
}

class _PagedItemsState<T> extends State<PagedItems<T>> {
  int _pageIndex = 0;
  late int _pageSize;

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
    final needed = (index + 1) * _pageSize;
    if (widget.onNeedMore != null &&
        widget.hasMore &&
        widget.items.length < needed) {
      await widget.onNeedMore!();
    }
    if (!mounted) return;
    setState(() => _pageIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final page = sliceListPage(
      items: widget.items,
      pageIndex: _pageIndex,
      pageSize: _pageSize,
    );
    final bar = ListPageBar(
      total: widget.items.length,
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
    );
    final children = <Widget>[
      for (var i = 0; i < page.length; i++) ...[
        if (i > 0 && widget.separator > 0) SizedBox(height: widget.separator),
        widget.itemBuilder(page[i]),
      ],
    ];
    final resolved = widget.padding.resolve(Directionality.of(context));
    final barInset = Padding(
      padding: EdgeInsets.only(left: resolved.left, right: resolved.right),
      child: bar,
    );
    if (widget.embedded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          barInset,
          ...children,
        ],
      );
    }
    Widget list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: widget.padding,
      children: children,
    );
    if (widget.onRefresh != null) {
      list = RefreshIndicator(onRefresh: widget.onRefresh!, child: list);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        barInset,
        Expanded(child: list),
      ],
    );
  }
}
