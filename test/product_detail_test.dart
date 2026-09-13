import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/features/product/product_detail_page.dart';
import 'package:store_app/widgets/product_image.dart';

import 'fakes/catalog_harness.dart';

const _images = [
  'gallery-one',
  'gallery-two',
  'gallery-three',
];

void _setPhoneView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<AppStore> _storeWithGallery() async {
  final store = AppStore();
  await store.upsertProduct(testProduct().copyWith(images: _images));
  return store;
}

Widget _app(AppStore store) {
  return ChangeNotifierProvider.value(
    value: store,
    child: const MaterialApp(
      home: Scaffold(body: ProductDetailPage(id: 'p-test')),
    ),
  );
}

PageController _pagerController(WidgetTester tester) {
  return tester.widget<PageView>(find.byType(PageView)).controller!;
}

void main() {
  testWidgets('swipe shows the next product image', (tester) async {
    _setPhoneView(tester);
    await tester.pumpWidget(_app(await _storeWithGallery()));
    await tester.pump();

    expect(_pagerController(tester).page, 0);
    expect(
      find.byKey(ValueKey('product-pager-image-0-${_images[0]}')),
      findsOneWidget,
    );

    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await tester.pumpAndSettle();

    expect(_pagerController(tester).page, 1);
    expect(
      find.byKey(ValueKey('product-pager-image-1-${_images[1]}')),
      findsOneWidget,
    );
    final visible = tester.widget<ProductImage>(
      find.byKey(ValueKey('product-pager-image-1-${_images[1]}')),
    );
    expect(visible.path, _images[1]);
  });

  testWidgets('mouse drag shows the next product image', (tester) async {
    _setPhoneView(tester);
    await tester.pumpWidget(_app(await _storeWithGallery()));
    await tester.pump();

    await tester.drag(
      find.byType(PageView),
      const Offset(-320, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(_pagerController(tester).page, 1);
  });

  testWidgets('tap on a thumbnail shows that image', (tester) async {
    _setPhoneView(tester);
    await tester.pumpWidget(_app(await _storeWithGallery()));
    await tester.pump();

    final thumb = find.byKey(const ValueKey('product-gallery-thumb-2'));
    await tester.ensureVisible(thumb);
    await tester.tap(thumb);
    await tester.pumpAndSettle();

    expect(_pagerController(tester).page, 2);
    final visible = tester.widget<ProductImage>(
      find.byKey(ValueKey('product-pager-image-2-${_images[2]}')),
    );
    expect(visible.path, _images[2]);
  });
}
