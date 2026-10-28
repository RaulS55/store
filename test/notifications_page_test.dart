import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/catalog_guest_store.dart';
import 'package:store_app/features/notifications/notifications_page.dart';
import 'package:store_app/models/catalog_request.dart';
import 'package:store_app/models/company.dart';
import 'package:store_app/models/record_source.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_catalog_request_access.dart';
import 'fakes/fake_company_access.dart';
import 'fakes/fake_customer_access.dart';
import 'fakes/fake_order_access.dart';
import 'fakes/fake_product_access.dart';

Company _company() {
  return Company(
    id: 'co1',
    name: 'Moda Stock',
    ownerId: 'u1',
    createdAt: DateTime.utc(2026, 9, 11),
    phone: '+54 9 11 4555-0101',
  );
}

Future<CatalogGuestStore> _guest({
  required FakeCompanyAccess companies,
  required FakeProductAccess products,
  required FakeCustomerAccess customers,
  required FakeOrderAccess orders,
  required FakeCatalogRequestAccess requests,
}) async {
  final store = CatalogGuestStore(
    companyId: 'co1',
    companies: companies,
    products: products,
    customers: customers,
    orders: orders,
    requests: requests,
  );
  await store.ready;
  return store;
}

void main() {
  testWidgets('approving a catalog request loads it as an order', (
    tester,
  ) async {
    final companies = FakeCompanyAccess()..companies['co1'] = _company();
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    final customers = FakeCustomerAccess();
    final orders = FakeOrderAccess();
    final requests = FakeCatalogRequestAccess();
    final guest = await _guest(
      companies: companies,
      products: products,
      customers: customers,
      orders: orders,
      requests: requests,
    );
    addTearDown(guest.dispose);
    final product = guest.visibleProducts.single;
    guest.addToCart(product, product.variants.first, quantity: 2);
    await guest.submit(name: 'Juan Pérez', phone: '+54 9 11 5555-1234');

    final business = AppStore(
      customers: customers,
      orderAccess: orders,
      catalogRequests: requests,
    );
    addTearDown(business.dispose);
    business.bindCompany('co1');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: business,
        child: const MaterialApp(home: Scaffold(body: NotificationsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juan Pérez (Catalogo)'), findsOneWidget);
    expect(find.text('+54 9 11 5555-1234'), findsOneWidget);
    expect(find.textContaining('Pedido nuevo del catálogo'), findsOneWidget);
    expect(find.text('2× TST-0001-M-NEGRO · Remera test M'), findsOneWidget);

    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();

    expect(find.text('Aprobar'), findsNothing);
    expect(find.text('Rechazar'), findsNothing);
    expect(find.text('Aprobado'), findsOneWidget);
    expect(find.text('Juan Pérez (Catalogo)'), findsOneWidget);
    expect(find.text('+54 9 11 5555-1234'), findsOneWidget);
    expect(find.byKey(const ValueKey('notifications-empty')), findsNothing);

    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del pedido'), findsOneWidget);
    expect(
      find.textContaining('2× TST-0001-M-NEGRO · Remera test M'),
      findsOneWidget,
    );
    final order = orders.orders['co1']!.values.single;
    expect(order.orderNumber, startsWith('WEB-'));
    expect(order.isCatalog, isTrue);
    expect(order.customer.name, 'Juan Pérez (Catalogo)');
    expect(order.customer.source, RecordSource.catalog);
    expect(order.lines.single.quantity, 2);
    expect(order.ivaEnabled, isFalse);
    expect(customers.customers['co1']!.values.single.isCatalog, isTrue);
    expect(requests.requests['co1']!.values.single.isApproved, isTrue);
    expect(guest.openOrder?.orderId, order.id);
  });

  testWidgets('rejecting a catalog request does not create an order', (
    tester,
  ) async {
    final companies = FakeCompanyAccess()..companies['co1'] = _company();
    final products = FakeProductAccess();
    await products.saveProduct('co1', testProduct());
    final customers = FakeCustomerAccess();
    final orders = FakeOrderAccess();
    final requests = FakeCatalogRequestAccess();
    final guest = await _guest(
      companies: companies,
      products: products,
      customers: customers,
      orders: orders,
      requests: requests,
    );
    addTearDown(guest.dispose);
    final product = guest.visibleProducts.single;
    guest.addToCart(product, product.variants.first);
    await guest.submit(name: 'Ana', phone: '+54 9 11 5555-1234');

    final business = AppStore(
      customers: customers,
      orderAccess: orders,
      catalogRequests: requests,
    );
    addTearDown(business.dispose);
    business.bindCompany('co1');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: business,
        child: const MaterialApp(home: Scaffold(body: NotificationsPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rechazar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, rechazar'));
    await tester.pumpAndSettle();

    expect(find.text('Rechazar'), findsNothing);
    expect(find.text('Aprobar'), findsNothing);
    expect(find.text('Rechazado'), findsOneWidget);
    expect(find.text('Ana (Catalogo)'), findsOneWidget);
    expect(find.byKey(const ValueKey('notifications-empty')), findsNothing);

    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del pedido'), findsOneWidget);
    expect(find.text('No se cargó en Pedidos.'), findsOneWidget);
    expect(orders.orders['co1'], isNull);
    expect(requests.requests['co1']!.values.single.isRejected, isTrue);
    expect(guest.pendingCartLines, isNotEmpty);
  });

  testWidgets('keeps every pending request and pages answered ones on scroll', (
    tester,
  ) async {
    final requests = FakeCatalogRequestAccess();
    Future<void> save({
      required String id,
      required String name,
      required CatalogRequestStatus status,
      required DateTime at,
    }) {
      return requests.saveRequest(
        'co1',
        CatalogRequest(
          id: id,
          customerName: name,
          status: status,
          createdAt: at,
          updatedAt: at,
          resolvedAt: status == CatalogRequestStatus.pendiente ? null : at,
        ),
      );
    }

    await save(
      id: 'pending-new',
      name: 'Pendiente nueva',
      status: CatalogRequestStatus.pendiente,
      at: DateTime.utc(2026, 10, 28, 12),
    );
    await save(
      id: 'pending-old',
      name: 'Pendiente vieja',
      status: CatalogRequestStatus.pendiente,
      at: DateTime.utc(2026, 10, 1, 8),
    );
    for (var i = 0; i < 14; i++) {
      await save(
        id: 'resolved-$i',
        name: 'Resuelta $i',
        status: CatalogRequestStatus.aprobado,
        at: DateTime.utc(2026, 10, 20, 23 - i),
      );
    }

    final business = AppStore(catalogRequests: requests);
    addTearDown(business.dispose);
    business.bindCompany('co1');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: business,
        child: const MaterialApp(home: Scaffold(body: NotificationsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('resolved-window-12')), findsOneWidget);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('notification-pending-new')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('notification-resolved-0')))
            .dy,
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('notification-pending-old')),
      400,
    );
    expect(
      find.byKey(const ValueKey('notification-pending-old')),
      findsOneWidget,
    );

    await tester.fling(find.byType(ListView), const Offset(0, -4000), 5000);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('resolved-window-14')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notification-resolved-13')),
      findsOneWidget,
    );
  });
}
