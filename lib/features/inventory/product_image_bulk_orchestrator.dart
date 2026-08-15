import 'product_image_bulk_result.dart';
import 'product_image_bulk_service.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';
import 'product_images.dart';

/// Sube fotos del ZIP y persiste `image_urls` por producto.
class ProductImageBulkOrchestrator {
  ProductImageBulkOrchestrator._();

  static Future<ProductImageBulkResult> execute({
    required ProductImageBulkPreview preview,
    required Map<String, ProductSkuImageIndexEntry> skuIndex,
    required ProductImageBulkMergeMode mode,
    void Function(int done, int total)? onProgress,
  }) async {
    final errors = <ProductImageBulkError>[];
    var updated = 0;
    var skipped = 0;

    final work = <String, List<ProductImageBulkFile>>{};
    for (final e in preview.bySku.entries) {
      if (!skuIndex.containsKey(e.key)) continue;
      if (e.value.length > kMaxProductImages) {
        errors.add(
          ProductImageBulkError(
            sku: e.value.first.sku,
            message: 'Más de $kMaxProductImages fotos en el ZIP',
          ),
        );
        continue;
      }
      work[e.key] = e.value;
    }

    final total = work.length;
    var done = 0;
    final batchRows = <Map<String, dynamic>>[];

    for (final e in work.entries) {
      final entry = skuIndex[e.key];
      if (entry == null) {
        skipped++;
        done++;
        onProgress?.call(done, total);
        continue;
      }

      if (mode == ProductImageBulkMergeMode.fillEmptyOnly &&
          entry.imageUrls.isNotEmpty) {
        skipped++;
        done++;
        onProgress?.call(done, total);
        continue;
      }

      final bySlot = ProductImageBulkService.filesBySlot(e.value);
      final uploadedBySlot = <int, String>{};

      for (final slotEntry in bySlot.entries) {
        final file = slotEntry.value;
        try {
          final url = await SupabaseService.uploadProductImage(
            bytes: file.bytes,
            fileExtension: file.extension,
            productId: entry.productId,
            slot: slotEntry.key,
          );
          uploadedBySlot[slotEntry.key] = url;
        } catch (ex) {
          errors.add(
            ProductImageBulkError(
              sku: entry.sku,
              message: 'Slot ${slotEntry.key}: $ex',
            ),
          );
        }
      }

      if (uploadedBySlot.isEmpty) {
        skipped++;
        done++;
        onProgress?.call(done, total);
        continue;
      }

      final merged = mergeProductImageUrls(
        existing: entry.imageUrls,
        newBySlot: uploadedBySlot,
        mode: mode,
      );

      if (merged.isEmpty) {
        skipped++;
      } else {
        batchRows.add({
          'product_id': entry.productId,
          'image_urls': merged,
        });
        updated++;
      }

      done++;
      onProgress?.call(done, total);
    }

    if (batchRows.isNotEmpty) {
      const chunkSize = 50;
      for (var i = 0; i < batchRows.length; i += chunkSize) {
        final chunk = batchRows.sublist(
          i,
          i + chunkSize > batchRows.length ? batchRows.length : i + chunkSize,
        );
        final rpc = await SupabaseService.importadorBulkSetProductImages(
          rows: chunk,
        );
        errors.addAll(rpc.errors);
      }
    }

    return ProductImageBulkResult(
      updated: updated,
      skipped: skipped,
      errors: errors,
    );
  }
}
