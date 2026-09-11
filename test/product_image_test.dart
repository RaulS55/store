import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:store_app/widgets/product_image.dart';

Uint8List _jpeg() {
  final image = img.Image(width: 8, height: 8);
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      image.setPixelRgb(x, y, 200, 40, 40);
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

  testWidgets('bytes render with Image.memory', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProductImage(bytes: _jpeg())),
      ),
    );

    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.checkroom_outlined), findsNothing);
  });
}
