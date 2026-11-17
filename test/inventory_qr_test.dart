import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/part_model.dart';
import 'package:motolink_pro_app/features/inventory/inventory_qr_assignment.dart';
import 'package:motolink_pro_app/features/inventory/inventory_qr_label.dart';
import 'package:motolink_pro_app/features/inventory/product_image_bulk_service.dart';

void main() {
  const first = '5ae14412-98e5-476d-a222-00fdc4062f5e';
  const second = '5ae14412-98e5-476d-a222-00fdc4062f5f';
  final bearing =
      PartModel.fromJson({'id': first, 'sku': '0007', 'name': 'Rodamiento'});
  final gasket =
      PartModel.fromJson({'id': second, 'sku': '0010', 'name': 'Junta'});
  final code = InventoryQrLabel.encode(first);

  test('la etiqueta conserva la identidad aunque cambie el SKU', () {
    final renamed = bearing.copyWith(sku: '0077');
    expect(InventoryQrLabel.encode(renamed.id), code);
    expect(InventoryQrLabel.productId(code), first);
    expect(InventoryQrLabel.productId('B2BCF1:0007'), isNull);
    expect(InventoryQrLabel.productId('B2BINV1:0007'), isNull);
  });

  test('solo propone un QR inequívoco y deja la foto pendiente de aprobación',
      () {
    final byId = {first: bearing, second: gasket};
    final bySku = {'0007': bearing, '0010': gasket};
    final occupied = <String, Set<int>>{};
    final image = Uint8List(1);
    final read = ([String name = 'IMG_001.jpg', List<String>? codes]) =>
        proposeInventoryQrPhoto(
          photo: ProductImageBulkFile(
              pathInZip: name,
              bytes: image,
              extension: 'jpeg',
              sku: '',
              slot: 1),
          codes: codes ?? [code],
          byId: byId,
          bySku: bySku,
          occupied: occupied,
        );
    final draft = read();
    expect(draft.sku, '0007');
    expect(draft.inventoryProductId, first);
    expect(draft.lockSku, isTrue);
    expect(draft.approved, isFalse);
    expect(read('0010.jpg').sku, isEmpty);
    expect(read('IMG_002.jpg', [code, InventoryQrLabel.encode(second)]).sku,
        isEmpty);
    expect(
        read('IMG_002.jpg', [
          InventoryQrLabel.encode('5ae14412-98e5-476d-a222-00fdc4062f50')
        ]).sku,
        isEmpty);
    expect(read().slot, 2);
    expect(read().slot, 3);
    expect(read().assignmentNote, contains('tres'));
  });

  test('genera una hoja imprimible y continúa en la siguiente página',
      () async {
    final bytes = await InventoryQrLabel.buildPdf(List.filled(16, bearing));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}
