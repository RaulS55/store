import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/firebase_bootstrap.dart';
import 'package:store_app/firebase_options.dart';

void main() {
  test('uses the custom host as auth domain on app.modastore.org', () {
    final options = firebaseOptionsForHost(
      uri: Uri.parse('https://app.modastore.org/equipo'),
      isWeb: true,
    );
    expect(options.authDomain, 'app.modastore.org');
  });

  test('keeps the Firebase auth domain on the default hosting host', () {
    final options = firebaseOptionsForHost(
      uri: Uri.parse('https://stockapp-9c34c.web.app/'),
      isWeb: true,
    );
    expect(options.authDomain, DefaultFirebaseOptions.web.authDomain);
  });
}
