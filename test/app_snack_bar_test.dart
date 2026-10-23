import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/theme/app_theme.dart';
import 'package:store_app/widgets/app_snack_bar.dart';

void main() {
  tearDown(AppSnackBar.hide);

  testWidgets('messages show at the top with white text', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  AppSnackBar.show(context, content: const Text('Listo'));
                },
                child: const Text('Avisar'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Avisar'));
    await tester.pump();

    final message = find.text('Listo');
    expect(message, findsOneWidget);
    expect(tester.getTopLeft(message).dy, lessThan(80));
    expect(
      tester.renderObject<RenderParagraph>(message).text.style?.color,
      Colors.white,
    );

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(message, findsNothing);
  });

  testWidgets('messages stay see-through and ignore taps', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var behindTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 80,
                child: GestureDetector(
                  onTap: () => behindTaps += 1,
                  behavior: HitTestBehavior.opaque,
                  child: const ColoredBox(
                    color: Colors.red,
                    child: Center(child: Text('Detras')),
                  ),
                ),
              ),
              Center(
                child: Builder(
                  builder: (context) {
                    return TextButton(
                      onPressed: () {
                        AppSnackBar.show(context, content: const Text('Listo'));
                      },
                      child: const Text('Avisar'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Avisar'));
    await tester.pump();

    final bar = tester.widget<Material>(
      find
          .ancestor(of: find.text('Listo'), matching: find.byType(Material))
          .first,
    );
    expect(bar.color?.a, closeTo(0.55, 0.01));

    await tester.tap(find.text('Detras'));
    await tester.pump();
    expect(behindTaps, 1);
  });
}
