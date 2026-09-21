import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:store_app/data/local/hive_bootstrap.dart';

void main() {
  late String existingKey;

  setUp(() {
    existingKey = base64UrlEncode(Hive.generateSecureKey());
  });

  test('composite key store reuses the first readable key', () async {
    final web = MemoryHiveKeyStore(existingKey);
    final secure = MemoryHiveKeyStore()..readError = Exception('secure down');

    final store = CompositeHiveKeyStore([web, secure]);
    expect(await store.read(), existingKey);
    expect(secure.value, existingKey);
  });

  test('loadHiveCipher does not rotate a key when one store throws', () async {
    final web = MemoryHiveKeyStore(existingKey);
    final secure = MemoryHiveKeyStore()..readError = Exception('secure down');

    await loadHiveCipher(keys: CompositeHiveKeyStore([web, secure]));

    expect(web.value, existingKey);
  });
}
