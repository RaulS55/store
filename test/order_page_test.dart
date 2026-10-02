import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/invoice_pdf.dart';
import 'package:store_app/features/order/order_actions.dart';
import 'package:store_app/features/order/order_page.dart';
import 'package:store_app/models/order.dart';

import 'fakes/catalog_harness.dart';

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  AppStore store,
  String orderId, {
  InvoiceSharer shareInvoice = shareInvoicePdf,
}) {
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(
      home: Scaffold(
        body: OrderPage(orderId: orderId, shareInvoice: shareInvoice),
      ),
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
    expect(find.text('Subtotal'), findsNothing);
    expect(find.text('Total'), findsOneWidget);
  });

  testWidgets('order totals show subtotal only when IVA is enabled', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);

    await tester.pumpWidget(_app(store, order.id));
    await tester.pump();
    expect(find.text('Subtotal'), findsNothing);

    store.setIvaEnabled(true);
    await tester.pump();
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.textContaining('IVA ('), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
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
    expect(find.byKey(const ValueKey('share-order')), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-order-sena')), findsOneWidget);

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
    expect(find.byKey(const ValueKey('share-order')), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-order-sena')), findsNothing);
    expect(find.byKey(const ValueKey('save-order-stock')), findsNothing);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.byKey(const ValueKey('reopen-order')), findsOneWidget);
  });

  testWidgets('open orders can share the current invoice pdf', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    DraftOrder? shared;
    bool? includeCode;

    await tester.pumpWidget(
      _app(
        store,
        order.id,
        shareInvoice: (value, {includeProductCode, sharePositionOrigin}) async {
          shared = value;
          includeCode = includeProductCode;
          return true;
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('share-order')));
    await tester.pump();
    await tester.pump();

    expect(shared?.id, order.id);
    expect(shared?.isClosed, isFalse);
    expect(includeCode, isTrue);
    expect(find.text('No se pudo compartir la factura.'), findsNothing);
  });

  testWidgets('open orders can load a deposit from the app bar', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);

    await tester.pumpWidget(_app(store, order.id));
    await tester.pump();

    expect(find.text('Seña'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('edit-order-sena')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Cantidad ya pagada. Se usa al facturar y al cerrar el pedido.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('edit-order-sena-field')),
      '2500',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(order.sena, 2500);
    expect(find.text('Seña'), findsOneWidget);
    expect(find.text('Restante'), findsOneWidget);
    expect(find.text(r'$2.500,00'), findsOneWidget);
    expect(find.text(r'$7.500,00'), findsOneWidget);
  });

  testWidgets('closing an order prefills the loaded deposit', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    store.setSenaAmount(5000);
    expect(store.setOrderSena(order.id, 2500), isTrue);

    await tester.pumpWidget(_app(store, order.id));
    await tester.pump();
    await tester.ensureVisible(find.text('Cerrar pedido'));
    await tester.tap(find.text('Cerrar pedido'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('order-sena-field')))
          .controller!
          .text,
      '2.500',
    );
  });

  testWidgets('empty orders cannot share an invoice pdf', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final customer = await seedTestCustomer(store);
    final order = store.createOrder(customer);
    var shared = false;

    await tester.pumpWidget(
      _app(
        store,
        order.id,
        shareInvoice: (value, {includeProductCode, sharePositionOrigin}) async {
          shared = true;
          return true;
        },
      ),
    );
    await tester.pump();

    final button = tester.widget<IconButton>(
      find.byKey(const ValueKey('share-order')),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('share-order')));
    await tester.pump();
    expect(shared, isFalse);
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
    expect(find.text('Restablecer stock'), findsOneWidget);
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
    expect(find.text('Restablecer stock'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
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

  testWidgets('active orders let staff change the sale price of a line', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);

    await tester.pumpWidget(_app(store, order.id));
    await tester.pump();

    expect(find.text(r'$10.000,00'), findsWidgets);
    await tester.ensureVisible(find.byKey(const ValueKey('edit-line-price')));
    await tester.tap(find.byKey(const ValueKey('edit-line-price')));
    await tester.pumpAndSettle();

    expect(find.text('Precio de venta'), findsOneWidget);
    expect(find.text(r'Lista: $10.000,00'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('line-unit-price-field')),
      '8000',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(order.lines.first.unitPrice, 8000);
    expect(order.subtotal, 8000);
    expect(find.text(r'$8.000,00'), findsWidgets);
    expect(find.text(r'Lista: $10.000,00'), findsOneWidget);
    expect(store.productById('p-test')!.price, 10000);
  });

  testWidgets('closed orders do not offer a line price change', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    store.setLineUnitPrice(order.id, order.lines.first.lineKey, 8000);
    expect(store.closeOrder(order.id), isTrue);

    await tester.pumpWidget(_app(store, order.id));
    await tester.pump();

    expect(find.byKey(const ValueKey('edit-line-price')), findsNothing);
    expect(find.text(r'$8.000,00'), findsWidgets);
    expect(find.text(r'Lista: $10.000,00'), findsOneWidget);
  });

  testWidgets(
    'an unreserved line shows out of stock after another order takes the last unit',
    (tester) async {
      _setPhoneView(tester);
      final store = AppStore();
      addTearDown(store.dispose);
      await store.upsertProduct(testProduct(stock: 1));
      final product = store.productById('p-test')!;
      final firstCustomer = await seedTestCustomer(store);
      final secondCustomer = await seedTestCustomer(
        store,
        customer: testCustomer(id: 'c-2', name: 'Carla Pérez'),
      );
      final first = store.createOrder(firstCustomer);
      expect(
        store.addToOrder(product, product.variants.first, orderId: first.id),
        isTrue,
      );
      final second = store.createOrder(secondCustomer);
      expect(
        store.addToOrder(product, product.variants.first, orderId: second.id),
        isTrue,
      );
      expect(store.saveOrderStock(first.id), SaveStockResult.saved);
      expect(store.closeOrder(first.id), isTrue);

      await tester.pumpWidget(_app(store, second.id));
      await tester.pump();

      expect(find.text('Sin stock'), findsOneWidget);
      expect(find.text(product.name), findsOneWidget);
    },
  );

  testWidgets(
    'a reserved line does not show out of stock when live units are zero',
    (tester) async {
      _setPhoneView(tester);
      final store = AppStore();
      addTearDown(store.dispose);
      await store.upsertProduct(testProduct(stock: 1));
      final product = store.productById('p-test')!;
      final customer = await seedTestCustomer(store);
      final order = store.createOrder(customer);
      expect(
        store.addToOrder(product, product.variants.first, orderId: order.id),
        isTrue,
      );
      expect(store.saveOrderStock(order.id), SaveStockResult.saved);
      expect(store.productById('p-test')!.variants.first.stock, 0);

      await tester.pumpWidget(_app(store, order.id));
      await tester.pump();

      expect(find.text('Sin stock'), findsNothing);
      expect(find.text('Restablecer stock'), findsOneWidget);
    },
  );

  testWidgets('reset stock asks for confirmation and returns reserved units', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    final order = await seedTestOrder(store);
    expect(store.saveOrderStock(order.id), SaveStockResult.saved);

    await tester.pumpWidget(_app(store, order.id));
    await tester.pump();

    final button = find.byKey(const ValueKey('save-order-stock'));
    expect(find.text('Restablecer stock'), findsOneWidget);
    expect(store.productById('p-test')!.variants.first.stock, 9);

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Restablecer stock'), findsWidgets);
    expect(
      find.text(
        'La reserva de stock de este pedido se va a quitar y volverá a estar disponible.',
      ),
      findsOneWidget,
    );
    expect(find.text('Aceptar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(store.productById('p-test')!.variants.first.stock, 9);
    expect(order.stockReservations, isNotEmpty);
    expect(find.text('Guardar stock'), findsNothing);

    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();

    expect(store.productById('p-test')!.variants.first.stock, 10);
    expect(order.stockReservations, isEmpty);
    expect(order.stockNeedsSave, isTrue);
    expect(find.text('Guardar stock'), findsOneWidget);
    expect(
      find.text('La reserva se quitó. El stock volvió a estar disponible.'),
      findsOneWidget,
    );
  });
}
