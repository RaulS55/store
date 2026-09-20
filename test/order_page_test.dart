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
}
