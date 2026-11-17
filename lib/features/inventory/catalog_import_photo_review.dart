import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'package:motolink_pro_app/core/layout/app_breakpoints.dart';
import 'package:motolink_pro_app/core/widgets/product_photo_lightbox.dart';
import 'catalog_import_photos.dart';
import 'catalog_photo_processing.dart';
import 'catalog_photo_editor.dart';
import 'product_images.dart';

class CatalogImportPhotoReview extends StatefulWidget {
  const CatalogImportPhotoReview({
    super.key,
    required this.drafts,
    required this.targets,
    this.catalog = const [],
    required this.invalidEntries,
  });

  final List<CatalogPhotoDraft> drafts;
  final Map<String, CatalogPhotoTarget> targets;
  final List<CatalogSkuChoice> catalog;
  final List<String> invalidEntries;

  /// Se recuerda entre aperturas y cambios de tamaño.
  static bool rememberPendingOnly = true;

  @override
  State<CatalogImportPhotoReview> createState() =>
      _CatalogImportPhotoReviewState();
}

class _CatalogImportPhotoReviewState extends State<CatalogImportPhotoReview> {
  late final _drafts = widget.drafts.toList();
  bool _pendingOnly = CatalogImportPhotoReview.rememberPendingOnly;
  bool _batchRunning = false;
  final _adjustmentFailures = <int>{};

  Future<void> _editOne(int index) async {
    final draft = _drafts[index];
    final result = await Navigator.of(context).push<CatalogPhotoEditorResult>(
      MaterialPageRoute(
          builder: (_) => CatalogPhotoEditor(
                original: draft.file.bytes,
                current: draft.edited?.bytes,
              )),
    );
    if (!mounted || result == null) return;
    setState(() {
      _drafts[index] = draft.copyWith(
        edited: result.edited,
        restoreOriginal: result.restore,
      );
      _adjustmentFailures.remove(index);
    });
  }

  Future<void> _editBatch(List<int> indices) async {
    final first = _drafts[indices.first];
    final result = await Navigator.of(context).push<CatalogPhotoEditorResult>(
      MaterialPageRoute(
          builder: (_) => CatalogPhotoEditor(
                original: first.file.bytes,
                batchCount: indices.length,
              )),
    );
    if (!mounted || result == null) return;
    setState(() => _batchRunning = true);
    for (final index in indices) {
      final draft = _drafts[index];
      try {
        final edited = await renderCatalogBatchPhoto(
          draft.file.bytes,
          result.adjustments,
        );
        if (!mounted) return;
        setState(() {
          _drafts[index] = draft.copyWith(edited: edited);
          _adjustmentFailures.remove(index);
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _adjustmentFailures.add(index));
      }
    }
    if (mounted) setState(() => _batchRunning = false);
  }

  void _change(int index, CatalogPhotoDraft draft) {
    setState(() => _drafts[index] = draft);
  }

  bool _hasValidSku(CatalogPhotoDraft draft) {
    if (draft.sku.trim().isEmpty) return false;
    final target = widget.targets[draft.skuKey];
    return target?.available == true;
  }

  void _includeAllWithSku() {
    setState(() {
      for (var i = 0; i < _drafts.length; i++) {
        final draft = _drafts[i];
        if (!draft.approved && _hasValidSku(draft)) {
          _drafts[i] = draft.copyWith(approved: true);
        }
      }
    });
  }

  void _clearAllIncluded() {
    setState(() {
      for (var i = 0; i < _drafts.length; i++) {
        final draft = _drafts[i];
        if (draft.approved) _drafts[i] = draft.copyWith(approved: false);
      }
    });
  }

  int _sourceRow(int index) => _drafts[index].workbookPhoto?.sourceRow ?? 1 << 20;

  Future<void> _openZoom(int position) {
    final errors = CatalogPhotoDraft.assignmentErrors(_drafts, widget.targets);
    final order = [
      for (var i = 0; i < _drafts.length; i++)
        if (!_pendingOnly || _isPending(i, errors)) i,
    ]..sort((a, b) {
        final byRow = _sourceRow(a).compareTo(_sourceRow(b));
        return byRow != 0 ? byRow : a.compareTo(b);
      });
    if (!order.contains(position)) order.add(position);
    return showProductPhotoLightbox(
      context,
      slides: [
        for (final index in order)
          ProductLightboxSlide(
            image: MemoryImage(
              _drafts[index].edited?.bytes ?? _drafts[index].file.bytes,
            ),
            caption: _zoomCaption(_drafts[index]),
          ),
      ],
      initialIndex: order.indexOf(position),
      productName: 'Revisar fotos',
    );
  }

  String _zoomCaption(CatalogPhotoDraft draft) {
    final sku = draft.sku.trim();
    final row = draft.workbookPhoto?.sourceRow;
    if (row != null && sku.isNotEmpty) return 'Fila $row · $sku';
    if (row != null) return 'Fila $row';
    if (sku.isNotEmpty) return sku;
    return 'Sin fila';
  }

  bool _isPending(int index, Map<String, String> errors) {
    final draft = _drafts[index];
    if (_adjustmentFailures.contains(index)) return true;
    if (draft.sku.trim().isEmpty) return true;
    if (!draft.approved) return true;
    return errors.containsKey(draft.skuKey);
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.mobileMenu;
    final errors = CatalogPhotoDraft.assignmentErrors(_drafts, widget.targets);
    final approved = _drafts.where((draft) => draft.approved).length;
    final readyToInclude = _drafts
        .where((draft) => !draft.approved && _hasValidSku(draft))
        .length;
    final batch = [
      for (var i = 0; i < _drafts.length; i++)
        if (_drafts[i].approved && _drafts[i].edited == null) i,
    ];
    final visible = [
      for (var i = 0; i < _drafts.length; i++)
        if (!_pendingOnly || _isPending(i, errors)) i,
    ]..sort((a, b) {
        final byRow = _sourceRow(a).compareTo(_sourceRow(b));
        return byRow != 0 ? byRow : a.compareTo(b);
      });
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_batchRunning,
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.surfaceCard,
          foregroundColor: theme.textPrimary,
          surfaceTintColor: Colors.transparent,
          title: const Text('Revisar fotos del catálogo'),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$approved de ${_drafts.length} fotos incluidas',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Asigna el SKU e incluye la foto.',
                    style: TextStyle(color: theme.textSecondary),
                  ),
                  if (widget.invalidEntries.isNotEmpty)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Avisos de lectura (${widget.invalidEntries.length})',
                        style: TextStyle(color: theme.textPrimary),
                      ),
                      children: [
                        for (final item in widget.invalidEntries.take(20))
                          ListTile(
                            dense: true,
                            title: Text(
                              item,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (widget.invalidEntries.length > 20)
                          const ListTile(
                            dense: true,
                            title: Text('Se muestran los primeros 20.'),
                          ),
                      ],
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilterChip(
                        label: Text(
                          _pendingOnly
                              ? 'Solo pendientes · ${visible.length}'
                              : 'Solo pendientes',
                        ),
                        selected: _pendingOnly,
                        showCheckmark: true,
                        selectedColor: theme.brandContainer,
                        checkmarkColor: theme.brand,
                        labelStyle: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (value) {
                          CatalogImportPhotoReview.rememberPendingOnly = value;
                          setState(() => _pendingOnly = value);
                        },
                      ),
                      FilledButton.tonal(
                        onPressed: _batchRunning || readyToInclude == 0
                            ? null
                            : _includeAllWithSku,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 36),
                          backgroundColor: theme.brandContainer,
                          foregroundColor: theme.brand,
                          disabledBackgroundColor: theme.surfaceSubtle,
                          disabledForegroundColor: theme.textMuted,
                        ),
                        child: Text(
                          'Incluir todas con SKU ($readyToInclude)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: _batchRunning || approved == 0
                            ? null
                            : _clearAllIncluded,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(0, 36),
                          foregroundColor: theme.textSecondary,
                        ),
                        child: const Text(
                          'Desmarcar todas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (batch.length > 1 || _batchRunning)
                        TextButton.icon(
                          onPressed:
                              _batchRunning ? null : () => _editBatch(batch),
                          icon: const Icon(Icons.tune),
                          label: const Text('Ajustar varias fotos'),
                        ),
                    ],
                  ),
                  if (_batchRunning) ...[
                    const LinearProgressIndicator(),
                    Text(
                      'Aplicando ajustes a las fotos…',
                      style: TextStyle(color: theme.textSecondary),
                    ),
                  ],
                  if (_adjustmentFailures.isNotEmpty)
                    Text(
                      '${_adjustmentFailures.length} fotos conservaron el original.',
                      style: TextStyle(color: colors.error),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.borderSubtle),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        _drafts.isEmpty
                            ? 'No hay fotos utilizables para revisar.'
                            : 'No hay fotos pendientes.',
                        style: TextStyle(color: theme.textSecondary),
                      ),
                    )
                  : wide
                      ? GridView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(16),
                          itemCount: visible.length,
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 420,
                            mainAxisExtent: 144,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemBuilder: (context, index) {
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.surfaceCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.borderSubtle),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                child: _photoCard(visible[index], errors),
                              ),
                            );
                          },
                        )
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.surfaceCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.borderSubtle),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                child: _photoCard(visible[index], errors),
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: theme.surfaceCard,
                  border: Border(top: BorderSide(color: theme.borderSubtle)),
                ),
                child: FilledButton(
                  onPressed: errors.isEmpty && !_batchRunning
                      ? () => Navigator.pop(context, _drafts)
                      : null,
                  child: const Text('Guardar revisión'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoCard(int position, Map<String, String> errors) {
    final draft = _drafts[position];
    return _PhotoAssignment(
      key: ValueKey(position),
      draft: draft,
      targets: widget.targets,
      catalog: widget.catalog,
      error: errors[draft.skuKey],
      adjustmentFailed: _adjustmentFailures.contains(position),
      onZoom: _batchRunning ? null : () => _openZoom(position),
      onChanged: _batchRunning ? null : (value) => _change(position, value),
      onEdit: _batchRunning ? null : () => _editOne(position),
    );
  }
}

class _PhotoAssignment extends StatefulWidget {
  const _PhotoAssignment({
    super.key,
    required this.draft,
    required this.targets,
    this.catalog = const [],
    required this.onChanged,
    required this.onEdit,
    this.onZoom,
    required this.adjustmentFailed,
    this.error,
  });

  final CatalogPhotoDraft draft;
  final Map<String, CatalogPhotoTarget> targets;
  final List<CatalogSkuChoice> catalog;
  final String? error;
  final ValueChanged<CatalogPhotoDraft>? onChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onZoom;
  final bool adjustmentFailed;

  @override
  State<_PhotoAssignment> createState() => _PhotoAssignmentState();
}

class _PhotoAssignmentState extends State<_PhotoAssignment> {
  late final TextEditingController _sku =
      TextEditingController(text: widget.draft.sku);

  @override
  void didUpdateWidget(covariant _PhotoAssignment oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft.sku != _sku.text && widget.draft.sku != oldWidget.draft.sku) {
      _sku.text = widget.draft.sku;
    }
  }

  @override
  void dispose() {
    _sku.dispose();
    super.dispose();
  }

  Future<void> _pickSku(BuildContext context) async {
    final chosen = await showCatalogSkuPicker(
      context,
      options: widget.catalog,
      current: _sku.text,
    );
    if (!mounted || chosen == null) return;
    _sku.text = chosen;
    widget.onChanged?.call(
      widget.draft.copyWith(sku: chosen, approved: widget.draft.approved),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final theme = B2BThemeExtension.of(context);
    final target = widget.targets[draft.skuKey];
    final row = target?.row;
    final colors = Theme.of(context).colorScheme;
    final variant = row?.variantAttributes.values.join(' · ');
    final productName = [
      if (row != null) row.name,
      if (variant != null && variant.isNotEmpty)
        variant
      else if (row?.variantAttributeValue case final value?)
        value,
    ].join(' · ');
    final name = draft.file.pathInZip;
    final origin = draft.workbookPhoto;
    final sourceRow = origin?.sourceRow;
    final suggested =
        draft.sourceRowBinding != null && draft.sku.trim().isNotEmpty;
    final String status;
    final Color statusColor;
    if (widget.error != null) {
      status = widget.error!;
      statusColor = colors.error;
    } else if (widget.adjustmentFailed) {
      status = 'No se pudo ajustar';
      statusColor = colors.error;
    } else if (sourceRow == null && origin != null) {
      status = 'Sin fila';
      statusColor = theme.textSecondary;
    } else if (origin != null && draft.sku.trim().isEmpty) {
      status = 'Fila $sourceRow · sin código';
      statusColor = theme.warningFg;
    } else if (suggested) {
      status = 'Sugerido · fila $sourceRow';
      statusColor = theme.brand;
    } else if (draft.sku.trim().isEmpty) {
      status = 'Sin código';
      statusColor = theme.textSecondary;
    } else {
      status = productName.isEmpty ? 'Asignado' : productName;
      statusColor = theme.textSecondary;
    }
    final bytes = draft.edited?.bytes ?? draft.file.bytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Tooltip(
              message: 'Ampliar $name',
              child: InkWell(
                onTap: widget.onZoom,
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ColoredBox(
                        color: theme.surfaceSubtle,
                        child: Image.memory(
                          bytes,
                          width: 56,
                          height: 56,
                          cacheWidth: 224,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) =>
                              SizedBox.square(
                            dimension: 56,
                            child: Icon(Icons.broken_image_outlined,
                                color: colors.error),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.surfaceCard.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.zoom_in,
                            size: 14, color: theme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _sku,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'SKU',
                      isDense: true,
                      filled: true,
                      fillColor: theme.inputFill,
                      contentPadding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: 'Buscar en el archivo',
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onChanged == null
                            ? null
                            : () => _pickSku(context),
                        icon: Icon(Icons.search, size: 18, color: theme.brand),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    enabled: widget.onChanged != null,
                    onChanged: (value) => widget.onChanged?.call(
                      draft.copyWith(sku: value, approved: draft.approved),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: Row(
            children: [
              _RolePill(
                slot: draft.slot,
                enabled: widget.onChanged != null,
                onSelected: (slot) =>
                    widget.onChanged?.call(draft.copyWith(slot: slot)),
              ),
              const Spacer(),
              _SquareAction(
                tooltip: draft.edited == null ? 'Editar foto' : 'Editada',
                icon: Icons.edit_outlined,
                emphasized: draft.edited != null,
                onPressed: widget.onEdit,
              ),
              const SizedBox(width: 6),
              _IncludeButton(
                included: draft.approved,
                enabled: widget.onChanged != null &&
                    (target?.available == true || draft.approved),
                onPressed: () => widget.onChanged?.call(
                  draft.copyWith(approved: !draft.approved),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _slotLabel(int slot) {
  if (slot <= 1) return 'Portada';
  if (slot == 2) return 'Galería';
  return 'Galería ${slot - 1}';
}

class _RolePill extends StatelessWidget {
  const _RolePill({
    required this.slot,
    required this.enabled,
    required this.onSelected,
  });

  final int slot;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    return PopupMenuButton<int>(
      tooltip: 'Rol de la foto',
      enabled: enabled,
      padding: EdgeInsets.zero,
      offset: const Offset(0, 36),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (var value = 1; value <= kMaxProductImages; value++)
          PopupMenuItem(
            value: value,
            height: 40,
            child: Text(
              _slotLabel(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surfaceSubtle,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.border),
        ),
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _slotLabel(slot),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? theme.textPrimary : theme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.expand_more, size: 16, color: theme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final color = emphasized ? theme.brand : theme.textSecondary;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 36,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: color,
            side: BorderSide(color: emphasized ? theme.brand : theme.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }
}

class _IncludeButton extends StatelessWidget {
  const _IncludeButton({
    required this.included,
    required this.enabled,
    required this.onPressed,
  });

  final bool included;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final colors = Theme.of(context).colorScheme;
    final label = Text(
      included ? 'Incluida' : 'Incluir',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );
    final icon = Icon(included ? Icons.check : Icons.add, size: 16);
    final style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
    if (included) {
      return FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: style.copyWith(
          backgroundColor: WidgetStatePropertyAll(theme.brand),
          foregroundColor: WidgetStatePropertyAll(colors.onPrimary),
        ),
        icon: icon,
        label: label,
      );
    }
    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      style: style.copyWith(
        foregroundColor: WidgetStatePropertyAll(theme.textPrimary),
        side: WidgetStatePropertyAll(BorderSide(color: theme.border)),
      ),
      icon: icon,
      label: label,
    );
  }
}

Future<String?> showCatalogSkuPicker(
  BuildContext context, {
  required List<CatalogSkuChoice> options,
  required String current,
}) {
  final theme = B2BThemeExtension.of(context);
  final mobile = MediaQuery.sizeOf(context).width < AppBreakpoints.mobileMenu;
  final picker = _SkuPicker(options: options, current: current);
  if (mobile) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.dialogSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.86,
          child: picker,
        ),
      ),
    );
  }
  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: theme.dialogSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
        ),
        child: picker,
      ),
    ),
  );
}

class _SkuPicker extends StatefulWidget {
  const _SkuPicker({required this.options, required this.current});

  final List<CatalogSkuChoice> options;
  final String current;

  @override
  State<_SkuPicker> createState() => _SkuPickerState();
}

class _SkuPickerState extends State<_SkuPicker> {
  late final TextEditingController _query =
      TextEditingController(text: widget.current);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final needle = _query.text.trim().toLowerCase();
    final matches = [
      for (final option in widget.options)
        if (needle.isEmpty ||
            option.sku.toLowerCase().contains(needle) ||
            option.name.toLowerCase().contains(needle))
          option,
    ];
    final typed = _query.text.trim();
    final exact = widget.options.any(
      (option) => option.sku.toLowerCase() == typed.toLowerCase(),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Códigos del archivo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: theme.textSecondary),
              ),
            ],
          ),
          Text(
            '${widget.options.length} códigos',
            style: TextStyle(color: theme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _query,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar código o descripción',
              isDense: true,
              filled: true,
              fillColor: theme.inputFill,
              prefixIcon: Icon(Icons.search, color: theme.textSecondary),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (typed.isNotEmpty && !exact) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.pop(context, typed),
                child: Text(
                  'Usar «$typed»',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: matches.isEmpty
                ? Center(
                    child: Text(
                      'Ningún código coincide.',
                      style: TextStyle(color: theme.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: matches.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: theme.borderSubtle),
                    itemBuilder: (context, index) {
                      final option = matches[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          option.sku,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          option.name.isEmpty ? 'Sin descripción' : option.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: theme.textSecondary),
                        ),
                        onTap: () => Navigator.pop(context, option.sku),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
