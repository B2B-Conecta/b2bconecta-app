import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../catalog/part_model.dart';
import 'catalog_import_photo_review.dart';
import 'catalog_import_photos.dart';
import 'catalog_import_validator.dart';
import 'importer_product_edit_screen.dart';
import 'inventory_qr_assignment.dart';
import 'inventory_qr_label.dart';
import 'inventory_qr_photo_reader_native.dart'
    if (dart.library.js_interop) 'inventory_qr_photo_reader_web.dart';
import 'inventory_qr_scan_sheet.dart';
import 'inventory_service.dart';
import 'product_image_bulk_service.dart';
import 'product_images.dart';

class InventoryQrScreen extends StatefulWidget {
  const InventoryQrScreen({super.key, required this.onInventoryChanged});

  final VoidCallback onInventoryChanged;

  @override
  State<InventoryQrScreen> createState() => _InventoryQrScreenState();
}

class _InventoryQrScreenState extends State<InventoryQrScreen> {
  static const _maxPhotoBytes = 10 * 1024 * 1024;
  static const _maxBatchBytes = 100 * 1024 * 1024;
  final _selected = <String>{};
  final _drafts = <CatalogPhotoDraft>[];
  final _notices = <String>[];
  final _guidedVisited = <String>{};
  var _products = <PartModel>[];
  var _byId = <String, PartModel>{};
  var _bySku = <String, PartModel>{};
  String? _activeId;
  String? _busy;
  String _query = '';
  bool _loadFailed = false;
  bool _nextAfterCapture = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _refreshProducts() async {
    final products = <PartModel>[];
    await for (final page in InventoryService.readMyInventoryPages(
      'id,sku,name,variant_attribute_value,variant_attributes,image_urls,image_url',
    )) {
      products.addAll(page.map(PartModel.fromJson));
    }
    products.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    final skuGroups = <String, List<PartModel>>{};
    for (final part in products) {
      final key = part.sku?.trim().toLowerCase();
      if (key != null && key.isNotEmpty) {
        skuGroups.putIfAbsent(key, () => []).add(part);
      }
    }
    if (!mounted) return;
    setState(() {
      _products = products;
      _byId = {for (final part in products) part.id.toLowerCase(): part};
      _bySku = {
        for (final entry in skuGroups.entries)
          if (entry.value.length == 1) entry.key: entry.value.single,
      };
      _selected.retainAll(_byId.keys);
      _loadFailed = false;
    });
  }

  Future<void> _load() => _run('Cargando inventario…', () async {
        try {
          await _refreshProducts();
        } catch (_) {
          if (mounted) setState(() => _loadFailed = true);
          rethrow;
        }
      });

  Future<void> _run(String progress, Future<void> Function() action) async {
    if (_busy != null) return;
    setState(() => _busy = progress);
    try {
      await action();
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted)
        _message('No se pudo completar la operación. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _nextProduct() {
    if (_activeId case final id?) _guidedVisited.add(id);
    final taken = _drafts
        .where((draft) => draft.lockSku)
        .map((draft) => draft.skuKey)
        .toSet();
    final candidates = _products.where((part) {
      final sku = part.sku?.toLowerCase();
      return _bySku[sku]?.id == part.id &&
          part.imageUrls.isEmpty &&
          !taken.contains(sku);
    });
    final next = candidates
        .where((part) => !_guidedVisited.contains(part.id))
        .firstOrNull;
    setState(() => _activeId = next?.id);
    if (next == null) _message('Ya puedes revisar las tomas pendientes.');
  }

  void _startGuided() {
    _guidedVisited.clear();
    _activeId = null;
    _nextProduct();
  }

  Future<void> _scan() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const InventoryQrScanSheet(),
    );
    if (mounted && id != null) {
      await _run('Buscando el repuesto…', () => _chooseProduct(id));
    }
  }

  Future<void> _chooseProduct(String id) async {
    final part = await InventoryService.fetchMyProductById(id);
    if (!mounted) return;
    if (part == null) {
      _message('La etiqueta no corresponde a un producto de tu inventario.');
      return;
    }
    if (part.imageUrls.isNotEmpty ||
        _bySku[part.sku?.toLowerCase()]?.id != part.id) {
      final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ImporterProductEditScreen(initial: part),
      ));
      if (mounted && changed == true) {
        widget.onInventoryChanged();
        await _refreshProducts();
      }
      return;
    }
    setState(() => _activeId = part.id);
  }

  Map<String, Set<int>> _occupied() {
    final occupied = <String, Set<int>>{};
    for (final draft in _drafts.where((draft) => draft.skuKey.isNotEmpty)) {
      occupied.putIfAbsent(draft.skuKey, () => {}).add(draft.slot);
    }
    return occupied;
  }

  void _checkBatchSize(Iterable<ProductImageBulkFile> files) {
    final bytes = [..._drafts.map((draft) => draft.file), ...files]
        .fold<int>(0, (total, file) => total + file.bytes.length);
    if (bytes > _maxBatchBytes) {
      throw const FormatException(
          'El lote supera 100 MiB. Guarda las fotos en tandas.');
    }
  }

  Future<void> _capture(PartModel part, ImageSource source) =>
      _run('Preparando la toma…', () async {
        if ((_occupied()[part.sku?.toLowerCase()]?.length ?? 0) >=
            kMaxProductImages) {
          throw const FormatException(
              'Este repuesto ya tiene tres tomas por revisar.');
        }
        final image = await ImagePicker().pickImage(
          source: source,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 91,
        );
        if (image == null || !mounted) return;
        final ext = image.name.split('.').last.toLowerCase();
        if (!isAllowedProductImageExtension(ext) ||
            await image.length() > _maxPhotoBytes) {
          throw const FormatException(
              'Selecciona una imagen JPG, PNG o WebP de hasta 10 MiB.');
        }
        final file = ProductImageBulkFile(
          pathInZip: image.name,
          bytes: await image.readAsBytes(),
          extension: ext == 'jpg' ? 'jpeg' : ext,
          sku: '',
          slot: 1,
        );
        if (!mounted) return;
        _checkBatchSize([file]);
        final occupied = _occupied();
        final draft = proposeInventoryQrPhoto(
          photo: file,
          codes: [InventoryQrLabel.encode(part.id)],
          byId: _byId,
          bySku: _bySku,
          occupied: occupied,
          checkFileName: false,
        );
        setState(() => _drafts.add(draft));
        if (_nextAfterCapture) _nextProduct();
      });

  Future<void> _readBatch() => _run('Abriendo fotos o ZIP…', () async {
        final picked = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: const ['jpeg', 'jpg', 'png', 'webp', 'zip'],
          withData: true,
        );
        if (picked == null || !mounted) return;
        await _refreshProducts();
        if (!mounted) return;
        final files = <ProductImageBulkFile>[];
        final notices = <String>[];
        for (final file in picked.files) {
          final bytes = file.bytes;
          final ext = file.extension?.toLowerCase();
          if (bytes == null || bytes.isEmpty || ext == null) {
            notices.add('${file.name}: archivo sin datos.');
          } else if (ext == 'zip') {
            try {
              final zip = ProductImageBulkService.parseZipBytes(
                bytes,
                knownSkuKeys: _bySku.keys.toSet(),
                keepAmbiguousForReview: true,
              );
              files.addAll(zip.files);
              notices.addAll(zip.invalidEntries);
            } on FormatException catch (error) {
              notices.add('${file.name}: ${error.message}');
            }
          } else if (!isAllowedProductImageExtension(ext) ||
              bytes.length > _maxPhotoBytes) {
            notices.add('${file.name}: formato incompatible o supera 10 MiB.');
          } else {
            files.add(ProductImageBulkFile(
              pathInZip: file.name,
              bytes: bytes,
              extension: ext == 'jpg' ? 'jpeg' : ext,
              sku: '',
              slot: 1,
            ));
          }
          _checkBatchSize(files);
        }
        final occupied = _occupied();
        final drafts = <CatalogPhotoDraft>[];
        for (final (index, file) in files.indexed) {
          if (!mounted) return;
          setState(() => _busy = 'Leyendo QR ${index + 1} de ${files.length}…');
          try {
            final codes = await readInventoryPhotoQr(file);
            drafts.add(proposeInventoryQrPhoto(
              photo: file,
              codes: codes,
              byId: _byId,
              bySku: _bySku,
              occupied: occupied,
            ));
          } catch (_) {
            drafts.add(CatalogPhotoDraft(
                file: file,
                assignmentNote:
                    'No se pudo analizar esta foto. Asigna el SKU.'));
          }
        }
        if (!mounted) return;
        setState(() {
          _drafts.addAll(drafts);
          _notices.addAll(notices);
        });
        if (drafts.isEmpty)
          _message('El lote no contiene imágenes utilizables.');
      });

  Future<void> _review() async {
    final targets = <String, CatalogPhotoTarget>{
      for (final entry in _bySku.entries)
        entry.key: (
          row: CatalogImportNormalizedRow(
            rowIndex: 0,
            sku: entry.value.sku!,
            name: entry.value.nombre,
            priceUsd: 0,
            stock: 0,
            variantAttributeValue: entry.value.variantAttributeValue,
            variantAttributes: entry.value.variantAttributes,
          ),
          available: entry.value.imageUrls.isEmpty,
        ),
    };
    final drafts = [
      for (final draft in _drafts)
        if (draft.inventoryProductId != null &&
            _bySku[draft.skuKey]?.id != draft.inventoryProductId)
          CatalogPhotoDraft(
            file: draft.file,
            edited: draft.edited,
            assignmentNote:
                'Cambió el SKU de la referencia. Vuelve a verificar la foto.',
          )
        else
          draft,
    ];
    final reviewed = await Navigator.of(context).push<List<CatalogPhotoDraft>>(
      MaterialPageRoute(
          builder: (_) => CatalogImportPhotoReview(
                drafts: drafts,
                targets: targets,
                invalidEntries: _notices,
              )),
    );
    if (!mounted || reviewed == null) return;
    setState(() => _drafts
      ..clear()
      ..addAll(reviewed));
    final selected = reviewed.where((draft) => draft.approved).toList();
    if (selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardar fotos en el inventario'),
        content:
            Text('Se guardarán ${selected.length} fotos en galerías vacías.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar fotos')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final ids = {
      for (final draft in selected)
        draft.skuKey: draft.inventoryProductId ?? _bySku[draft.skuKey]!.id,
    };
    await _run('Guardando fotos…', () => _save(selected, ids));
  }

  Future<void> _save(
      List<CatalogPhotoDraft> approved, Map<String, String> ids) async {
    final bySku = <String, List<ProductImageBulkFile>>{};
    for (final draft in approved) {
      bySku.putIfAbsent(draft.skuKey, () => []).add(draft.assigned);
    }
    final result =
        await CatalogPhotoWriteResult.save(bySku, expectedProductIds: ids);
    if (!mounted) return;
    final remaining = [
      for (final draft in _drafts)
        if (!approved.contains(draft))
          draft
        else if (result.pending[draft.skuKey] case final reason?)
          CatalogPhotoDraft(
            file: draft.file,
            sku: draft.sku,
            slot: draft.slot,
            approved: true,
            edited: draft.edited,
            inventoryProductId: ids[draft.skuKey],
            lockSku: draft.lockSku,
            assignmentNote: reason,
          ),
    ];
    setState(() => _drafts
      ..clear()
      ..addAll(remaining));
    if (result.saved > 0) widget.onInventoryChanged();
    _message(
        '${result.saved} galerías guardadas · ${result.skipped} omitidas · ${result.pending.length} pendientes.');
    await _refreshProducts();
  }

  @override
  Widget build(BuildContext context) {
    final active = _byId[_activeId];
    final query = _query.trim().toLowerCase();
    final visible = _products
        .where((part) =>
            '${part.nombre} ${part.sku ?? ''}'.toLowerCase().contains(query))
        .toList();
    final camera = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final ready = _busy == null && !_loadFailed;
    return PopScope(
      canPop: _busy == null,
      child: Scaffold(
        appBar: AppBar(title: const Text('Etiquetas QR')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                    child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        FilledButton.icon(
                          onPressed: ready && _selected.isNotEmpty
                              ? () => _run(
                                    'Preparando PDF…',
                                    () => InventoryQrLabel.download(_products
                                        .where((p) => _selected.contains(p.id))
                                        .toList()),
                                  )
                              : null,
                          icon: const Icon(Icons.print_outlined),
                          label:
                              Text('Descargar etiquetas (${_selected.length})'),
                        ),
                        if (supportsInventoryPhotoQr)
                          OutlinedButton.icon(
                            onPressed: ready ? _scan : null,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Escanear etiqueta'),
                          ),
                        if (supportsInventoryPhotoQr)
                          OutlinedButton.icon(
                            onPressed: ready ? _readBatch : null,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Leer QR de fotos o ZIP'),
                          ),
                        OutlinedButton(
                          onPressed: ready &&
                                  (_drafts.isNotEmpty || _notices.isNotEmpty)
                              ? _review
                              : null,
                          child: Text('Revisar fotos (${_drafts.length})'),
                        ),
                        TextButton(
                            onPressed: ready && _products.isNotEmpty
                                ? _startGuided
                                : null,
                            child: const Text('Capturar repuestos sin foto')),
                      ]),
                      if (_busy case final progress?) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                        Text(progress),
                      ],
                      if (_loadFailed)
                        TextButton(
                            onPressed: _busy == null ? _load : null,
                            child: const Text(
                                'Reintentar la carga del inventario')),
                      if (active != null && active.imageUrls.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                            '${active.nombre} · ${active.sku ?? ''}${InventoryQrLabel.variant(active).isEmpty ? '' : ' · ${InventoryQrLabel.variant(active)}'}',
                            style: Theme.of(context).textTheme.titleMedium),
                        Wrap(spacing: 8, children: [
                          if (camera)
                            TextButton.icon(
                              onPressed: ready
                                  ? () => _capture(active, ImageSource.camera)
                                  : null,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Tomar foto'),
                            ),
                          TextButton(
                              onPressed: ready
                                  ? () => _capture(active, ImageSource.gallery)
                                  : null,
                              child: const Text('Adjuntar foto')),
                          TextButton(
                              onPressed: ready ? _nextProduct : null,
                              child: const Text('Siguiente repuesto')),
                          FilterChip(
                              label: const Text('Avanzar al tomar la foto'),
                              selected: _nextAfterCapture,
                              onSelected: ready
                                  ? (value) =>
                                      setState(() => _nextAfterCapture = value)
                                  : null),
                        ]),
                      ],
                      const SizedBox(height: 8),
                      TextField(
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Buscar repuesto o SKU'),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      if (visible.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: ready
                                ? () => setState(() {
                                      final ids =
                                          visible.map((part) => part.id);
                                      if (ids.every(_selected.contains)) {
                                        _selected.removeAll(ids);
                                      } else {
                                        _selected.addAll(ids);
                                      }
                                    })
                                : null,
                            child: Text(visible.every(
                                    (part) => _selected.contains(part.id))
                                ? 'Quitar selección visible'
                                : 'Seleccionar resultados (${visible.length})'),
                          ),
                        ),
                    ],
                  ),
                )),
                const SliverToBoxAdapter(child: Divider(height: 1)),
                SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (_, index) {
                    final part = visible[index];
                    return CheckboxListTile(
                      value: _selected.contains(part.id),
                      onChanged: ready
                          ? (selected) => setState(() {
                                if (selected == true) {
                                  _selected.add(part.id);
                                } else {
                                  _selected.remove(part.id);
                                }
                              })
                          : null,
                      title: Text(part.nombre),
                      subtitle: Text([
                        part.sku ?? 'Sin SKU',
                        if (InventoryQrLabel.variant(part).isNotEmpty)
                          InventoryQrLabel.variant(part),
                        if (part.imageUrls.isEmpty) 'Sin fotos',
                      ].join(' · ')),
                      secondary: IconButton(
                        tooltip: part.imageUrls.isEmpty
                            ? 'Preparar fotos'
                            : 'Abrir ficha',
                        onPressed: ready
                            ? () => _run('Buscando el repuesto…',
                                () => _chooseProduct(part.id))
                            : null,
                        icon: Icon(part.imageUrls.isEmpty
                            ? Icons.add_a_photo_outlined
                            : Icons.edit_outlined),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
