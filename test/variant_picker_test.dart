import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/models/product.dart';
import 'package:store_app/theme/app_theme.dart';
import 'package:store_app/widgets/variant_picker.dart';

Product _garment() {
  final stamp = DateTime.utc(2026, 9, 11);
  return Product(
    id: 'p-multi',
    name: 'Remera',
    sku: 'RM-1',
    category: ApparelCategory.remeras,
    brand: 'Test',
    price: 10000,
    images: const [],
    variants: const [
      ProductVariant(size: 'L', color: 'Negro', colorHex: '#1E1E1E', stock: 4),
      ProductVariant(size: 'S', color: 'Negro', colorHex: '#1E1E1E', stock: 6),
      ProductVariant(size: 'M', color: 'Negro', colorHex: '#1E1E1E', stock: 3),
      ProductVariant(size: 'M', color: 'Rojo', colorHex: '#C62828', stock: 2),
    ],
    createdAt: stamp,
    updatedAt: stamp,
  );
}

Finder _sizeChip(String color, String size) {
  return find.byKey(ValueKey('variant-size-$color-$size'));
}

void main() {
  test('effective selection keeps only sizes that exist for the color', () {
    final product = _garment();
    final next = VariantSelection.effective(
      product,
      const VariantSelection(color: 'Rojo', sizes: {'L', 'M'}),
    );
    expect(next.color, 'Rojo');
    expect(next.sizes, {'M'});
    expect(product.sizesForColor('Rojo'), ['M']);
    expect(product.sizesForColor('Negro'), ['S', 'M', 'L']);
  });

  testWidgets('sizes sit under each color and several can be selected', (
    tester,
  ) async {
    final product = _garment();
    var selection = const VariantSelection();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return VariantPicker(
                product: product,
                selection: selection,
                onChanged: (next) => setState(() => selection = next),
              );
            },
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('variant-color-Negro'))).dy,
      lessThan(tester.getTopLeft(_sizeChip('Negro', 'S')).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('variant-color-Negro'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('variant-color-Rojo'))).dy,
      ),
    );
    expect(
      find.text(
        'Los talles se agrupan por color. Podés elegir varios del mismo.',
      ),
      findsOneWidget,
    );
    expect(_sizeChip('Negro', 'L'), findsOneWidget);
    expect(_sizeChip('Rojo', 'L'), findsNothing);
    expect(_sizeChip('Rojo', 'M'), findsOneWidget);
    expect(
      tester.getTopLeft(_sizeChip('Negro', 'S')).dx,
      lessThan(tester.getTopLeft(_sizeChip('Negro', 'M')).dx),
    );
    expect(
      tester.getTopLeft(_sizeChip('Negro', 'M')).dx,
      lessThan(tester.getTopLeft(_sizeChip('Negro', 'L')).dx),
    );

    await tester.tap(_sizeChip('Negro', 'L'));
    await tester.pump();
    await tester.tap(_sizeChip('Negro', 'S'));
    await tester.pump();

    expect(selection.color, 'Negro');
    expect(selection.sizes, {'S', 'L'});
    expect(
      [for (final variant in selection.addableVariants(product)) variant.size],
      ['S', 'L'],
    );
    expect(find.text('2 talles · stock mínimo: 4 u.'), findsOneWidget);
  });

  testWidgets('sheet can add several sizes of the same color', (tester) async {
    final product = _garment();
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final future = showVariantPickerSheet(host, product);
    await tester.pumpAndSettle();

    await tester.tap(_sizeChip('Negro', 'S'));
    await tester.pump();
    await tester.tap(_sizeChip('Negro', 'M'));
    await tester.pump();
    await tester.tap(find.text('Agregar 2 al pedido'));
    await tester.pumpAndSettle();

    final variants = await future;
    expect(variants, isNotNull);
    expect([for (final variant in variants!) variant.size], ['S', 'M']);
    expect(variants.every((variant) => variant.color == 'Negro'), isTrue);
  });

  testWidgets('a size of another color does not mark this color as out', (
    tester,
  ) async {
    final product = _garment();
    var selection = const VariantSelection();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return VariantPicker(
                product: product,
                selection: selection,
                onChanged: (next) => setState(() => selection = next),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('sin stock'), findsNothing);
    expect(find.textContaining('·  0'), findsNothing);

    await tester.tap(_sizeChip('Negro', 'L'));
    await tester.pump();

    expect(find.text('sin stock'), findsNothing);
    expect(find.text('2 u.'), findsOneWidget);

    await tester.tap(find.text('Rojo'));
    await tester.pump();

    expect(selection.color, 'Rojo');
    expect(_sizeChip('Rojo', 'L'), findsNothing);
    expect(_sizeChip('Negro', 'L'), findsOneWidget);
    expect(_sizeChip('Rojo', 'M'), findsOneWidget);
    expect(find.text('sin stock'), findsNothing);
    expect(find.text('2 u.'), findsOneWidget);
  });
}
