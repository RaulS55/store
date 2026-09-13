import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/picked_image_file.dart';
import 'package:store_app/features/product/product_form_page.dart';

import 'fakes/catalog_harness.dart';
import 'fakes/fake_image_access.dart';
import 'fakes/fake_product_access.dart';

Finder _fieldWithHint(String hint) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );
}

Widget _formApp(
  AppStore store, {
  String? productId,
  Future<List<PickedImageFile>> Function({required int limit})? pickImages,
}) {
  final form = pickImages == null
      ? ProductFormPage(id: productId)
      : ProductFormPage(id: productId, pickImages: pickImages);
  return ChangeNotifierProvider.value(
    value: store,
    child: MaterialApp(home: Scaffold(body: form)),
  );
}

void _setTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('isSkuInUse detects another product with the same SKU', () async {
    final store = AppStore();
    await store.upsertProduct(testProduct(id: 'p1', sku: 'CJL-0255'));

    expect(store.isSkuInUse('CJL-0255'), isTrue);
    expect(store.isSkuInUse('cjl-0255'), isTrue);
    expect(store.isSkuInUse('CJL-0255', excludingProductId: 'p1'), isFalse);
    expect(store.isSkuInUse('OTRO-1'), isFalse);
  });

  testWidgets('price field keeps digits only', (tester) async {
    _setTallView(tester);
    await tester.pumpWidget(_formApp(AppStore()));

    final price = _fieldWithHint('Ej. 12500');
    final field = tester.widget<TextField>(price);
    expect(field.inputFormatters, contains(isA<FilteringTextInputFormatter>()));

    await tester.enterText(price, '12a3b');
    await tester.pump();
    expect(field.controller!.text, '123');
  });

  testWidgets('SKU field indicates when the value is already in use', (
    tester,
  ) async {
    _setTallView(tester);
    final store = AppStore();
    await store.upsertProduct(testProduct(sku: 'CJL-0255'));
    await tester.pumpWidget(_formApp(store));

    await tester.enterText(_fieldWithHint('Ej. CJL-0255'), 'CJL-0255');
    await tester.pump();

    expect(find.text('Este SKU ya está en uso'), findsOneWidget);
  });

  testWidgets('editing a product does not flag its own SKU as in use', (
    tester,
  ) async {
    _setTallView(tester);
    final store = AppStore();
    await store.upsertProduct(testProduct(id: 'p-own', sku: 'CJL-0255'));
    await tester.pumpWidget(_formApp(store, productId: 'p-own'));

    await tester.enterText(_fieldWithHint('Ej. CJL-0255'), 'CJL-0255');
    await tester.pump();

    expect(find.text('Este SKU ya está en uso'), findsNothing);
  });

  testWidgets('custom size chip label has no plus in the text', (tester) async {
    _setTallView(tester);
    await tester.pumpWidget(_formApp(AppStore()));

    expect(find.text('+ Talle'), findsNothing);
    expect(find.text('Talle'), findsOneWidget);
    expect(find.text('+ Color'), findsNothing);
    expect(find.text('Color'), findsOneWidget);
  });

  testWidgets('form header paints an opaque background', (tester) async {
    _setTallView(tester);
    await tester.pumpWidget(_formApp(AppStore()));

    final material = tester.widget<Material>(
      find
          .ancestor(
            of: find.text('Nueva prenda'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, isNotNull);
    expect(material.color!.alpha, 255);
  });

  testWidgets(
    'add photo tile scrolls with the form and clips under the header',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_formApp(AppStore()));

      final header = find.text('Nueva prenda');
      final addPhoto = find.text('Agregar foto (máx. 3)');
      final startTop = tester.getTopLeft(addPhoto).dy;
      expect(startTop, greaterThanOrEqualTo(tester.getRect(header).bottom));

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(addPhoto).dy, lessThan(startTop));
      expect(addPhoto.hitTestable(), findsNothing);
    },
  );

  testWidgets(
    'picking a photo compresses it at once and does not upload yet',
    (tester) async {
      _setTallView(tester);
      final original = _png();
      final images = FakeImageAccess();
      final logs = <String>[];
      final store = AppStore(
        products: FakeProductAccess(),
        images: images,
        log: logs.add,
      );
      addTearDown(store.dispose);
      store.bindCompany('co1');

      await tester.pumpWidget(
        _formApp(
          store,
          pickImages: ({required int limit}) async {
            return [PickedImageFile(name: 'foto.png', bytes: original)];
          },
        ),
      );

      await tester.tap(find.text('Agregar'));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pump();

      expect(images.uploads, isEmpty);
      expect(logs.where((line) => line.startsWith('Image compress start')), [
        'Image compress start originalBytes=${original.lengthInBytes}',
      ]);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}

Uint8List _png({int width = 240, int height = 240}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, (x * 13) & 255, (y * 17) & 255, (x + y) & 255);
    }
  }
  return img.encodePng(image);
}
