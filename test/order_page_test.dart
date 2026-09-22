import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/features/order/order_page.dart';

import 'fakes/catalog_harness.dart';

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(AppStore store, String orderId) {
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(
      home: Scaffold(body: OrderPage(orderId: orderId)),
    ),
  );
}

void main() {
  testWidgets('order page shows a subtle customer change with a confirm hint', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);

    await tester.pumpWidget(_app(store, order.id));
    await tester.pump();

    expect(find.text(order.customer.name), findsOneWidget);
    expect(find.text('Cambiar'), findsOneWidget);
    expect(
      find.text('Se pedirá confirmación antes de cambiar el cliente.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('changing the order customer asks for confirmation', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    final ana = await seedTestCustomer(
      store,
      customer: testCustomer(id: 'c-ana', name: 'Ana López'),
    );

    await tester.pumpWidget(_app(store, order.id));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('change-order-customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ana.name));
    await tester.pumpAndSettle();

    expect(find.text('Cambiar cliente'), findsOneWidget);
    expect(
      find.text(
        'El pedido se va a asignar a Ana López. Confirmá para completar el cambio.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(order.customer.id, 'c-test');

    await tester.tap(find.text(ana.name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(order.customer.id, ana.id);
    expect(find.text(ana.name), findsOneWidget);
  });

  testWidgets('closed orders do not offer a customer change', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    expect(store.closeOrder(order.id), isTrue);

    await tester.pumpWidget(_app(store, order.id));
    await tester.pump();

    expect(find.text('Cambiar'), findsNothing);
    expect(
      find.text('Se pedirá confirmación antes de cambiar el cliente.'),
      findsNothing,
    );
  });

  testWidgets('active orders offer cancel and keep the order if dismissed', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);

    await tester.pumpWidget(_app(store, order.id));
    await tester.pump();

    expect(find.text('WhatsApp'), findsNothing);
    expect(find.text('Guardar stock'), findsOneWidget);
    expect(find.text('Cerrar pedido'), findsOneWidget);
    expect(find.byKey(const ValueKey('cancel-order')), findsOneWidget);

    final stock = tester.getRect(
      find.byKey(const ValueKey('save-order-stock')),
    );
    final close = tester.getRect(find.text('Cerrar pedido'));
    expect((stock.center.dy - close.center.dy).abs(), lessThan(8));
    expect(stock.height, lessThan(48));

    await tester.ensureVisible(find.byKey(const ValueKey('cancel-order')));
    await tester.tap(find.byKey(const ValueKey('cancel-order')));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar pedido'), findsWidgets);
    expect(
      find.text(
        '¿Cancelar ${order.orderNumber}? El pedido se elimina y el cliente queda libre para uno nuevo.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(store.orders, hasLength(1));
    expect(store.orderById(order.id), isNotNull);
    expect(store.orderById(order.id)!.isDeleted, isFalse);
  });

  testWidgets('closed orders do not offer cancel', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    expect(store.closeOrder(order.id), isTrue);

    await tester.pumpWidget(_app(store, order.id));
    await tester.pump();

    expect(find.byKey(const ValueKey('cancel-order')), findsNothing);
    expect(find.text('Cancelar pedido'), findsNothing);
    expect(find.byKey(const ValueKey('save-order-stock')), findsNothing);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.byKey(const ValueKey('reopen-order')), findsOneWidget);
  });

  testWidgets('reopening a closed order keeps reserved stock and unlocks edits', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    expect(store.closeOrder(order.id), isTrue);
    final stockAfterClose = store.productById('p-test')!.variants.first.stock;

    await tester.pumpWidget(_app(store, order.id));
    await tester.pump();

    expect(find.text('Pedido cerrado'), findsOneWidget);
    expect(find.text('Reabrir pedido'), findsOneWidget);
    expect(find.text('Cambiar'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('reopen-order')));
    await tester.tap(find.byKey(const ValueKey('reopen-order')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'El pedido vuelve a estar activo. El stock reservado se mantiene y podés modificar las prendas.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Reabrir pedido').last);
    await tester.pumpAndSettle();

    expect(order.isActive, isTrue);
    expect(store.productById('p-test')!.variants.first.stock, stockAfterClose);
    expect(find.text('Armar pedido'), findsOneWidget);
    expect(find.text('Stock guardado'), findsOneWidget);
    expect(find.text('Cambiar'), findsOneWidget);
    expect(
      find.text('Pedido reabierto. El stock sigue reservado.'),
      findsOneWidget,
    );
  });

  testWidgets('save stock reserves units and re-enables after an edit', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);

    await tester.pumpWidget(_app(store, order.id));
    await tester.pump();

    final button = find.byKey(const ValueKey('save-order-stock'));
    expect(find.text('Guardar stock'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(store.productById('p-test')!.variants.first.stock, 9);
    expect(find.text('Stock guardado'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(
      find.text('Stock reservado. El disponible ya se actualizó.'),
      findsOneWidget,
    );

    store.setLineQty(order.id, order.lines.first.lineKey, 2);
    await tester.pump();

    expect(find.text('Guardar stock'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);

    await tester.tap(button);
    await tester.pump();

    expect(store.productById('p-test')!.variants.first.stock, 8);
    expect(order.stockNeedsSave, isFalse);
  });
}
