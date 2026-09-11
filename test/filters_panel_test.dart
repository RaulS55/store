import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/features/stock/filters_panel.dart';
import 'package:store_app/models/product.dart';
import 'package:store_app/theme/app_theme.dart';

Product _sizedProduct() {
  final stamp = DateTime.utc(2026, 9, 11);
  return Product(
    id: 'p-sizes',
    name: 'Prenda',
    sku: 'SZ-1',
    category: ApparelCategory.remeras,
    brand: 'Test',
    price: 1000,
    images: const [],
    variants: [
      for (final size in const ['S', 'M', 'L', 'XL'])
        ProductVariant(
          size: size,
          color: 'Negro',
          colorHex: '#1E1E1E',
          stock: 4,
        ),
    ],
    createdAt: stamp,
    updatedAt: stamp,
  );
}

Widget _app(AppStore store) {
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: FiltersEditor()),
    ),
  );
}

Finder _sizeChip(String size) => find.widgetWithText(FilterChip, size);

void main() {
  testWidgets('filter sizes stay in place and skip the checkmark', (
    tester,
  ) async {
    final store = AppStore();
    await store.upsertProduct(_sizedProduct());
    await tester.pumpWidget(_app(store));

    final sizes = ['S', 'M', 'L', 'XL'];
    final before = {
      for (final size in sizes) size: tester.getTopLeft(_sizeChip(size)),
    };

    await tester.tap(_sizeChip('XL'));
    await tester.pump();

    final chip = tester.widget<FilterChip>(_sizeChip('XL'));
    expect(chip.selected, isTrue);
    expect(chip.showCheckmark, isFalse);
    for (final size in sizes) {
      expect(tester.getTopLeft(_sizeChip(size)), before[size]);
    }
  });

  testWidgets('web filter bar keeps letter sizes and Poco stock without checkmark', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: AppStore(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: WebFilterBar()),
        ),
      ),
    );

    expect(find.text('S'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('L'), findsOneWidget);
    expect(find.text('38'), findsNothing);
    expect(find.text('40'), findsNothing);
    expect(find.text('42'), findsNothing);
    expect(find.text('Poco stock'), findsOneWidget);
    expect(find.text('Solo bajo stock'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Poco stock'));
    await tester.pump();

    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Poco stock'),
    );
    expect(chip.selected, isTrue);
    expect(chip.showCheckmark, isFalse);
  });
}
