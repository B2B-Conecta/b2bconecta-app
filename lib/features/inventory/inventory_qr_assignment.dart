import '../catalog/part_model.dart';
import 'catalog_import_photos.dart';
import 'inventory_qr_label.dart';
import 'product_image_bulk_service.dart';
import 'product_images.dart';

CatalogPhotoDraft proposeInventoryQrPhoto({
  required ProductImageBulkFile photo,
  required List<String> codes,
  required Map<String, PartModel> byId,
  required Map<String, PartModel> bySku,
  required Map<String, Set<int>> occupied,
  bool checkFileName = true,
}) {
  CatalogPhotoDraft pending(String note) =>
      CatalogPhotoDraft(file: photo, assignmentNote: note);

  if (codes.isEmpty) return pending('No se encontró un QR. Asigna el SKU.');
  if (codes.length > 1)
    return pending('Se leyeron varias etiquetas. Revisa la referencia.');
  final id = InventoryQrLabel.productId(codes.single);
  if (id == null) return pending('El QR no es una etiqueta de este sistema.');
  final part = byId[id];
  if (part == null)
    return pending('La etiqueta no corresponde a tu inventario.');
  final sku = part.sku?.trim() ?? '';
  final key = sku.toLowerCase();
  if (bySku[key]?.id != id) {
    return pending('La referencia requiere un SKU único para la carga masiva.');
  }
  final name = photo.pathInZip.replaceAll(r'\', '/').split('/').last;
  final dot = name.lastIndexOf('.');
  final stem = (dot < 0 ? name : name.substring(0, dot)).toLowerCase();
  final guess = parseProductImageFilename(name)?.sku.toLowerCase();
  final filenameMatches = {
    if (bySku.containsKey(stem)) bySku[stem]!.id,
    if (guess != null && bySku.containsKey(guess)) bySku[guess]!.id,
  };
  if (checkFileName && filenameMatches.any((match) => match != id)) {
    return pending(
        'El QR y el nombre del archivo indican referencias distintas.');
  }
  final slots = occupied.putIfAbsent(key, () => {});
  final slot = List.generate(kMaxProductImages, (i) => i + 1)
      .where((i) => !slots.contains(i))
      .firstOrNull;
  if (slot != null && part.imageUrls.isEmpty) slots.add(slot);
  return CatalogPhotoDraft(
    file: photo,
    sku: sku,
    slot: slot ?? 1,
    lockSku: true,
    inventoryProductId: id,
    assignmentNote: part.imageUrls.isNotEmpty
        ? 'Este producto ya tiene fotos. Puedes gestionarlas desde su ficha.'
        : slot == null
            ? 'Ya hay tres tomas propuestas. Elige cuáles incluir.'
            : 'Referencia propuesta por la etiqueta QR.',
  );
}
