import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/widgets/product_image_viewer.dart';

void main() {
  testWidgets('empty images do not open the viewer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showProductImageViewer(
                context: context,
                images: const [ProductImageEntry()],
              ),
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('product-image-viewer')), findsNothing);
  });

  testWidgets('viewer shows the requested image and can close', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showProductImageViewer(
                context: context,
                images: productImageEntries(const ['one', 'two']),
                initialIndex: 1,
              ),
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('product-image-viewer')), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-image-viewer-image-1-two')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('product-image-viewer-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('product-image-viewer')), findsNothing);
  });
}
