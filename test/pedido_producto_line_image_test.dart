import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/orders/shared/order_item_model.dart';
import 'package:motolink_pro_app/features/orders/shared/transaction_request_model.dart';

void main() {
  test('lineasProductoDesglose incluye portada del embed products', () {
    final m = TransactionRequestModel.fromJson({
      'id': 'tr-1',
      'aliado_id': 'al-1',
      'product_id': 'p-1',
      'importador_id': 'im-1',
      'status': 'pendiente',
      'cantidad': 5,
      'precio_total_usd': 230,
      'precio_unitario_aliado': 46,
      'precio_unitario_proveedor': 40,
      'precio_base_aliado_total': 230,
      'products': {
        'name': 'Caucho firestone 110/90-16',
        'sku': 'cau-110/90',
        'image_urls': ['https://cdn.example/caucho.jpg'],
      },
    });
    final lines = m.lineasProductoDesglose();
    expect(lines, hasLength(1));
    expect(lines.single.nombre, 'Caucho firestone 110/90-16');
    expect(lines.single.sku, 'cau-110/90');
    expect(lines.single.imageUrl, 'https://cdn.example/caucho.jpg');
  });

  test('OrderItemModel parsea image_urls del producto', () {
    final item = OrderItemModel.fromJson({
      'id': 'oi-1',
      'sub_order_id': 'so-1',
      'product_id': 'p-1',
      'importador_id': 'im-1',
      'cantidad': 2,
      'precio_unitario_proveedor': 10,
      'precio_unitario_aliado': 12,
      'precio_line_total': 24,
      'precio_base_aliado_line': 24,
      'products': {
        'name': 'Filtro',
        'sku': 'FIL-1',
        'image_urls': ['https://cdn.example/filtro.jpg'],
      },
    });
    expect(item.productImageUrls, ['https://cdn.example/filtro.jpg']);
    expect(
      PedidoProductoLineUi.fromOrderItem(item).imageUrl,
      'https://cdn.example/filtro.jpg',
    );
  });
}
