import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/features/order/order_card.dart';
import 'package:store_app/features/order/orders_page.dart';
import 'package:store_app/models/order.dart';
import 'package:store_app/routing/app_router.dart';
import 'package:store_app/theme/tokens.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/session_harness.dart';

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _pageApp(AppStore store) {
  return ChangeNotifierProvider.value(
    value: store,
    child: const MaterialApp(home: Scaffold(body: OrdersPage())),
  );
}

Widget _routerApp({
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

Future<void> _openClosedTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('orders-tab-closed')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('orders page shows closed orders in a related tab', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    expect(store.closeOrder(order.id), isTrue);

    await tester.pumpWidget(_pageApp(store));
    await tester.pump();

    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.byKey(const ValueKey('orders-tab-open')), findsOneWidget);
    expect(find.byKey(const ValueKey('orders-tab-closed')), findsOneWidget);
    expect(find.text('Todavía no hay pedidos abiertos.'), findsOneWidget);
    expect(find.text('Cerrados'), findsOneWidget);

    await _openClosedTab(tester);

    expect(find.byKey(ValueKey('closed-order-${order.id}')), findsOneWidget);
    expect(find.text(order.customer.name), findsOneWidget);
    expect(find.textContaining(order.orderNumber), findsOneWidget);
    expect(find.text('Cerrado'), findsOneWidget);
  });

  testWidgets('orders page switches between open and closed orders', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final closed = await seedTestOrder(store);
    expect(store.closeOrder(closed.id), isTrue);
    final open = await seedTestOrder(store);

    await tester.pumpWidget(_pageApp(store));
    await tester.pump();

    expect(find.text('Abiertos (1)'), findsOneWidget);
    expect(find.text('Cerrados'), findsOneWidget);
    expect(find.textContaining(open.orderNumber), findsOneWidget);

    await _openClosedTab(tester);

    expect(find.byKey(ValueKey('closed-order-${closed.id}')), findsOneWidget);
    expect(find.text('Cerrado'), findsOneWidget);
  });

  testWidgets('tapping a closed order opens the billing view', (tester) async {
    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final order = await seedTestOrder(store);
    expect(store.closeOrder(order.id), isTrue);
    final router = createRouter(session);

    await tester.pumpWidget(
      _routerApp(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/pedido');
    await tester.pumpAndSettle();
    await _openClosedTab(tester);
    await tester.ensureVisible(
      find.byKey(ValueKey('closed-order-${order.id}')),
    );
    await tester.tap(find.byKey(ValueKey('closed-order-${order.id}')));
    await tester.pumpAndSettle();

    expect(find.text('MODA STOCK'), findsOneWidget);
    expect(find.textContaining('RESUMEN DE FACTURA'), findsOneWidget);
    expect(find.textContaining('by MODA STOCK'), findsOneWidget);
    expect(find.text('Total a facturar'), findsOneWidget);
  });

  testWidgets('orders page search filters open orders by customer', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final monica = await seedTestCustomer(store);
    final ana = await seedTestCustomer(
      store,
      customer: testCustomer(id: 'c-ana', name: 'Ana López'),
    );
    store.createOrder(monica);
    store.createOrder(ana);

    await tester.pumpWidget(_pageApp(store));
    await tester.pump();

    expect(find.text('Mónica Fernández'), findsOneWidget);
    expect(find.text('Ana López'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('orders-search')), 'Ana');
    await tester.pump();

    expect(find.text('Ana López'), findsOneWidget);
    expect(find.text('Mónica Fernández'), findsNothing);
    expect(find.text('Abiertos (1)'), findsOneWidget);
  });

  testWidgets('orders page search can clear and restore the list', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final closed = await seedTestOrder(store);
    expect(store.closeOrder(closed.id), isTrue);
    final open = await seedTestOrder(store);

    await tester.pumpWidget(_pageApp(store));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('orders-search')),
      'sin-resultados',
    );
    await tester.pump();

    expect(find.text('No encontramos pedidos'), findsAtLeastNWidgets(1));
    expect(find.textContaining(open.orderNumber), findsNothing);

    await tester.tap(find.byKey(const ValueKey('search-clear')));
    await tester.pump();

    expect(find.textContaining(open.orderNumber), findsOneWidget);
    expect(find.text('No encontramos pedidos'), findsNothing);
  });

  testWidgets('more page no longer lists closed orders', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    final order = await seedTestOrder(store);
    expect(store.closeOrder(order.id), isTrue);
    final router = createRouter(session);

    await tester.pumpWidget(
      _routerApp(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();

    router.go('/mas');
    await tester.pumpAndSettle();

    expect(find.text('Pedidos cerrados'), findsNothing);
    expect(find.text(order.orderNumber), findsNothing);
  });

  testWidgets(
    'open orders show reserved balance on the border and can be sorted',
    (tester) async {
      _setPhoneView(tester);
      final store = AppStore();
      addTearDown(store.dispose);
      await _reservedOrder(
        store,
        customerId: 'c-ana',
        customerName: 'Ana López',
        productId: 'p-ana',
        quantity: 1,
        paid: 10000,
      );
      _tickClock();
      await _reservedOrder(
        store,
        customerId: 'c-bruno',
        customerName: 'Bruno Díaz',
        productId: 'p-bruno',
        quantity: 2,
      );
      _tickClock();
      await _reservedOrder(
        store,
        customerId: 'c-carla',
        customerName: 'Carla Ruiz',
        productId: 'p-carla',
        quantity: 3,
      );

      await tester.pumpWidget(_pageApp(store));
      await tester.pump();

      expect(_borderFor(tester, 'Ana López').top.color, AppColors.lightBorder);
      expect(_borderFor(tester, 'Bruno Díaz').top.color, AppColors.lightBorder);
      expect(_borderFor(tester, 'Carla Ruiz').top.color, AppColors.lightBorder);

      await tester.tap(find.byKey(const ValueKey('orders-remaining-view')));
      await tester.pump();

      expect(_borderFor(tester, 'Ana López').top.color, AppColors.lightBorder);
      expect(_borderFor(tester, 'Ana López').top.width, 1);
      expect(_borderFor(tester, 'Bruno Díaz').top.color, AppColors.stockGap);
      expect(_borderFor(tester, 'Bruno Díaz').top.width, 2);
      expect(_borderFor(tester, 'Carla Ruiz').top.color, AppColors.stockLow);
      expect(_borderFor(tester, 'Carla Ruiz').top.width, 2);
      expect(_customerNames(tester), ['Carla Ruiz', 'Bruno Díaz', 'Ana López']);

      await _chooseSort(tester, 'Cliente');
      expect(_customerNames(tester), ['Ana López', 'Bruno Díaz', 'Carla Ruiz']);

      await _chooseSort(tester, 'Falta pagar');
      expect(_customerNames(tester), ['Carla Ruiz', 'Bruno Díaz', 'Ana López']);
    },
  );

  testWidgets(
    'remaining view replaces garment names and restores the previous sort',
    (tester) async {
      _setPhoneView(tester);
      final store = AppStore();
      addTearDown(store.dispose);
      await _reservedOrder(
        store,
        customerId: 'c-ana',
        customerName: 'Ana López',
        productId: 'p-ana',
        productName: 'Camisa',
        quantity: 1,
        paid: 10000,
      );
      _tickClock();
      await _reservedOrder(
        store,
        customerId: 'c-bruno',
        customerName: 'Bruno Díaz',
        productId: 'p-bruno',
        productName: 'Pantalón',
        quantity: 2,
      );

      final ana = store.orders.firstWhere(
        (order) => order.customer.name == 'Ana López',
      );
      expect(
        store.setOrderPayments(ana.id, [
          OrderPayment(amount: 2000, createdAt: DateTime.utc(2026, 1, 2)),
        ]),
        isTrue,
      );

      await tester.pumpWidget(_pageApp(store));
      await tester.pump();

      await _chooseSort(tester, 'Cliente');
      expect(_customerNames(tester), ['Ana López', 'Bruno Díaz']);
      expect(find.text('Camisa'), findsOneWidget);
      expect(find.text('Pantalón'), findsOneWidget);
      expect(find.text('Remeras ×1'), findsOneWidget);
      expect(find.text('Remeras ×2'), findsOneWidget);
      expect(find.text('Seña'), findsNothing);
      expect(find.text('Pago'), findsNothing);
      expect(find.text('Restante'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('orders-remaining-view')));
      await tester.pump();

      expect(find.text('Restante'), findsNWidgets(2));
      expect(find.text('Seña'), findsOneWidget);
      expect(find.text('\$10.000,00'), findsNWidgets(2));
      expect(find.text('Pago'), findsOneWidget);
      expect(find.text('\$2.000,00'), findsOneWidget);
      expect(find.text('Camisa'), findsNothing);
      expect(find.text('Pantalón'), findsNothing);
      expect(find.text('Remeras ×1'), findsNothing);
      expect(find.text('Remeras ×2'), findsNothing);
      expect(_customerNames(tester), ['Bruno Díaz', 'Ana López']);

      await tester.tap(find.byKey(const ValueKey('orders-remaining-view')));
      await tester.pump();

      expect(find.text('Camisa'), findsOneWidget);
      expect(find.text('Pantalón'), findsOneWidget);
      expect(find.text('Remeras ×1'), findsOneWidget);
      expect(find.text('Remeras ×2'), findsOneWidget);
      expect(find.text('Seña'), findsNothing);
      expect(find.text('Pago'), findsNothing);
      expect(find.text('Restante'), findsNothing);
      expect(_customerNames(tester), ['Ana López', 'Bruno Díaz']);
    },
  );

  testWidgets(
    'unpaid orders without a deposit color the border by remaining',
    (tester) async {
      _setPhoneView(tester);
      final store = AppStore();
      addTearDown(store.dispose);
      await _reservedOrder(
        store,
        customerId: 'c-dora',
        customerName: 'Dora Paz',
        productId: 'p-dora',
        quantity: 1,
        saveStock: false,
      );
      await _reservedOrder(
        store,
        customerId: 'c-elena',
        customerName: 'Elena Díaz',
        productId: 'p-elena',
        quantity: 3,
        saveStock: false,
      );
      await _reservedOrder(
        store,
        customerId: 'c-fabio',
        customerName: 'Fabio Ruiz',
        productId: 'p-fabio',
        quantity: 3,
        paid: 5000,
        saveStock: false,
      );

      await tester.pumpWidget(_pageApp(store));
      await tester.pump();

      expect(_borderFor(tester, 'Dora Paz').top.color, AppColors.lightBorder);
      expect(_borderFor(tester, 'Elena Díaz').top.color, AppColors.lightBorder);
      expect(_borderFor(tester, 'Fabio Ruiz').top.color, AppColors.lightBorder);

      await tester.tap(find.byKey(const ValueKey('orders-remaining-view')));
      await tester.pump();

      expect(_borderFor(tester, 'Dora Paz').top.color, AppColors.stockGap);
      expect(_borderFor(tester, 'Elena Díaz').top.color, AppColors.stockLow);
      expect(_borderFor(tester, 'Fabio Ruiz').top.color, AppColors.lightBorder);
    },
  );

  testWidgets(
    'falta pagar sorts an unpaid order above one with a smaller remaining',
    (tester) async {
      _setPhoneView(tester);
      final store = AppStore();
      addTearDown(store.dispose);
      await _reservedOrder(
        store,
        customerId: 'c-hugo',
        customerName: 'Hugo Paz',
        productId: 'p-hugo',
        quantity: 3,
        saveStock: false,
      );
      _tickClock();
      await _reservedOrder(
        store,
        customerId: 'c-ines',
        customerName: 'Inés Díaz',
        productId: 'p-ines',
        quantity: 2,
        paid: 10000,
      );

      await tester.pumpWidget(_pageApp(store));
      await tester.pump();

      await _chooseSort(tester, 'Falta pagar');
      expect(_customerNames(tester), ['Hugo Paz', 'Inés Díaz']);
    },
  );
}

Future<void> _reservedOrder(
  AppStore store, {
  required String customerId,
  required String customerName,
  required String productId,
  required int quantity,
  String productName = 'Remera test',
  double paid = 0,
  bool saveStock = true,
}) async {
  final product = testProduct(
    id: productId,
    name: productName,
    stock: 10,
    price: 10000,
  );
  await store.upsertProduct(product);
  final customer = await seedTestCustomer(
    store,
    customer: testCustomer(id: customerId, name: customerName),
  );
  final order = store.createOrder(customer);
  final live = store.productById(productId)!;
  expect(
    store.addToOrder(live, live.variants.first, orderId: order.id),
    isTrue,
  );
  if (quantity != 1) {
    store.setLineQty(order.id, order.lines.first.lineKey, quantity);
  }
  if (saveStock) {
    expect(store.saveOrderStock(order.id), SaveStockResult.saved);
  }
  if (paid > 0) {
    expect(store.setOrderSena(order.id, paid), isTrue);
  }
}

Border _borderFor(WidgetTester tester, String customerName) {
  final card = find.widgetWithText(OrderSummaryCard, customerName);
  final ink = find.descendant(of: card, matching: find.byType(Ink));
  final decoration = tester.widget<Ink>(ink).decoration! as BoxDecoration;
  return decoration.border! as Border;
}

List<String> _customerNames(WidgetTester tester) {
  return [
    for (final card in tester.widgetList<OrderSummaryCard>(
      find.byType(OrderSummaryCard),
    ))
      card.order.customer.name,
  ];
}

void _tickClock() {
  final start = DateTime.now();
  while (!DateTime.now().isAfter(start)) {}
}

Future<void> _chooseSort(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('orders-sort')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(
    find.widgetWithText(CheckedPopupMenuItem<OrderListSort>, label),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
