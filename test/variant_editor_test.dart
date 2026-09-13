import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/features/product/variant_editor.dart';
import 'package:store_app/models/product.dart';
import 'package:store_app/theme/app_theme.dart';

Widget _app(VariantDraft draft) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) {
          return VariantEditor(
            draft: draft,
            wide: true,
            onChanged: () => setState(() {}),
          );
        },
      ),
    ),
  );
}

List<String> _sizeChipOrder(WidgetTester tester) {
  return tester
      .widgetList<FilterChip>(find.byType(FilterChip))
      .map((chip) => (chip.label as Text).data!)
      .where(ApparelSizes.all.contains)
      .toList();
}

List<String> _colorOrder(WidgetTester tester) {
  return tester
      .widgetList<Tooltip>(find.byType(Tooltip))
      .map((tooltip) => tooltip.message)
      .whereType<String>()
      .where(
        (message) =>
            message.startsWith('Agregar ') || message.startsWith('Quitar '),
      )
      .map((message) => message.replaceFirst(RegExp(r'^(Agregar|Quitar) '), ''))
      .toList();
}

void main() {
  test('custom sizes keep the typed name', () {
    final draft = VariantDraft();
    draft.addSize('44');
    draft.addColor(Swatches.negro);
    expect(ApparelSizes.isCustom('44'), isTrue);
    expect(draft.sizes.single, '44');
    expect(draft.variants.single.size, '44');
  });

  test('custom colors skip the swatch hex', () {
    final draft = VariantDraft();
    draft.addSize('M');
    draft.addColor(Swatches.resolve('Lila'));
    expect(draft.colors.single.isCustom, isTrue);
    expect(draft.variants.single.color, 'Lila');
    expect(draft.variants.single.colorHex, isNull);
  });

  testWidgets('selecting a size keeps the chip order and skips the checkmark', (
    tester,
  ) async {
    await tester.pumpWidget(_app(VariantDraft()));

    final before = _sizeChipOrder(tester);
    expect(before, ApparelSizes.all);

    await tester.tap(find.widgetWithText(FilterChip, 'XL'));
    await tester.pump();

    expect(_sizeChipOrder(tester), before);
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'XL'),
    );
    expect(chip.selected, isTrue);
    expect(chip.showCheckmark, isFalse);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('selecting a color keeps the swatch order', (tester) async {
    await tester.pumpWidget(_app(VariantDraft()));

    final before = _colorOrder(tester);
    expect(before, [for (final color in Swatches.all) color.name]);

    await tester.tap(find.byTooltip('Agregar Azul'));
    await tester.pump();

    expect(_colorOrder(tester), before);
    expect(find.byTooltip('Quitar Azul'), findsOneWidget);
  });

  testWidgets('custom color shows as a name chip without a swatch', (
    tester,
  ) async {
    await tester.pumpWidget(_app(VariantDraft()));

    expect(find.text('Óxido'), findsNothing);
    expect(find.byTooltip('Agregar Marrón'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Color'));
    await tester.pumpAndSettle();

    expect(find.text('Agregar color'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Lila');
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();

    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Lila'),
    );
    expect(chip.selected, isTrue);
    expect(chip.showCheckmark, isFalse);
    expect(find.byTooltip('Agregar Lila'), findsNothing);
    expect(find.byTooltip('Quitar Lila'), findsNothing);
    expect(_colorOrder(tester), [for (final color in Swatches.all) color.name]);
  });

  testWidgets('custom size shows as a name chip without a size icon', (
    tester,
  ) async {
    await tester.pumpWidget(_app(VariantDraft()));

    expect(find.widgetWithText(FilterChip, 'XXL'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Talle'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Talle'));
    await tester.pumpAndSettle();

    expect(find.text('Agregar talle'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '44');
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();

    final chip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, '44'));
    expect(chip.selected, isTrue);
    expect(chip.showCheckmark, isFalse);
    expect(chip.avatar, isNull);
    expect(_sizeChipOrder(tester), ApparelSizes.all);
  });

  testWidgets('add size dialog keeps Cancelar beside Agregar', (tester) async {
    await tester.pumpWidget(_app(VariantDraft()));
    await tester.tap(find.widgetWithText(ActionChip, 'Talle'));
    await tester.pumpAndSettle();

    expect(find.text('Agregar talle'), findsOneWidget);
    final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancelar'));
    final add = tester.getRect(find.widgetWithText(FilledButton, 'Agregar'));
    expect(cancel.center.dy, closeTo(add.center.dy, 2));
    expect(cancel.right, lessThan(add.left));
  });
}
