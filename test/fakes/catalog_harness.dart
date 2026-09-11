import 'package:store_app/data/app_store.dart';
import 'package:store_app/models/order.dart';
import 'package:store_app/models/product.dart';

Product testProduct({
  String id = 'p-test',
  String name = 'Remera test',
  String sku = 'TST-0001',
  double price = 10000,
  int stock = 10,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  final stamp = createdAt ?? DateTime.utc(2026, 9, 11);
  return Product(
    id: id,
    name: name,
    sku: sku,
    category: ApparelCategory.remeras,
    brand: 'Test',
    price: price,
    images: const [],
    variants: [
      ProductVariant(
        size: 'M',
        color: 'Negro',
        colorHex: '#1E1E1E',
        stock: stock,
      ),
    ],
    createdAt: stamp,
    updatedAt: updatedAt ?? stamp,
    deletedAt: deletedAt,
  );
}

Future<DraftOrder> seedTestOrder(AppStore store, {Product? product}) async {
  final item = product ?? testProduct();
  await store.upsertProduct(item);
  final live = store.productById(item.id)!;
  final order = store.createOrder(store.customers.first);
  store.addToOrder(live, live.variants.first);
  return order;
}
