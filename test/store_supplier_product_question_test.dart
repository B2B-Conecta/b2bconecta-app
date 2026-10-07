import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/store_supplier_chat.dart';

void main() {
  test('un mensaje general no menciona producto', () {
    final message = StoreSupplierMessage.fromJson({
      'id': 'm1',
      'thread_id': 't1',
      'author_id': 'u1',
      'author_role': 'aliado',
      'body': 'Hola',
      'created_at': '2026-10-07T12:00:00Z',
    });
    expect(message.productLabel, isEmpty);
    expect(message.body, 'Hola');
  });

  test('una pregunta de ficha conserva el producto', () {
    final message = StoreSupplierMessage.fromJson({
      'id': 'm2',
      'thread_id': 't1',
      'author_id': 'u1',
      'author_role': 'aliado',
      'body': '¿Tienen este repuesto?',
      'product_id': 'p1',
      'product_name': 'Pastilla de freno',
      'product_sku': 'FR-01',
    });
    expect(message.productId, 'p1');
    expect(message.productLabel, 'Pastilla de freno · FR-01');
  });

  test('el botón de la ficha sigue reservado a otra tienda', () {
    expect(
      showStoreSupplierChatButton(
        viewerRole: 'aliado',
        viewerId: 'tienda',
        importerId: 'proveedor',
      ),
      isTrue,
    );
    expect(
      showStoreSupplierChatButton(
        viewerRole: 'importador',
        viewerId: 'proveedor',
        importerId: 'proveedor',
      ),
      isFalse,
    );
  });
}
