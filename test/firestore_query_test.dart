import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/firestore_query.dart';
import 'package:store_app/models/customer.dart';

import 'fakes/catalog_harness.dart';

void main() {
  test('catalogSyncFilters asks for live rows until a cursor exists', () {
    expect(catalogSyncFilters(null).single.field, 'deletedAt');
    expect(catalogSyncFilters(null).single.isNull, isTrue);

    final since = DateTime.utc(2026, 9, 21, 12);
    final filters = catalogSyncFilters(since);
    expect(filters.single.field, 'updatedAt');
    expect(filters.single.op, '>');
    expect(filters.single.value, since.toIso8601String());
  });

  test('FirestoreDoc reads the company id from a nested path', () {
    const doc = FirestoreDoc(
      id: 'inv-1',
      data: {},
      path: 'companies/co-9/invitations/inv-1',
    );
    expect(doc.parentDocumentId, 'co-9');
    expect(const FirestoreDoc(id: 'x', data: {}).parentDocumentId, isNull);
  });

  test('mapFirestoreDocs keeps valid rows and skips broken ones', () {
    final customer = testCustomer();
    final items = mapFirestoreDocs(
      docs: [
        FirestoreDoc(id: customer.id, data: customer.toMap()),
        const FirestoreDoc(id: 'bad', data: {'name': 1, 'createdAt': 0}),
      ],
      fromMap: Customer.fromMap,
      label: 'Customer',
    );
    expect(items, hasLength(1));
    expect(items.single.id, customer.id);
    expect(items.single.name, customer.name);
  });
}
