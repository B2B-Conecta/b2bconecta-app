class ProductImageBulkResult {
  const ProductImageBulkResult({
    this.updated = 0,
    this.skipped = 0,
    this.errors = const [],
  });

  final int updated;
  final int skipped;
  final List<ProductImageBulkError> errors;

  int get errorCount => errors.length;
}

class ProductImageBulkError {
  const ProductImageBulkError({
    this.sku,
    required this.message,
  });

  final String? sku;
  final String message;
}

class ProductSkuImageIndexEntry {
  const ProductSkuImageIndexEntry({
    required this.productId,
    required this.sku,
    required this.imageUrls,
  });

  final String productId;
  final String sku;
  final List<String> imageUrls;
}
