import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/features/order/invoice_page.dart';
import 'package:store_app/features/order/order_actions.dart';
import 'package:store_app/routing/app_router.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/session_harness.dart';

Widget _app({
  required AppStore store,
  required SessionStore session,
  required GoRouter router,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider.value(value: session),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('closed order shows the billing summary', (tester) async {
    final store = AppStore();
    final order = await seedTestOrder(store);
    expect(store.closeOrder(order.id), isTrue);
    final closed = store.closedOrders.first;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(home: InvoicePage(orderId: closed.id)),
      ),
    );

    expect(find.text('Factura'), findsOneWidget);
    expect(find.text('RESUMEN DE FACTURA'), findsOneWidget);
    expect(find.text('Total a facturar'), findsOneWidget);
    expect(find.text(closed.orderNumber), findsOneWidget);
    expect(find.text(closed.customer.name), findsOneWidget);
    expect(find.text('Cerrar pedido'), findsNothing);
    expect(find.text('Volver al cliente'), findsOneWidget);
    expect(find.textContaining('IVA ('), findsNothing);
  });

  testWidgets('closing an order opens the billing view', (tester) async {
    final store = AppStore();
    final session = await signedInOwnerSession();
    final order = await seedTestOrder(store);
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/pedido/${order.id}');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('RESUMEN DE FACTURA'), findsOneWidget);
    expect(find.text('Total a facturar'), findsOneWidget);
    expect(order.isClosed, isTrue);
  });

  testWidgets('customers history opens billing for a closed order', (
    tester,
  ) async {
    final store = AppStore();
    final session = await signedInOwnerSession();
    final order = await seedTestOrder(store);
    expect(store.closeOrder(order.id), isTrue);
    final closed = store.closedOrders.first;
    final router = createRouter(session);

    await tester.pumpWidget(
      _app(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/clientes/${closed.customer.id}');
    await tester.pumpAndSettle();
    await tester.tap(find.text(closed.orderNumber));
    await tester.pumpAndSettle();

    expect(find.text('RESUMEN DE FACTURA'), findsOneWidget);
    expect(find.text('Total a facturar'), findsOneWidget);
  });

  test('invoice route points to the billing view of the order', () {
    expect(invoiceRoute('o1'), '/pedido/o1/facturar');
  });

  testWidgets('WhatsApp phone dialog survives the close animation', (
    tester,
  ) async {
    final store = AppStore();
    addTearDown(store.dispose);
    await store.upsertProduct(testProduct());
    final product = store.productById('p-test')!;
    final customer = await seedTestCustomer(
      store,
      customer: testCustomer(phone: null),
    );
    final order = store.createOrder(customer);
    store.addToOrder(product, product.variants.first);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          home: Scaffold(
            body: WhatsAppButton(order: store.orderById(order.id)!),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Enviar por WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.text('WhatsApp'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '+54 9 11 4555-0101');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('WhatsApp'), findsNothing);
    expect(store.customerById(customer.id)!.phone, '+54 9 11 4555-0101');
  });
}
