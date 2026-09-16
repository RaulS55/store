import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:store_app/widgets/product_image.dart';

Uint8List _jpeg({int green = 40}) {
  final image = img.Image(width: 8, height: 8);
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      image.setPixelRgb(x, y, 200, green, 40);
    }
  }
  return img.encodeJpg(image);
}

void main() {
  testWidgets('empty path shows the default product icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProductImage())),
    );

    expect(find.byIcon(Icons.checkroom_outlined), findsOneWidget);
  });

  testWidgets('a bounded box decodes only one cache side', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 80,
            child: ProductImage(bytes: _jpeg()),
          ),
        ),
      ),
    );

    final provider = tester.widget<Image>(find.byType(Image)).image;
    expect(provider, isA<ResizeImage>());
    final resize = provider as ResizeImage;
    expect(resize.width == null || resize.height == null, isTrue);
    expect(resize.width != null || resize.height != null, isTrue);
  });

  testWidgets('bytes render with Image.memory', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductImage(bytes: _jpeg())),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.checkroom_outlined), findsNothing);
  });

  testWidgets('a new path replaces the previous image widget', (tester) async {
    final first = _jpeg();
    final second = _jpeg(green: 180);

    Widget image(String path, Uint8List bytes) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            height: 80,
            child: ProductImage(path: path, bytes: bytes),
          ),
        ),
      );
    }

    await tester.pumpWidget(image('first', first));
    expect(
      find.byKey(ValueKey('memory:first:${first.length}')),
      findsOneWidget,
    );

    await tester.pumpWidget(image('second', second));
    expect(find.byKey(ValueKey('memory:first:${first.length}')), findsNothing);
    expect(
      find.byKey(ValueKey('memory:second:${second.length}')),
      findsOneWidget,
    );
  });
}
