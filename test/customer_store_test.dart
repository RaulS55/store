import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/app_store.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_customer_access.dart';

void main() {
  test('upsert writes customers with sync fields', () async {
    final access = FakeCustomerAccess();
    final store = AppStore(customers: access);
    addTearDown(store.dispose);
    store.bindCompany('co1');
    final customer = testCustomer();
    await store.upsertCustomer(customer);
    final saved = access.customers['co1']![customer.id]!;
    expect(
      saved.toMap().keys,
      containsAll(['id', 'createdAt', 'updatedAt', 'deletedAt']),
    );
    expect(saved.id, customer.id);
    expect(saved.name, customer.name);
    expect(saved.deletedAt, isNull);
    expect(store.customerById(customer.id), isNotNull);
  });

  test('addCustomer trims the name and persists the document', () async {
    final access = FakeCustomerAccess();
    final store = AppStore(customers: access);
    addTearDown(store.dispose);
    store.bindCompany('co1');
    final created = await store.addCustomer(
      name: '  Juan Pérez  ',
      phone: ' +54 9 11 0000-0000 ',
    );
    expect(created.name, 'Juan Pérez');
    expect(created.phone, '+54 9 11 0000-0000');
    expect(created.cuit, isNull);
    expect(created.taxCondition, isNull);
    expect(store.customers.first.id, created.id);
    final saved = access.customers['co1']![created.id]!;
    expect(saved.name, 'Juan Pérez');
    expect(saved.createdAt, isNotNull);
    expect(saved.updatedAt, isNotNull);
    expect(saved.deletedAt, isNull);
  });

  test('setCustomerPhone updates the agenda and open orders', () async {
    final access = FakeCustomerAccess();
    final store = AppStore(customers: access);
    addTearDown(store.dispose);
    store.bindCompany('co1');
    final customer = await seedTestCustomer(store);
    final order = store.createOrder(customer);
    await store.setCustomerPhone(customer.id, '+54 9 11 9999-0000');
    expect(store.customerById(customer.id)!.phone, '+54 9 11 9999-0000');
    expect(order.customer.phone, '+54 9 11 9999-0000');
    expect(
      access.customers['co1']![customer.id]!.phone,
      '+54 9 11 9999-0000',
    );
  });

  test('deleteCustomer soft-deletes and leaves the live list', () async {
    final access = FakeCustomerAccess();
    final store = AppStore(customers: access);
    addTearDown(store.dispose);
    store.bindCompany('co1');
    final customer = await seedTestCustomer(store);
    await store.deleteCustomer(customer.id);
    expect(store.customerById(customer.id), isNull);
    final saved = access.customers['co1']![customer.id]!;
    expect(saved.isDeleted, isTrue);
    expect(saved.deletedAt, isNotNull);
  });

  test('upsertCustomer copies the name into existing orders', () async {
    final store = AppStore();
    addTearDown(store.dispose);
    final customer = await seedTestCustomer(store);
    final order = store.createOrder(customer);
    await store.upsertCustomer(customer.copyWith(name: 'Boutique Abril'));
    expect(store.customerById(customer.id)!.name, 'Boutique Abril');
    expect(order.customer.name, 'Boutique Abril');
  });
}
