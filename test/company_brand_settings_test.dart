import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:store_app/data/app_store.dart';
import 'package:store_app/data/picked_image_file.dart';
import 'package:store_app/features/settings/settings_page.dart';
import 'package:store_app/models/company_role.dart';

import 'fakes/fake_image_access.dart';
import 'fakes/fake_product_access.dart';
import 'fakes/session_harness.dart';

Uint8List _png({int width = 80, int height = 80}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, 196, 92, 62);
    }
  }
  return img.encodePng(image);
}

void main() {
  testWidgets('owner can edit the company name, logo and socials', (
    tester,
  ) async {
    final images = FakeImageAccess();
    final store = AppStore(products: FakeProductAccess(), images: images);
    addTearDown(store.dispose);
    final session = await signedInOwnerSession();
    addTearDown(session.dispose);
    store.bindCompany(session.companyId);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: session),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              pickLogo: ({required int limit}) async => [
                PickedImageFile(name: 'logo.png', bytes: _png()),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tu negocio'), findsOneWidget);
    expect(find.byKey(const ValueKey('company-name')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('company-name')),
      ' Taller Ana ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-company-name')));
    await tester.pump();
    expect(session.company?.name, 'Taller Ana');
    expect(find.text('Guardado exitosamente'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pick-company-logo')));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
    expect(session.company?.logoUrl, isNotNull);
    expect(images.uploads, hasLength(1));
    expect(images.uploads.single.productId, isEmpty);
    expect(images.uploads.single.fileName, startsWith('logo-'));

    await tester.ensureVisible(find.byKey(const ValueKey('company-instagram')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('company-instagram')),
      '@taller.ana',
    );
    await tester.enterText(
      find.byKey(const ValueKey('company-tiktok')),
      'taller.ana',
    );
    await tester.enterText(
      find.byKey(const ValueKey('company-facebook')),
      'tallerana',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-company-socials')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-company-socials')));
    await tester.pump();

    expect(session.company?.instagram, '@taller.ana');
    expect(session.company?.tiktok, 'taller.ana');
    expect(session.company?.facebook, 'tallerana');
  });

  testWidgets('employees do not see the company profile section', (
    tester,
  ) async {
    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInMemberSession(role: CompanyRole.employee);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: session),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    expect(find.text('Tu negocio'), findsNothing);
    expect(find.byKey(const ValueKey('company-name')), findsNothing);
    expect(find.text('WhatsApp'), findsOneWidget);
  });

  testWidgets('administrators do not see the company profile section', (
    tester,
  ) async {
    final store = AppStore();
    addTearDown(store.dispose);
    final session = await signedInMemberSession(
      role: CompanyRole.administrator,
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: session),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );

    expect(session.canEditCompanySettings, isTrue);
    expect(find.text('Tu negocio'), findsNothing);
    expect(find.byKey(const ValueKey('company-instagram')), findsNothing);
  });
}
