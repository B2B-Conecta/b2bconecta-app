import 'package:flutter_test/flutter_test.dart';
import 'package:motolink_pro_app/features/catalog/product_share_link.dart';

void main() {
  const id = '11111111-2222-3333-4444-555555555555';

  test('arma el enlace estable de la ficha', () {
    expect(
      ProductShareLink.urlFor(id),
      'https://app.b2bconecta.com.ve/producto/$id',
    );
    expect(
      ProductShareLink.devUrlFor(id),
      'https://b2bconecta-app-git-dev-b2bconecta.vercel.app/producto/$id',
    );
  });

  test('lee el id en la ruta, el host de la app y www', () {
    expect(
      ProductShareLink.idFromUri(
        Uri.parse('https://app.b2bconecta.com.ve/producto/$id'),
      ),
      id,
    );
    expect(
      ProductShareLink.idFromUri(
        Uri.parse('https://www.b2bconecta.com.ve/producto/$id/'),
      ),
      id,
    );
    expect(
      ProductShareLink.idFromRouteName('/producto/$id'),
      id,
    );
  });

  test('ignora rutas que no son una ficha', () {
    expect(
      ProductShareLink.idFromUri(
        Uri.parse('https://app.b2bconecta.com.ve/registro'),
      ),
      isNull,
    );
    expect(
      ProductShareLink.idFromUri(
        Uri.parse('https://app.b2bconecta.com.ve/producto/no-es-uuid'),
      ),
      isNull,
    );
  });
}
