import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'image_access.dart';

class FirebaseImageAccess implements ImageAccess {
  FirebaseImageAccess({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> uploadProductImage({
    required String companyId,
    required String productId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ref = _storage
        .ref()
        .child('companies')
        .child(companyId)
        .child('products')
        .child(productId)
        .child(fileName);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
