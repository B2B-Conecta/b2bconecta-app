import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:motolink_pro_app/features/catalog/product_share_link.dart';

void main() {
  const id = '11111111-2222-3333-4444-555555555555';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProductShareLink.pending.value = null;
  });

  test('un enlace consumido al llegar no queda guardado para abrirse otra vez',
      () async {
    Future<String?>? consumed;
    void onPending() {
      if (ProductShareLink.pending.value != null) {
        consumed = ProductShareLink.take();
      }
    }

    ProductShareLink.pending.addListener(onPending);
    addTearDown(() => ProductShareLink.pending.removeListener(onPending));
    await ProductShareLink.capture(Uri.parse(ProductShareLink.urlFor(id)));
    expect(await consumed, id);
    expect(await ProductShareLink.take(), isNull);
  });

  test('conserva el producto durante el registro o inicio de sesión', () async {
    await ProductShareLink.capture(Uri.parse(ProductShareLink.urlFor(id)));
    // Authentication routes must not overwrite the pending product.
    await ProductShareLink.capture(
        Uri.parse('${ProductShareLink.origin}/registro'));
    ProductShareLink.pending.value = null;
    await ProductShareLink.restore();
    expect(ProductShareLink.pending.value, id);
    expect(await ProductShareLink.take(), id);
    expect(await ProductShareLink.take(), isNull);
  });

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
