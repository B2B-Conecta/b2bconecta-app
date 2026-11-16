import 'catalog_import_validator.dart';
import 'catalog_photo_adjustments.dart';
import 'catalog_photo_source.dart';
import 'inventory_service.dart';
import 'product_image_bulk_orchestrator.dart';
import 'product_image_bulk_result.dart';
import 'product_image_bulk_service.dart';
import 'product_images.dart';

typedef CatalogPhotoTarget = ({
  CatalogImportNormalizedRow row,
  bool available,
});

/// Keeps the reviewed assignment separate from the name in the ZIP.
class CatalogPhotoDraft {
  const CatalogPhotoDraft({
    required this.file,
    this.sku = '',
    this.slot = 1,
    this.approved = false,
    this.workbookPhoto,
    this.sourceRowBinding,
    this.edited,
  });

  final ProductImageBulkFile file;
  final String sku;
  final int slot;
  final bool approved;
  final CatalogSourcePhoto? workbookPhoto;
  final int? sourceRowBinding;
  final CatalogEditedPhoto? edited;

  String get skuKey => sku.trim().toLowerCase();

  CatalogPhotoDraft copyWith({
    String? sku,
    int? slot,
    bool? approved,
    CatalogEditedPhoto? edited,
    bool restoreOriginal = false,
  }) {
    return CatalogPhotoDraft(
      file: file,
      sku: sku ?? this.sku,
      slot: slot ?? this.slot,
      approved: approved ?? this.approved,
      workbookPhoto: workbookPhoto,
      sourceRowBinding: sku == null ? sourceRowBinding : null,
      edited: restoreOriginal ? null : edited ?? this.edited,
    );
  }

  ProductImageBulkFile get assigned => ProductImageBulkFile(
        pathInZip: file.pathInZip,
        bytes: edited?.bytes ?? file.bytes,
        extension: edited?.extension ?? file.extension,
        sku: sku.trim(),
        slot: slot,
      );

  static List<CatalogPhotoDraft> fromWorkbook(
    List<CatalogSourcePhoto> photos,
    Map<String, CatalogPhotoTarget> targets, {
    List<CatalogPhotoDraft> existing = const [],
    int sourceRowOffset = 0,
  }) {
    final byRow = {
      for (final target in targets.values)
        target.row.rowIndex + sourceRowOffset: target
    };
    final occupied = <String, Set<int>>{};
    for (final draft in existing) {
      if (draft.skuKey.isNotEmpty) {
        occupied.putIfAbsent(draft.skuKey, () => {}).add(draft.slot);
      }
    }
    return [
      for (final photo in photos) _suggestWorkbookPhoto(photo, byRow, occupied),
    ];
  }

  static CatalogPhotoDraft _suggestWorkbookPhoto(
    CatalogSourcePhoto photo,
    Map<int, CatalogPhotoTarget> byRow,
    Map<String, Set<int>> occupied,
  ) {
    final target = photo.singleRow ? byRow[photo.sourceRow] : null;
    final sku = target?.row.sku ?? '';
    final slots = occupied.putIfAbsent(sku.toLowerCase(), () => {});
    final slot = List.generate(kMaxProductImages, (i) => i + 1)
        .where((slot) => !slots.contains(slot))
        .firstOrNull;
    final hasSuggestion = sku.isNotEmpty && slot != null;
    if (hasSuggestion) slots.add(slot);
    return CatalogPhotoDraft(
      file: ProductImageBulkFile(
        pathInZip: photo.name,
        bytes: photo.bytes,
        extension: photo.extension,
        sku: '',
        slot: 1,
      ),
      workbookPhoto: photo,
      sourceRowBinding: hasSuggestion ? target?.row.rowIndex : null,
      sku: hasSuggestion ? sku : '',
      slot: slot ?? 1,
      approved: hasSuggestion && target?.available == true,
    );
  }

  static Map<String, String> assignmentErrors(
    List<CatalogPhotoDraft> drafts,
    Map<String, CatalogPhotoTarget> targets,
  ) {
    final slots = <String, List<int>>{};
    final errors = <String, String>{};
    for (final draft in drafts.where((draft) => draft.approved)) {
      final key = draft.skuKey;
      final target = targets[key];
      if (target == null || !target.available) {
        errors[key] = target == null
            ? 'El SKU no está en las filas válidas.'
            : 'Este SKU ya tiene foto o se omitirá en esta importación.';
        continue;
      }
      if (draft.sourceRowBinding != null &&
          target.row.rowIndex != draft.sourceRowBinding) {
        errors[key] = 'Cambió la fila de este SKU. Revisa la asignación.';
        continue;
      }
      slots.putIfAbsent(key, () => []).add(draft.slot);
    }
    for (final entry in slots.entries) {
      final sorted = entry.value..sort();
      for (var i = 0; i < sorted.length; i++) {
        if (i >= kMaxProductImages || sorted[i] != i + 1) {
          errors[entry.key] =
              'Usa posiciones consecutivas desde Portada, sin repetirlas.';
          break;
        }
      }
    }
    return errors;
  }
}

class CatalogPhotoWriteResult {
  const CatalogPhotoWriteResult({
    this.saved = 0,
    this.skipped = 0,
    this.pending = const {},
  });

  final int saved;
  final int skipped;
  final Map<String, String> pending;

  static Future<CatalogPhotoWriteResult> save(
    Map<String, List<ProductImageBulkFile>> files,
  ) async {
    if (files.isEmpty) return const CatalogPhotoWriteResult();
    final pending = <String, String>{};
    Map<String, ProductSkuImageIndexEntry> index;
    try {
      index = await InventoryService.fetchMyInventorySkuImageIndex();
    } catch (_) {
      return CatalogPhotoWriteResult(pending: {
        for (final sku in files.keys)
          sku: 'No se pudo consultar el inventario. Reintenta las fotos.',
      });
    }

    var saved = 0;
    var skipped = 0;
    for (final entry in files.entries) {
      final target = index[entry.key];
      if (target == null) {
        pending[entry.key] = 'El repuesto no está disponible en tu inventario.';
        continue;
      }
      try {
        final result = await ProductImageBulkOrchestrator.execute(
          preview: ProductImageBulkPreview(
            files: entry.value,
            bySku: {entry.key: entry.value},
            unknownSkus: const [],
            overLimitSkus: const [],
            invalidEntries: const [],
          ),
          skuIndex: {entry.key: target},
          mode: ProductImageBulkMergeMode.fillEmptyOnly,
          atomicFillEmpty: true,
        );
        if (result.errors.isNotEmpty) {
          pending[entry.key] =
              'No se pudieron subir todas las fotos del repuesto.';
        } else {
          saved += result.updated;
          skipped += result.skipped;
        }
      } catch (_) {
        pending[entry.key] = 'No se pudo confirmar el guardado de sus fotos.';
      }
    }
    return CatalogPhotoWriteResult(
        saved: saved, skipped: skipped, pending: pending);
  }
}
