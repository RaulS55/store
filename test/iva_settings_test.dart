import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/formatters.dart';
import 'package:store_app/features/settings/settings_page.dart';

void main() {
  testWidgets('settings can enable VAT and edit the percentage', (tester) async {
    final store = AppStore();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const MaterialApp(
          home: Scaffold(body: SettingsPage()),
        ),
      ),
    );

    expect(store.ivaEnabled, isFalse);
    expect(find.text('Porcentaje de IVA'), findsNothing);

    await tester.tap(find.widgetWithText(SwitchListTile, 'IVA'));
    await tester.pumpAndSettle();

    expect(store.ivaEnabled, isTrue);
    expect(find.text('Porcentaje de IVA'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '10,5');
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
}
