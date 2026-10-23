import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/features/customers/customers_page.dart';

import 'fakes/catalog_harness.dart';

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _pageApp(AppStore store) {
  return ChangeNotifierProvider.value(
    value: store,
    child: const MaterialApp(home: Scaffold(body: CustomersPage())),
  );
}

void main() {
  testWidgets('customers page search filters by name', (tester) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await seedTestCustomer(store);
    await seedTestCustomer(
      store,
      customer: testCustomer(id: 'c-ana', name: 'Ana López'),
    );

    await tester.pumpWidget(_pageApp(store));
    await tester.pump();

    expect(find.text('Mónica Fernández'), findsOneWidget);
    expect(find.text('Ana López'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('customers-search')),
      'Ana',
    );
    await tester.pump();

    expect(find.text('Ana López'), findsOneWidget);
    expect(find.text('Mónica Fernández'), findsNothing);
  });

  testWidgets('customers page search can clear and restore the list', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await seedTestCustomer(store);
    await seedTestCustomer(
      store,
      customer: testCustomer(id: 'c-ana', name: 'Ana López'),
    );

    await tester.pumpWidget(_pageApp(store));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('customers-search')),
      'sin-resultados',
    );
    await tester.pump();

    expect(find.text('No encontramos clientes'), findsOneWidget);
    expect(find.text('Mónica Fernández'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('search-clear')));
    await tester.pump();

    expect(find.text('Mónica Fernández'), findsOneWidget);
    expect(find.text('Ana López'), findsOneWidget);
    expect(find.text('No encontramos clientes'), findsNothing);
  });
}
