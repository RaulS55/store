import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/features/stock/filters_panel.dart';
import 'package:store_app/models/product.dart';
import 'package:store_app/theme/app_theme.dart';

import 'fakes/catalog_harness.dart';

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
      home: Scaffold(body: FiltersEditor(host: store)),
    ),
  );
}

Finder _sizeChip(String size) => find.widgetWithText(FilterChip, size);

void main() {
  testWidgets('filter sizes stay in place and skip the checkmark', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    expect(find.widgetWithText(FilterChip, 'Remeras'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Musculosas'), findsNothing);
    expect(find.text('Público'), findsNothing);
  });

  testWidgets('filter sheet lists used audiences', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore();
    await store.upsertProduct(
      testProduct(id: 'p-m', audience: ApparelAudience.mujer),
    );
    await store.upsertProduct(
      testProduct(
        id: 'p-h',
        sku: 'TST-0002',
        audience: ApparelAudience.hombre,
      ),
    );
    await tester.pumpWidget(_app(store));

    expect(find.text('Público'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Mujer'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Hombre'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Bebé'), findsNothing);
  });

  testWidgets('filter sheet hides public when only one audience exists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore();
    await store.upsertProduct(
      testProduct(audience: ApparelAudience.mujer),
    );
    await tester.pumpWidget(_app(store));

    expect(find.text('Público'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Mujer'), findsNothing);
  });

  testWidgets(
    'web filter bar keeps letter sizes and Poco stock without checkmark',
    (tester) async {
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
      expect(find.byKey(const ValueKey('audience-chip-all')), findsNothing);
      expect(find.byKey(const ValueKey('audience-chip-mujer')), findsNothing);
      expect(find.text('Público'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Poco stock'));
      await tester.pump();

      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Poco stock'),
      );
      expect(chip.selected, isTrue);
      expect(chip.showCheckmark, isFalse);
    },
  );

  testWidgets('web filter bar audience chips select the public', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = AppStore();
    await store.upsertProduct(
      testProduct(id: 'p-m', audience: ApparelAudience.mujer),
    );
    await store.upsertProduct(
      testProduct(
        id: 'p-h',
        sku: 'TST-0002',
        audience: ApparelAudience.hombre,
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: WebFilterBar()),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('audience-chip-mujer')));
    await tester.pump();
    expect(store.chipAudience, ApparelAudience.mujer);

    await tester.tap(find.byKey(const ValueKey('audience-chip-all')));
    await tester.pump();
    expect(store.chipAudience, isNull);
    expect(find.byKey(const ValueKey('audience-chip-bebe')), findsNothing);
  });
}
