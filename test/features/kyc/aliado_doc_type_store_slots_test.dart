import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/kyc/aliado_doc_type.dart';

void main() {
  test('cada documento tiene exactamente 3 slots de foto', () {
    expect(AliadoDocType.maxPhotosPerDoc, 3);
    expect(
      AliadoDocType.photoSlotsFor(AliadoDocType.cedulaPropietario),
      [
        'cedula_propietario',
        'cedula_propietario_2',
        'cedula_propietario_3',
      ],
    );
    expect(
      AliadoDocType.photoSlotsFor(AliadoDocType.fotoTienda),
      AliadoDocType.photoSlotsFor('foto_tienda_2'),
    );
  });

  test('baseType y slotIndex', () {
    expect(AliadoDocType.baseType('registro_mercantil_3'), 'registro_mercantil');
    expect(AliadoDocType.photoSlotIndex('registro_mercantil_3'), 3);
    expect(AliadoDocType.photoSlotIndex('registro_mercantil'), 1);
  });

  test('docGroupsForAdmin no expande slots', () {
    final groups = AliadoDocType.docGroupsForAdmin(
      role: 'aliado',
      uploadedTypes: const ['cedula_propietario_2', 'foto_tienda_3'],
    );
    expect(groups, contains(AliadoDocType.cedulaPropietario));
    expect(groups, contains(AliadoDocType.storePhotoBase));
    expect(groups, isNot(contains('cedula_propietario_2')));
  });

  test('mayorista no tiene grupos documentales KYC', () {
    expect(
      AliadoDocType.docGroupsForAdmin(
        role: 'importador',
        uploadedTypes: const ['cedula_representante', 'foto_tienda'],
      ),
      isEmpty,
    );
    expect(
      AliadoDocType.forAdminReview(
        role: 'importador',
        uploadedTypes: const [],
      ),
      isEmpty,
    );
  });

  test('forAdminReview expande a 3 por grupo en minorista', () {
    final flat = AliadoDocType.forAdminReview(
      role: 'aliado',
      uploadedTypes: const [],
    );
    expect(flat, containsAll(AliadoDocType.photoSlotsFor('cedula_propietario')));
    expect(flat, containsAll(AliadoDocType.photoSlotsFor('foto_tienda')));
  });
}
