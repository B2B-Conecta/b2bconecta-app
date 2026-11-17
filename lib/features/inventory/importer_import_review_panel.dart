import 'package:flutter/material.dart';

import 'package:motolink_pro_app/app/theme/b2b_theme_extension.dart';
import 'catalog_import/catalog_import_result.dart';
import 'catalog_import_issue_scan.dart';

/// Revisión de simulación: resumen coherente y errores agrupados.
class ImporterImportReviewPanel extends StatefulWidget {
  const ImporterImportReviewPanel({
    super.key,
    required this.result,
    required this.detectedPhotos,
    required this.includedPhotos,
    required this.discardedFiles,
    required this.workbookPending,
    required this.assignmentErrors,
    required this.requirePdfConfirm,
    required this.formatError,
    required this.onEditRow,
    required this.onFillEmptyStock,
    required this.onBack,
    required this.onConfirm,
    this.onDownload,
  });

  final CatalogImportResult result;
  final int detectedPhotos;
  final int includedPhotos;
  final int discardedFiles;
  final bool workbookPending;
  final Map<String, String> assignmentErrors;
  final bool requirePdfConfirm;
  final String Function(CatalogImportRowError error) formatError;
  final Future<void> Function(CatalogImportRowError error) onEditRow;
  final ValueChanged<int> onFillEmptyStock;
  final VoidCallback onBack;
  final VoidCallback? onConfirm;
  final Future<void> Function()? onDownload;

  @override
  State<ImporterImportReviewPanel> createState() =>
      _ImporterImportReviewPanelState();
}

class _ImporterImportReviewPanelState extends State<ImporterImportReviewPanel> {
  bool _onlyErrors = true;
  bool _pdfConfirmed = false;
  bool _askingFixed = false;
  bool _downloading = false;
  final _fixedController = TextEditingController();

  @override
  void dispose() {
    _fixedController.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      widget.result.successCount > 0 &&
      widget.assignmentErrors.isEmpty &&
      (!widget.requirePdfConfirm || _pdfConfirmed);

  @override
  Widget build(BuildContext context) {
    final theme = B2BThemeExtension.of(context);
    final groups = groupCatalogImportErrors(widget.result.allErrors);
    final showPhotos = widget.detectedPhotos > 0 || widget.includedPhotos > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Revisa antes de guardar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: widget.onBack,
                icon: Icon(Icons.close, color: theme.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            children: [
              Text(
                '${widget.result.inserted} por crear · '
                '${widget.result.updated} por actualizar · '
                '${widget.result.skipped} omitidas · '
                '${widget.result.errorCount} con error',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.result.priceChanges} cambios de precio · '
                '${widget.result.stockChanges} cambios de stock',
                style: TextStyle(color: theme.textSecondary, fontSize: 13),
              ),
              if (showPhotos) ...[
                const SizedBox(height: 8),
                Text(
                  '${widget.includedPhotos}/${widget.detectedPhotos} fotos incluidas'
                  '${widget.discardedFiles == 0 ? '' : ' · ${widget.discardedFiles} descartadas'}',
                  style: TextStyle(color: theme.textSecondary, fontSize: 13),
                ),
              ],
              if (!_onlyErrors && widget.workbookPending)
                _note(
                  theme,
                  'Advertencia',
                  'Las fotos detectadas entran después de revisarlas.',
                  warning: true,
                ),
              if (!_onlyErrors && widget.assignmentErrors.isNotEmpty)
                _note(
                  theme,
                  'Advertencia',
                  'Revisa ${widget.assignmentErrors.length} asignaciones de fotos.',
                  warning: true,
                ),
              if (groups.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bloquean esa fila',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilterChip(
                      label: const Text('Solo con errores'),
                      selected: _onlyErrors,
                      onSelected: (v) => setState(() => _onlyErrors = v),
                      selectedColor: theme.brandContainer,
                      checkmarkColor: theme.brand,
                      labelStyle: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final group in groups) ...[
                  _groupCard(theme, group),
                  const SizedBox(height: 8),
                ],
              ] else
                _note(
                  theme,
                  'Listo',
                  'No hay errores. Puedes confirmar el lote.',
                  warning: false,
                ),
              if (widget.requirePdfConfirm)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _pdfConfirmed,
                  onChanged: (v) =>
                      setState(() => _pdfConfirmed = v ?? false),
                  title: Text(
                    'Revisé SKU, precio y stock del PDF.',
                    style: TextStyle(color: theme.textPrimary, fontSize: 14),
                  ),
                ),
              if (widget.onDownload != null && groups.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _downloading || widget.onDownload == null
                        ? null
                        : () async {
                            setState(() => _downloading = true);
                            await widget.onDownload!();
                            if (mounted) setState(() => _downloading = false);
                          },
                    icon: const Icon(Icons.download_outlined),
                    label: Text(
                      _downloading
                          ? 'Preparando Excel…'
                          : 'Descargar Excel revisado',
                    ),
                  ),
                ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.dialogSurface,
            border: Border(top: BorderSide(color: theme.borderSubtle)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: widget.onBack,
                  child: const Text('Volver'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _canConfirm ? widget.onConfirm : null,
                  child: const Text('Confirmar importación'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _note(
    B2BThemeExtension theme,
    String label,
    String message, {
    required bool warning,
  }) {
    final tone = warning ? theme.warningFg : theme.successFg;
    final bg = warning ? theme.warningBg : theme.successBg;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(color: theme.textPrimary, fontSize: 13, height: 1.35),
          children: [
            TextSpan(
              text: '$label · ',
              style: TextStyle(color: tone, fontWeight: FontWeight.w800),
            ),
            TextSpan(text: message),
          ],
        ),
      ),
    );
  }

  Widget _groupCard(B2BThemeExtension theme, CatalogImportErrorGroup group) {
    final preview = group.errors.take(3).toList();
    final rest = group.count - preview.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: theme.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.warningBg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${group.count}',
                  style: TextStyle(
                    color: theme.warningFg,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Bloquea esas filas. El resto del lote se puede guardar.',
            style: TextStyle(color: theme.textSecondary, fontSize: 12),
          ),
          if (group.canFillStock) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Asignar 0'),
                  onPressed: () => widget.onFillEmptyStock(0),
                ),
                ActionChip(
                  label: const Text('Stock mínimo (1)'),
                  onPressed: () => widget.onFillEmptyStock(1),
                ),
                ActionChip(
                  label: const Text('Valor fijo'),
                  onPressed: () => setState(() => _askingFixed = !_askingFixed),
                ),
              ],
            ),
            if (_askingFixed) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fixedController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Existencias',
                        filled: true,
                        fillColor: theme.inputFill,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final n = int.tryParse(_fixedController.text.trim());
                      if (n == null || n < 0) return;
                      widget.onFillEmptyStock(n);
                    },
                    child: const Text('Aplicar'),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 4),
          for (final error in preview)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                widget.formatError(error),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.textPrimary, fontSize: 13),
              ),
              trailing: Icon(Icons.edit_outlined, color: theme.textSecondary),
              onTap: () => widget.onEditRow(error),
            ),
          if (rest > 0)
            Text(
              'y $rest más del mismo tipo',
              style: TextStyle(color: theme.textMuted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
