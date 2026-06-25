import 'dart:typed_data';

import '../models/catalog_import/catalog_import_mapping.dart';
import '../models/catalog_import/catalog_import_result.dart';
import 'flexible_catalog_import_service.dart';
import 'supabase_service.dart';

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
    void Function(int processedRows, CatalogImportResult partial)? onProgress,
  }) async {
    var aggregate = const CatalogImportResult();
    var processed = 0;

    await for (final batch in FlexibleCatalogImportService.parseInBatches(
      bytes: bytes,
      mapping: mapping,
    )) {
      processed += batch.validRows.length + batch.errors.length;

      if (mapping.options.dryRun) {
        aggregate = aggregate.merge(
          CatalogImportResult(
            skipped: batch.validRows.length,
            validationErrors: batch.errors,
            dryRun: true,
          ),
        );
      } else {
        aggregate = aggregate.merge(
          CatalogImportResult(validationErrors: batch.errors),
        );
        if (batch.validRows.isNotEmpty) {
          final rpc = await SupabaseService.importadorBulkUpsertProducts(
            rows: batch.validRows,
            options: mapping.options,
          );
          aggregate = aggregate.merge(rpc);
        }
      }

      onProgress?.call(processed, aggregate);
    }

    return aggregate;
  }
}
