import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/product_image_bulk_result.dart';
import '../services/product_image_bulk_orchestrator.dart';
import '../services/product_image_bulk_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/product_images.dart';

/// Carga masiva de fotos: ZIP con archivos nombrados por SKU.
class ImporterBulkPhotosScreen extends StatefulWidget {
  const ImporterBulkPhotosScreen({super.key});

  static Future<ProductImageBulkResult?> open(BuildContext context) {
    return Navigator.of(context).push<ProductImageBulkResult>(
      MaterialPageRoute(builder: (_) => const ImporterBulkPhotosScreen()),
    );
  }

  @override
  State<ImporterBulkPhotosScreen> createState() =>
      _ImporterBulkPhotosScreenState();
}

class _ImporterBulkPhotosScreenState extends State<ImporterBulkPhotosScreen> {
  ProductImageBulkPreview? _preview;
  Map<String, ProductSkuImageIndexEntry> _skuIndex = {};
  ProductImageBulkMergeMode _mode = ProductImageBulkMergeMode.replace;
  bool _loading = false;
  bool _importing = false;
  int _progressDone = 0;
  int _progressTotal = 0;
  String? _fileName;

  Future<void> _pickZip() async {
    setState(() {
      _loading = true;
      _preview = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw StateError('No se pudieron leer los datos del ZIP.');
      }

      final index = await SupabaseService.fetchMyInventorySkuImageIndex();
      final preview = ProductImageBulkService.parseZipBytes(
        bytes,
        knownSkuKeys: index.keys.toSet(),
      );

      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _skuIndex = index;
        _preview = preview;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _runImport() async {
    final preview = _preview;
    if (preview == null || preview.files.isEmpty) return;

    final matched = preview.bySku.keys
        .where((k) => !preview.unknownSkus.any((u) => u.toLowerCase() == k))
        .where((k) => !preview.overLimitSkus.any((u) => u.toLowerCase() == k))
        .length;

    if (matched == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay SKUs del ZIP que coincidan con tu inventario.'),
        ),
      );
      return;
    }

    setState(() {
      _importing = true;
      _progressDone = 0;
      _progressTotal = matched;
    });

    try {
      final result = await ProductImageBulkOrchestrator.execute(
        preview: preview,
        skuIndex: _skuIndex,
        mode: _mode,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _progressDone = done;
            _progressTotal = total;
          });
        },
      );

      if (!mounted) return;
      setState(() => _importing = false);
      await _showResult(result);
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _showResult(ProductImageBulkResult result) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fotos importadas'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Productos actualizados: ${result.updated}'),
              Text('Omitidos: ${result.skipped}'),
              if (result.errorCount > 0)
                Text('Errores: ${result.errorCount}'),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'Detalle:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                ...result.errors.take(10).map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${e.sku != null ? '${e.sku}: ' : ''}${e.message}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Carga masiva de fotos'),
        backgroundColor: AppColors.surfaceTinted,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _infoCard(),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (preview == null)
                  _pickCard()
                else ...[
                  _summaryCard(preview),
                  const SizedBox(height: 16),
                  _modeSelector(),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _importing ? null : _runImport,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandBlue,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Subir fotos'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _importing ? null : _pickZip,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Elegir otro ZIP'),
                  ),
                ],
              ],
            ),
          ),
          if (_importing) _progressOverlay(),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandBlueContainer.withOpacity(0.35),
        borderRadius: AppDecorations.radius12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nombra las fotos como tu SKU',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            '• ABC123.jpg → foto principal\n'
            '• ABC123_2.jpg → segunda foto\n'
            '• ABC123_3.jpg → tercera foto (máx. 3 por producto)',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickCard() {
    return Material(
      color: AppColors.brandBlue.withOpacity(0.06),
      borderRadius: AppDecorations.radius12,
      child: InkWell(
        borderRadius: AppDecorations.radius12,
        onTap: _pickZip,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: AppDecorations.radius12,
            border: Border.all(
              color: AppColors.brandBlue.withOpacity(0.35),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: AppColors.brandBlue.withOpacity(0.85),
              ),
              const SizedBox(height: 12),
              const Text(
                'Elegir archivo ZIP',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Comprime las fotos de tu proveedor en un .zip',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(ProductImageBulkPreview preview) {
    final matched = preview.bySku.length -
        preview.unknownSkus.length -
        preview.overLimitSkus.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDecorations.radius12,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _fileName ?? 'Archivo ZIP',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _statRow(Icons.image_outlined, '${preview.files.length} fotos'),
          _statRow(Icons.inventory_2_outlined, '${preview.skuCount} SKUs'),
          _statRow(
            Icons.check_circle_outline,
            '$matched listos para subir',
            color: AppColors.successGreen,
          ),
          if (preview.unknownSkus.isNotEmpty)
            _statRow(
              Icons.help_outline,
              '${preview.unknownSkus.length} SKU sin producto en inventario',
              color: Colors.orange.shade800,
            ),
          if (preview.overLimitSkus.isNotEmpty)
            _statRow(
              Icons.warning_amber_outlined,
              '${preview.overLimitSkus.length} SKU con más de 3 fotos',
              color: Colors.red.shade700,
            ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '¿Qué hacer con las fotos actuales?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ...ProductImageBulkMergeMode.values.map((mode) {
          final selected = _mode == mode;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected
                  ? AppColors.brandBlue.withOpacity(0.08)
                  : AppColors.fieldFill,
              borderRadius: AppDecorations.radius12,
              child: InkWell(
                borderRadius: AppDecorations.radius12,
                onTap: _importing ? null : () => setState(() => _mode = mode),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: AppDecorations.radius12,
                    border: Border.all(
                      color: selected
                          ? AppColors.brandBlue.withOpacity(0.4)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              mode.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Radio<ProductImageBulkMergeMode>(
                        value: mode,
                        groupValue: _mode,
                        onChanged: _importing
                            ? null
                            : (v) {
                                if (v != null) setState(() => _mode = v);
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _progressOverlay() {
    return ColoredBox(
      color: Colors.black.withOpacity(0.35),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Subiendo fotos… $_progressDone / $_progressTotal',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
