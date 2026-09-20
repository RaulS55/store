import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/session_store.dart';
import 'package:store_app/features/customers/customer_detail_page.dart';
import 'package:store_app/models/company_role.dart';
import 'package:store_app/routing/app_router.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_customer_access.dart';
import 'fakes/session_harness.dart';

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setFormView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _detailApp({required AppStore store, required SessionStore session}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider.value(value: session),
    ],
    child: const MaterialApp(
      home: Scaffold(body: CustomerDetailPage(customerId: 'c-test')),
    ),
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

void main() {
  testWidgets('owner can edit a customer from the detail page', (tester) async {
    _setFormView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await seedTestCustomer(store);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);

    await tester.pumpWidget(_detailApp(store: store, session: session));
    await tester.pump();

    expect(find.byKey(const ValueKey('edit-customer')), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-customer')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit-customer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Editar cliente'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('customer-name')),
      'Boutique Abril',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('save-customer')));
    await tester.tap(find.byKey(const ValueKey('save-customer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(store.customerById('c-test')!.name, 'Boutique Abril');
    expect(find.text('Boutique Abril'), findsOneWidget);
  });

  testWidgets('employee does not see delete on customer detail', (
    tester,
  ) async {
    _setPhoneView(tester);
    final store = AppStore();
    addTearDown(store.dispose);
    await seedTestCustomer(store);
    final session = await signedInMemberSession(role: CompanyRole.employee);
    addTearDown(session.dispose);

    await tester.pumpWidget(_detailApp(store: store, session: session));
    await tester.pump();

    expect(find.byKey(const ValueKey('edit-customer')), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-customer')), findsNothing);
  });

  testWidgets('owner confirm delete leaves the customers route', (
    tester,
  ) async {
    _setPhoneView(tester);
    final customers = FakeCustomerAccess();
    final store = AppStore(customers: customers);
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    store.bindCompany(session.companyId);
    await seedTestCustomer(store);

    final router = createRouter(session);
    await tester.pumpWidget(
      _routerApp(store: store, session: session, router: router),
    );
    await tester.pumpAndSettle();
    router.go('/clientes/c-test');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-customer')));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar cliente'), findsWidgets);
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(store.customerById('c-test'), isNull);
    expect(
      customers.customers[session.companyId]!['c-test']!.isDeleted,
      isTrue,
    );
    expect(router.routeInformationProvider.value.uri.path, '/clientes');
    expect(find.text('Cliente eliminado'), findsOneWidget);
  });
}
