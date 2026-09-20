import 'catalog_guest_store.dart';
import 'company_access.dart';
import 'customer_access.dart';
import 'local/catalog_cart_cache.dart';
import 'order_access.dart';
import 'product_access.dart';
import 'product_image_cache.dart';

class CatalogBindings {
  CatalogBindings({
    required this.companies,
    required this.products,
    required this.customers,
    required this.orders,
    CatalogCartCache? cart,
    this.images,
  }) : cart = cart ?? MemoryCatalogCartCache();

  final CompanyAccess companies;
  final ProductAccess products;
  final CustomerAccess customers;
  final OrderAccess orders;
  final CatalogCartCache cart;
  final ProductImageCache? images;
  final _stores = <String, CatalogGuestStore>{};

  CatalogGuestStore storeFor(String companyId) {
    return _stores.putIfAbsent(
      companyId,
      () => CatalogGuestStore(
        companyId: companyId,
        companies: companies,
        products: products,
        customers: customers,
        orders: orders,
        cart: cart,
        images: images,
      ),
    );
  }

  void dispose() {
    for (final store in _stores.values) {
      store.dispose();
    }
    _stores.clear();
  }
}
