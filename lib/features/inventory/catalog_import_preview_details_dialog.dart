import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:motolink_pro_app/app/theme/app_theme.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/layout/list_page_bar.dart';
import 'catalog_import/catalog_import_result.dart';

enum CatalogImportPreviewPanelSize { compact, full }

/// Resultado al cerrar el modal de detalles de carga.
enum CatalogImportPreviewDetailsAction {
  /// Cierra y sigue en el wizard de mapeo/importación.
  continueImport,

  /// Solo cierra el modal.
  dismiss,
}

/// Modal compacto para revisar el archivo: desglose, búsqueda, paginado 10/20.
Future<CatalogImportPreviewDetailsAction?> showCatalogImportPreviewDetailsDialog({
  required BuildContext context,
  required CatalogImportPreview preview,
  required String fileName,
  required Set<String> coreHeaders,
  required Set<String> erpHeaders,
}) {
  return showGeneralDialog<CatalogImportPreviewDetailsAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withOpacity(0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return CatalogImportPreviewDetailsDialog(
        preview: preview,
        fileName: fileName,
        coreHeaders: coreHeaders,
        erpHeaders: erpHeaders,
      );
    },
    transitionBuilder: (ctx, animation, secondary, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class CatalogImportPreviewDetailsDialog extends StatefulWidget {
  const CatalogImportPreviewDetailsDialog({
    super.key,
    required this.preview,
    required this.fileName,
    required this.coreHeaders,
    required this.erpHeaders,
  });

  final CatalogImportPreview preview;
  final String fileName;
  final Set<String> coreHeaders;
  final Set<String> erpHeaders;

  @override
  State<CatalogImportPreviewDetailsDialog> createState() =>
      _CatalogImportPreviewDetailsDialogState();
}

class _CatalogImportPreviewDetailsDialogState
    extends State<CatalogImportPreviewDetailsDialog> {
  /// Compacto por defecto: más filas visibles y menos ruido.
  CatalogImportPreviewPanelSize _panelSize =
      CatalogImportPreviewPanelSize.compact;
  int _pageIndex = 0;
  int _pageSize = 10;
  String _query = '';
  final _searchController = TextEditingController();
  final _verticalScroll = ScrollController();
  final _horizontalScroll = ScrollController();

  bool get _isFull => _panelSize == CatalogImportPreviewPanelSize.full;

  List<Map<String, String>> get _filteredRows {
    final q = _query.trim().toLowerCase();
    final rows = widget.preview.sampleRows;
    if (q.isEmpty) return rows;
    return [
      for (final row in rows)
        if (row.values.any((v) => v.toLowerCase().contains(q))) row,
    ];
  }

  List<Map<String, String>> get _pageRows => sliceListPage(
        items: _filteredRows,
        pageIndex: _pageIndex,
        pageSize: _pageSize,
      );

  int get _unassignedCount {
    var n = 0;
    for (final h in widget.preview.headers) {
      if (!widget.coreHeaders.contains(h) && !widget.erpHeaders.contains(h)) {
        n++;
      }
    }
    return n;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verticalScroll.dispose();
    _horizontalScroll.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      _pageIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final desktop = size.width >= AppBreakpoints.b2bDesktop;
    final maxW = desktop
        ? (_isFull
            ? math.min(size.width * 0.9, 1080.0)
            : math.min(size.width * 0.78, 880.0))
        : size.width - 20;
    final maxH = _isFull ? size.height * 0.9 : size.height * 0.78;

    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: maxW,
            height: maxH,
            margin: EdgeInsets.symmetric(
              horizontal: desktop ? 12 : 10,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withOpacity(0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const Divider(height: 1),
                  Expanded(child: _tablePane()),
                  _paginationBar(),
                  const Divider(height: 1),
                  _stickyFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final estimate = widget.preview.totalDataRowsEstimate;
    final loaded = widget.preview.sampleRows.length;
    final truncated = estimate != null && estimate > loaded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.table_chart_outlined,
                  color: AppColors.brandBlue, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalles de la carga',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _panelSizeToggle(),
              IconButton(
                tooltip: 'Cerrar',
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(
                  CatalogImportPreviewDetailsAction.dismiss,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatChip(
                icon: Icons.view_column_outlined,
                label: '${widget.preview.headers.length} columnas',
              ),
              _StatChip(
                icon: Icons.inventory_2_outlined,
                label: truncated
                    ? '$loaded de $estimate filas'
                    : '${estimate ?? loaded} filas',
              ),
              _StatChip(
                icon: Icons.storefront_outlined,
                label: '${widget.coreHeaders.length} clave(s)',
                tone: _ChipTone.core,
              ),
              _StatChip(
                icon: Icons.dataset_outlined,
                label: '${widget.erpHeaders.length} extra(s)',
                tone: _ChipTone.erp,
              ),
              if (_unassignedCount > 0)
                _StatChip(
                  icon: Icons.link_off_rounded,
                  label: '$_unassignedCount sin asignar',
                  tone: _ChipTone.muted,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            onChanged: _setQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Filtrar por SKU, nombre u otra celda…',
              hintStyle: AppColors.hintStyle,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _searchController.clear();
                        _setQuery('');
                      },
                      icon: const Icon(Icons.clear, size: 18),
                    ),
              filled: true,
              fillColor: AppColors.fieldFill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.borderSubtle),
              ),
            ),
          ),
          if (truncated) ...[
            const SizedBox(height: 6),
            Text(
              'Vista limitada a $loaded filas por rendimiento. '
              'La importación usa el archivo completo.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _panelSizeToggle() {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: SegmentedButton<CatalogImportPreviewPanelSize>(
        segments: const [
          ButtonSegment(
            value: CatalogImportPreviewPanelSize.compact,
            tooltip: 'Panel compacto',
            icon: Icon(Icons.view_compact_outlined, size: 16),
          ),
          ButtonSegment(
            value: CatalogImportPreviewPanelSize.full,
            tooltip: 'Vista completa',
            icon: Icon(Icons.open_in_full_rounded, size: 16),
          ),
        ],
        selected: {_panelSize},
        onSelectionChanged: (next) {
          if (next.isEmpty) return;
          setState(() => _panelSize = next.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ),
    );
  }

  Widget _tablePane() {
    final headers = widget.preview.headers;
    final rows = _pageRows;
    if (headers.isEmpty) {
      return const Center(
        child: Text('No se detectaron columnas en el archivo.'),
      );
    }
    if (_filteredRows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _query.trim().isEmpty
                ? 'No hay filas para mostrar.'
                : 'Ninguna fila coincide con “$_query”.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final dense = !_isFull;
    final headingH = dense ? 32.0 : 40.0;
    final rowMin = dense ? 28.0 : 34.0;
    final rowMax = dense ? 40.0 : 52.0;
    final fontSize = dense ? 11.0 : 12.0;
    final columnSpacing = dense ? 12.0 : 18.0;

    final table = DataTable(
      headingRowColor: WidgetStateProperty.all(
        AppColors.brandBlueContainer.withOpacity(0.4),
      ),
      headingRowHeight: headingH,
      dataRowMinHeight: rowMin,
      dataRowMaxHeight: rowMax,
      columnSpacing: columnSpacing,
      horizontalMargin: dense ? 8 : 14,
      columns: [
        DataColumn(
          label: Text(
            '#',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        for (final h in headers)
          DataColumn(
            label: _HeaderChip(
              label: h,
              color: _headerColor(h),
              icon: widget.coreHeaders.contains(h)
                  ? Icons.storefront_outlined
                  : widget.erpHeaders.contains(h)
                      ? Icons.dataset_outlined
                      : null,
              fontSize: fontSize,
            ),
          ),
      ],
      rows: [
        for (var i = 0; i < rows.length; i++)
          DataRow(
            cells: [
              DataCell(
                Text(
                  '${_pageIndex * _pageSize + i + 1}',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              for (final h in headers)
                DataCell(
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: dense ? 140 : 200,
                    ),
                    child: Text(
                      rows[i][h] ?? '',
                      style: TextStyle(
                        fontSize: fontSize,
                        color: widget.coreHeaders.contains(h) ||
                                widget.erpHeaders.contains(h)
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: dense ? 1 : 2,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderSubtle),
          color: AppColors.surfaceTinted.withOpacity(0.28),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Scrollbar(
            controller: _horizontalScroll,
            thumbVisibility: true,
            trackVisibility: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _horizontalScroll,
              scrollDirection: Axis.horizontal,
              child: Scrollbar(
                controller: _verticalScroll,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalScroll,
                  child: table,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paginationBar() {
    final total = _filteredRows.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      child: ListPageBar(
        total: total,
        pageIndex: _pageIndex,
        pageSize: _pageSize,
        alwaysShow: total > 0,
        pageSizeOptions: listPageSizeOptions,
        onPageIndex: (index) => setState(() => _pageIndex = index),
        onPageSize: (size) => setState(() {
          _pageSize = size;
          _pageIndex = 0;
        }),
      ),
    );
  }

  Color _headerColor(String h) {
    if (widget.coreHeaders.contains(h)) return AppColors.brandBlue;
    if (widget.erpHeaders.contains(h)) return AppColors.brandAccent;
    return AppColors.textPrimary;
  }

  Widget _stickyFooter() {
    return Material(
      color: AppColors.surfaceTinted,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(
                  CatalogImportPreviewDetailsAction.dismiss,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                child: const Text('Volver'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  CatalogImportPreviewDetailsAction.continueImport,
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChipTone { neutral, core, erp, muted }

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    this.tone = _ChipTone.neutral,
  });

  final IconData icon;
  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    switch (tone) {
      case _ChipTone.core:
        fg = AppColors.brandBlue;
        bg = AppColors.brandBlueContainer.withOpacity(0.55);
      case _ChipTone.erp:
        fg = AppColors.brandAccent;
        bg = AppColors.brandAccent.withOpacity(0.12);
      case _ChipTone.muted:
        fg = AppColors.textSecondary;
        bg = AppColors.fieldFill;
      case _ChipTone.neutral:
        fg = AppColors.textPrimary;
        bg = AppColors.surfaceTinted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.label,
    required this.color,
    required this.fontSize,
    this.icon,
  });

  final String label;
  final Color color;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
