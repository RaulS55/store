import 'package:store_app/data/app_store.dart';
import 'package:store_app/models/customer.dart';
import 'package:store_app/models/lot.dart';
import 'package:store_app/models/order.dart';
import 'package:store_app/models/product.dart';

Product testProduct({
  String id = 'p-test',
  String name = 'Remera test',
  String sku = 'TST-0001',
  ApparelCategory? category = ApparelCategory.remeras,
  ApparelAudience? audience,
  String brand = 'Test',
  double price = 10000,
  int stock = 10,
  String lotId = '',
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  final stamp = createdAt ?? DateTime.utc(2026, 9, 11);
  return Product(
    id: id,
    name: name,
    sku: sku,
    category: category,
    audience: audience,
    brand: brand,
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
    lotId: lotId,
  );
}

Lot testLot({
  String id = 'l-test',
  String name = 'Lote test',
  double cost = 40000,
  int? quantity = 10,
  double? unitCost = 4000,
  double soldElsewhere = 0,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  final stamp = createdAt ?? DateTime.utc(2026, 9, 11);
  return Lot(
    id: id,
    name: name,
    cost: cost,
    quantity: quantity,
    unitCost: unitCost,
    soldElsewhere: soldElsewhere,
    createdAt: stamp,
    updatedAt: updatedAt ?? stamp,
    deletedAt: deletedAt,
  );
}

Customer testCustomer({
  String id = 'c-test',
  String name = 'Mónica Fernández',
  String? cuit = '27-21543678-3',
  TaxCondition? taxCondition = TaxCondition.responsableInscripto,
  String? phone = '+54 9 11 4555-0101',
  String? address,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? deletedAt,
}) {
  final stamp = createdAt ?? DateTime.utc(2026, 9, 11);
  return Customer(
    id: id,
    name: name,
    cuit: cuit,
    taxCondition: taxCondition,
    phone: phone,
    address: address,
    createdAt: stamp,
    updatedAt: updatedAt ?? stamp,
    deletedAt: deletedAt,
  );
}

Future<Customer> seedTestCustomer(AppStore store, {Customer? customer}) async {
  final item = customer ?? testCustomer();
  await store.upsertCustomer(item);
  return store.customerById(item.id)!;
}

Future<DraftOrder> seedTestOrder(AppStore store, {Product? product}) async {
  final item = product ?? testProduct();
  await store.upsertProduct(item);
  final live = store.productById(item.id)!;
  final customer = await seedTestCustomer(store);
  final order = store.createOrder(customer);
  store.addToOrder(live, live.variants.first);
  return order;
}
