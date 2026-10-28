import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/inventory/product_delete_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ProductDeleteErrors', () {
    test('detects 23503 replacement_orders as postventa history', () {
      final error = PostgrestException(
        message:
            'update or delete on table "products" violates foreign key constraint '
            '"replacement_orders_product_id_fkey"',
        code: '23503',
        details: 'Key (id)=(abc) is still referenced from table "replacement_orders".',
        hint: null,
      );

      expect(ProductDeleteErrors.isForeignKeyViolation(error), isTrue);
      expect(
        ProductDeleteErrors.classify(error),
        ProductDeleteBlockReason.replacementHistory,
      );
      expect(
        ProductDeleteErrors.reasonLabel(
          ProductDeleteBlockReason.replacementHistory,
        ),
        contains('reemplazo'),
      );
    });

    test('detects other foreign key violations without replacement table', () {
      final error = PostgrestException(
        message: 'violates foreign key constraint "profit_sync_product_mappings_product_id_fkey"',
        code: '23503',
        details: 'Key is still referenced from table "profit_sync_product_mappings".',
        hint: null,
      );

      expect(ProductDeleteErrors.isForeignKeyViolation(error), isTrue);
      expect(
        ProductDeleteErrors.classify(error),
        ProductDeleteBlockReason.foreignKey,
      );
    });

    test('ignores unrelated postgres codes', () {
      final error = PostgrestException(
        message: 'duplicate key',
        code: '23505',
        details: null,
        hint: null,
      );

      expect(ProductDeleteErrors.isForeignKeyViolation(error), isFalse);
      expect(
        ProductDeleteErrors.classify(error),
        ProductDeleteBlockReason.other,
      );
    });
  });

  group('ProductDeleteBatchResult', () {
    test('flags mixed success and blocked rows', () {
      const result = ProductDeleteBatchResult(
        deletedIds: ['a'],
        blocked: [
          ProductDeleteBlockedItem(
            id: 'b',
            label: 'SKU-B',
            reason: ProductDeleteBlockReason.replacementHistory,
          ),
        ],
      );

      expect(result.isMixed, isTrue);
      expect(result.allSucceeded, isFalse);
      expect(result.allBlocked, isFalse);
      expect(result.blockedIds, ['b']);
    });
  });
}
