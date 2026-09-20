import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/routing/app_entry.dart';

void main() {
  test('reads catalog links from path or hash', () {
    expect(
      locationFromUri(Uri.parse('https://moda.stock/catalogo/co1')),
      '/catalogo/co1',
    );
    expect(
      locationFromUri(Uri.parse('https://moda.stock/#/catalogo/co1')),
      '/catalogo/co1',
    );
    expect(
      locationFromUri(Uri.parse('https://moda.stock/#/catalogo/co1/pedido')),
      '/catalogo/co1/pedido',
    );
    expect(locationFromUri(Uri.parse('https://moda.stock/')), '/');
    expect(isCatalogLocation('/catalogo/co1'), isTrue);
    expect(isCatalogLocation('/catalogo/co1/pedido'), isTrue);
    expect(isCatalogLocation('/'), isFalse);
    expect(isCatalogLocation('/ingresar'), isFalse);
  });
}
