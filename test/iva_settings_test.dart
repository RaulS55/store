import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/formatters.dart';
import 'package:store_app/features/settings/settings_page.dart';
import 'package:store_app/models/company.dart';
import 'package:store_app/models/product.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/session_harness.dart';

void main() {
  testWidgets('settings can enable VAT and edit the percentage', (
    tester,
  ) async {
    final store = AppStore();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    expect(store.ivaEnabled, isFalse);
    expect(find.text('Porcentaje de IVA'), findsNothing);

    await tester.tap(find.widgetWithText(SwitchListTile, 'IVA'));
    await tester.pumpAndSettle();

    expect(store.ivaEnabled, isTrue);
    expect(find.text('Porcentaje de IVA'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('iva-percent')), '10,5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(store.ivaPercent, 10.5);
    expect(find.text('10,5% sobre el subtotal del pedido'), findsOneWidget);
  });

  test('percent parser accepts comma and clamps in the store', () {
    expect(PercentFormat.tryParse('10,5'), 10.5);
    expect(PercentFormat.of(21), '21');
    expect(PercentFormat.of(10.5), '10,5');

    final store = AppStore();
    store.setIvaPercent(150);
    expect(store.ivaPercent, 100);
  });

  testWidgets('settings can select clothing, footwear or both', (tester) async {
    final store = AppStore();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    expect(store.rubro, CompanyRubro.ambos);
    expect(store.visibleCategories, contains(ApparelCategory.remeras));
    expect(store.visibleCategories, contains(ApparelCategory.zapatillas));

    await tester.tap(find.widgetWithText(FilterChip, 'Calzado'));
    await tester.pumpAndSettle();

    expect(store.rubro, CompanyRubro.ropa);
    expect(store.visibleCategories, contains(ApparelCategory.remeras));
    expect(
      store.visibleCategories,
      isNot(contains(ApparelCategory.zapatillas)),
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Ropa'));
    await tester.pumpAndSettle();

    expect(store.rubro, CompanyRubro.ropa);

    await tester.tap(find.widgetWithText(FilterChip, 'Calzado'));
    await tester.pumpAndSettle();

    expect(store.rubro, CompanyRubro.ambos);

    await tester.tap(find.widgetWithText(FilterChip, 'Ropa'));
    await tester.pumpAndSettle();

    expect(store.rubro, CompanyRubro.calzado);
    expect(store.visibleCategories, contains(ApparelCategory.pantuflas));
    expect(store.visibleCategories, isNot(contains(ApparelCategory.remeras)));
  });

  testWidgets('settings can save a company phone number', (tester) async {
    final store = AppStore();
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: session),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    expect(find.text('Número de teléfono'), findsOneWidget);
    expect(session.company?.phone, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('company-phone')),
      ' +54 9 11 5555-0101 ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(session.company?.phone, '+54 9 11 5555-0101');

    await tester.enterText(find.byKey(const ValueKey('company-phone')), '  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(session.company?.phone, isNull);
  });

  test('store hides clothing products when the line is footwear', () async {
    final store = AppStore();
    await store.upsertProduct(testProduct());
    expect(store.filteredProducts, isNotEmpty);

    store.setRubro(CompanyRubro.calzado);
    expect(store.filteredProducts, isEmpty);
    expect(store.visibleCategories.first.line, ApparelLine.calzado);
  });
}
