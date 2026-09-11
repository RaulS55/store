import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'image_access.dart';
import 'image_compress.dart';

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
    try {
      debugPrint(
        'Storage upload start path=${ref.fullPath} bytes=${bytes.lengthInBytes}',
      );
      await ref
          .putData(bytes, SettableMetadata(contentType: contentType))
          .timeout(const Duration(seconds: 45));
      final url = await ref.getDownloadURL().timeout(
        const Duration(seconds: 20),
      );
      debugPrint('Storage upload done path=${ref.fullPath}');
      return url;
    } on ImageUploadException {
      rethrow;
    } on TimeoutException {
      throw const ImageUploadException('La subida tardó demasiado.');
    } on FirebaseException catch (error) {
      debugPrint('Storage upload failed code=${error.code} ${error.message}');
      throw ImageUploadException(_storageMessage(error));
    }
  }

  String _storageMessage(FirebaseException error) {
    final code = error.code.replaceFirst('storage/', '');
    switch (code) {
      case 'unauthorized':
      case 'permission-denied':
        return 'No tenés permiso para subir fotos.';
      case 'canceled':
        return 'La subida se canceló.';
      default:
        return error.message ?? 'No se pudo subir la foto.';
    }
  }
}
