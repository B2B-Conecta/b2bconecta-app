import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/app/config/brand_copy.dart';

void main() {
  test('reemplaza MotoLink por B2B Conecta', () {
    expect(
      BrandCopy.display(
        'Su acceso a MotoLink está habilitado. Ya puede operar en la plataforma.',
      ),
      'Su acceso a B2B Conecta está habilitado. Ya puede operar en la plataforma.',
    );
    expect(
      BrandCopy.display('Pedido anulado por Motolink'),
      'Pedido anulado por B2B Conecta',
    );
    expect(BrandCopy.display('anulado_por_motolink'), 'anulado_por_motolink');
  });
}
