import 'package:flutter/material.dart';

import 'catalog_import_photos.dart';
import 'catalog_photo_processing.dart';
import 'catalog_photo_editor.dart';
import 'product_images.dart';

class CatalogImportPhotoReview extends StatefulWidget {
  const CatalogImportPhotoReview({
    super.key,
    required this.drafts,
    required this.targets,
    required this.invalidEntries,
    this.originLabel = 'Excel',
  });

  final List<CatalogPhotoDraft> drafts;
  final Map<String, CatalogPhotoTarget> targets;
  final List<String> invalidEntries;
  final String originLabel;

  @override
  State<CatalogImportPhotoReview> createState() =>
      _CatalogImportPhotoReviewState();
}

class _CatalogImportPhotoReviewState extends State<CatalogImportPhotoReview> {
  late final _drafts = widget.drafts.toList();
  bool _pendingOnly = false;
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

  @override
  Widget build(BuildContext context) {
    final errors = CatalogPhotoDraft.assignmentErrors(_drafts, widget.targets);
    final approved = _drafts.where((draft) => draft.approved).length;
    final batch = [
      for (var i = 0; i < _drafts.length; i++)
        if (_drafts[i].approved && _drafts[i].edited == null) i,
    ];
    final visible = [
      for (var i = 0; i < _drafts.length; i++)
        if (!_pendingOnly ||
            _adjustmentFailures.contains(i) ||
            !_drafts[i].approved ||
            errors.containsKey(_drafts[i].skuKey))
          i,
    ];
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_batchRunning,
      child: Scaffold(
        appBar: AppBar(title: const Text('Revisar fotos del catálogo')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$approved de ${_drafts.length} fotos incluidas',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text('Asigna cada foto a un SKU del archivo. '
                          'Para variantes, usa el SKU de la variante.'),
                      if (widget.invalidEntries.isNotEmpty)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                              'Avisos de lectura (${widget.invalidEntries.length})'),
                          children: [
                            for (final item in widget.invalidEntries.take(20))
                              ListTile(dense: true, title: Text(item)),
                            if (widget.invalidEntries.length > 20)
                              const ListTile(
                                  dense: true,
                                  title: Text('Se muestran los primeros 20.')),
                          ],
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: const Text('Solo pendientes'),
                            selected: _pendingOnly,
                            onSelected: (value) =>
                                setState(() => _pendingOnly = value),
                          ),
                          if (batch.length > 1 || _batchRunning)
                            TextButton.icon(
                              onPressed: _batchRunning
                                  ? null
                                  : () => _editBatch(batch),
                              icon: const Icon(Icons.tune),
                              label: const Text('Ajustar varias fotos'),
                            ),
                        ],
                      ),
                      if (_batchRunning) ...[
                        const LinearProgressIndicator(),
                        const Text('Aplicando ajustes a las fotos…'),
                      ],
                      if (_adjustmentFailures.isNotEmpty)
                        Text(
                          '${_adjustmentFailures.length} fotos conservaron el original. '
                          'Filtra las pendientes para revisarlas.',
                          style: TextStyle(color: colors.error),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Text(_drafts.isEmpty
                              ? 'No hay fotos utilizables para revisar.'
                              : 'Todas las fotos están revisadas.'))
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          findChildIndexCallback: (key) {
                            if (key is! ValueKey<int>) return null;
                            final index = visible.indexOf(key.value);
                            return index < 0 ? null : index * 2;
                          },
                          itemBuilder: (context, index) {
                            final position = visible[index];
                            final draft = _drafts[position];
                            return _PhotoAssignment(
                              key: ValueKey(position),
                              draft: draft,
                              targets: widget.targets,
                              originLabel: widget.originLabel,
                              error: errors[draft.skuKey],
                              adjustmentFailed:
                                  _adjustmentFailures.contains(position),
                              onChanged: _batchRunning
                                  ? null
                                  : (value) => _change(position, value),
                              onEdit: _batchRunning
                                  ? null
                                  : () => _editOne(position),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      border:
                          Border(top: BorderSide(color: colors.outlineVariant)),
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
        ),
      ),
    );
  }
}

class _PhotoAssignment extends StatelessWidget {
  const _PhotoAssignment({
    super.key,
    required this.draft,
    required this.targets,
    required this.onChanged,
    required this.onEdit,
    required this.adjustmentFailed,
    required this.originLabel,
    this.error,
  });

  final CatalogPhotoDraft draft;
  final Map<String, CatalogPhotoTarget> targets;
  final String? error;
  final ValueChanged<CatalogPhotoDraft>? onChanged;
  final VoidCallback? onEdit;
  final bool adjustmentFailed;
  final String originLabel;

  @override
  Widget build(BuildContext context) {
    final target = targets[draft.skuKey];
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
    final helper = error ??
        (target == null
            ? 'Escribe el SKU que corresponde a esta foto.'
            : target.available
                ? productName
                : 'Este repuesto ya tiene foto o está omitido.');
    final name = draft.file.pathInZip;
    final origin = draft.workbookPhoto;
    final sourceRow = origin?.sourceRow;
    final source = origin == null
        ? null
        : sourceRow == null
            ? '$originLabel · Sin fila asociada'
            : origin.singleRow
                ? '$originLabel · Fila $sourceRow'
                : '$originLabel · Desde fila $sourceRow · Asignación manual';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ColoredBox(
              color: Colors.white,
              child: Image.memory(
                draft.edited?.bytes ?? draft.file.bytes,
                width: 64,
                height: 64,
                cacheWidth: 128,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => SizedBox.square(
                  dimension: 64,
                  child: Icon(Icons.broken_image_outlined, color: colors.error),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
                if (source != null)
                  Text(source, style: Theme.of(context).textTheme.bodySmall),
                if (adjustmentFailed)
                  Text('No se pudo aplicar el ajuste. Se conserva el original.',
                      style: TextStyle(color: colors.error)),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: draft.sku,
                  decoration: const InputDecoration(
                    labelText: 'SKU del repuesto',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  enabled: onChanged != null,
                  onChanged: (value) => onChanged?.call(
                    draft.copyWith(sku: value, approved: false),
                  ),
                ),
                const SizedBox(height: 4),
                Text(helper,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: error == null
                              ? colors.onSurfaceVariant
                              : colors.error,
                        )),
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<int>(
                      value: draft.slot,
                      onChanged: onChanged == null
                          ? null
                          : (value) {
                              if (value != null) {
                                onChanged?.call(draft.copyWith(slot: value));
                              }
                            },
                      items: [
                        for (var slot = 1; slot <= kMaxProductImages; slot++)
                          DropdownMenuItem(
                            value: slot,
                            child: Text(slot == 1 ? 'Portada' : 'Foto $slot'),
                          ),
                      ],
                    ),
                    FilterChip(
                      label: const Text('Incluir'),
                      selected: draft.approved,
                      onSelected: onChanged != null &&
                              (target?.available == true || draft.approved)
                          ? (value) =>
                              onChanged?.call(draft.copyWith(approved: value))
                          : null,
                    ),
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(draft.edited == null
                          ? 'Editar foto'
                          : 'Foto editada'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
