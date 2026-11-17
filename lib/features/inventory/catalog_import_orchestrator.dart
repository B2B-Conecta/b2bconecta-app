import 'dart:typed_data';

import 'catalog_import/catalog_import_mapping.dart';
import 'catalog_import/catalog_import_result.dart';
import 'catalog_import_validator.dart';
import 'flexible_catalog_import_service.dart';
import 'inventory_service.dart';
import 'product_images.dart';
import 'package:motolink_pro_app/core/data/supabase_service.dart';

/// Orquestador de extremo a extremo: preview → parseo por lotes → upsert RPC.
class CatalogImportOrchestrator {
  CatalogImportOrchestrator._();

  /// Paso 1 del wizard: cabeceras + muestra para mapeo dinámico.
  static CatalogImportPreview preview({
    required Uint8List bytes,
    required CatalogImportFileMeta fileMeta,
  }) {
    return FlexibleCatalogImportService.previewFile(
      bytes: bytes,
      meta: fileMeta,
    );
  }

  /// Paso 2+3: parsea, valida y persiste en lotes (memoria acotada).
  static Future<CatalogImportResult> execute({
    required Uint8List bytes,
    required CatalogImportMapping mapping,
    Map<int, Map<String, String>> corrections = const {},
    Set<String> photoSkuKeys = const {},
    void Function(String skuKey)? onSourceSku,
    void Function(int rowIndex, String sku, String name)? onCatalogRow,
    void Function(CatalogImportNormalizedRow row, bool canSavePhotos)?
        onPhotoCandidate,
    void Function(String skuKey)? onProductSaved,
    void Function(int processedRows, CatalogImportResult partial)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final current = <String, Map<String, dynamic>>{};
    if (mapping.options.dryRun) {
      await for (final page in InventoryService.readMyInventoryPages(
        'id, sku, price_usd, sale_price_usd, stock, image_url, image_urls',
      )) {
        for (final product in page) {
          final sku = (product['sku'] as String?)?.trim().toLowerCase();
          if (sku != null && sku.isNotEmpty) current[sku] = product;
        }
      }
    }
    var aggregate = CatalogImportResult(dryRun: mapping.options.dryRun);
    var processed = 0;

    await for (final batch in FlexibleCatalogImportService.parseInBatches(
      bytes: bytes,
      mapping: mapping,
      corrections: corrections,
      onSourceSku: onSourceSku,
      onCatalogRow: onCatalogRow,
    )) {
      processed += batch.validRows.length + batch.errors.length;

      if (mapping.options.dryRun) {
        var inserted = 0, updated = 0, skipped = 0;
        var priceChanges = 0, stockChanges = 0, imageUrlChanges = 0;
        for (final row in batch.validRows) {
          final skuKey = row.sku.trim().toLowerCase();
          final product = current[skuKey];
          final eligible = product == null ||
              mapping.options.upsertMode != CatalogImportUpsertMode.insertOnly;
          final hasPhoto = product != null &&
              productRowHasPhotos(
                imageUrls: product['image_urls'],
                imageUrl: product['image_url'],
              );
          final keepsUrl = row.imageUrl != null &&
              (product == null ||
                  mapping.options.upsertMode ==
                      CatalogImportUpsertMode.updateAll);
          onPhotoCandidate?.call(row, eligible && !hasPhoto && !keepsUrl);
          if (product == null) {
            inserted++;
          } else if (mapping.options.upsertMode ==
              CatalogImportUpsertMode.insertOnly) {
            skipped++;
          } else {
            updated++;
            if (product['price_usd'] != row.priceUsd ||
                product['sale_price_usd'] != row.salePriceUsd) {
              priceChanges++;
            }
            if (product['stock'] != row.stock) stockChanges++;
            if (mapping.options.upsertMode ==
                    CatalogImportUpsertMode.updateAll &&
                !hasPhoto &&
                row.imageUrl != null &&
                product['image_url'] != row.imageUrl) {
              imageUrlChanges++;
            }
          }
        }
        aggregate = aggregate.merge(CatalogImportResult(
          inserted: inserted,
          updated: updated,
          skipped: skipped,
          validationErrors: batch.errors,
          dryRun: true,
          priceChanges: priceChanges,
          stockChanges: stockChanges,
          imageUrlChanges: imageUrlChanges,
        ));
      } else {
        aggregate = aggregate.merge(
          CatalogImportResult(validationErrors: batch.errors),
        );
        final isolatePhotoRows =
            mapping.options.upsertMode == CatalogImportUpsertMode.insertOnly;
        for (final rows in _writeGroups(
          batch.validRows,
          isolatePhotoRows ? photoSkuKeys : const {},
        )) {
          try {
            final rpc = await SupabaseService.importadorBulkUpsertProducts(
              rows: rows,
              options: mapping.options,
            );
            aggregate = aggregate.merge(rpc);
            final failures =
                rpc.persistenceErrors.map((e) => e.rowIndex).toSet();
            final confirmed =
                rows.where((row) => !failures.contains(row.rowIndex));
            // Only infer which rows succeeded when the response accounts for all
            // of them. Insert-only photo rows are submitted individually.
            if (rpc.skipped == 0 && rpc.successCount == confirmed.length) {
              for (final row in confirmed) {
                final key = row.sku.trim().toLowerCase();
                if (photoSkuKeys.contains(key)) onProductSaved?.call(key);
              }
            } else if (rpc.successCount + rpc.skipped != confirmed.length) {
              aggregate = aggregate.merge(CatalogImportResult(
                persistenceErrors: [
                  CatalogImportRowError(
                    rowIndex: rows.first.rowIndex,
                    code: 'UNCONFIRMED_BATCH',
                    message:
                        'La base no confirmó todas las filas de este lote.',
                  ),
                ],
              ));
            }
          } catch (_) {
            aggregate = aggregate.merge(CatalogImportResult(
              persistenceErrors: [
                CatalogImportRowError(
                  rowIndex: rows.first.rowIndex,
                  code: 'UNCONFIRMED_BATCH',
                  message: 'No se pudo confirmar el guardado de las filas '
                      '${rows.first.rowIndex} a ${rows.last.rowIndex}.',
                ),
              ],
            ));
          }
        }
      }

      onProgress?.call(processed, aggregate);
      if (shouldCancel?.call() == true) return aggregate;
    }

    return aggregate;
  }

  static Iterable<List<CatalogImportNormalizedRow>> _writeGroups(
    List<CatalogImportNormalizedRow> rows,
    Set<String> photoSkuKeys,
  ) sync* {
    var start = 0;
    for (var i = 0; i < rows.length; i++) {
      if (!photoSkuKeys.contains(rows[i].sku.trim().toLowerCase())) continue;
      if (i > start) yield rows.sublist(start, i);
      yield [rows[i]];
      start = i + 1;
    }
    if (start < rows.length) yield rows.sublist(start);
  }
}
