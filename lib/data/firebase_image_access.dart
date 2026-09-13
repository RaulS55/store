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

  @override
  Future<void> deleteProductImages({
    required String companyId,
    required String productId,
  }) async {
    final ref = _storage
        .ref()
        .child('companies')
        .child(companyId)
        .child('products')
        .child(productId);
    try {
      debugPrint('Storage delete start path=${ref.fullPath}');
      final result = await ref.listAll().timeout(const Duration(seconds: 20));
      await Future.wait([
        for (final item in result.items)
          item.delete().timeout(const Duration(seconds: 20)),
      ]);
      debugPrint(
        'Storage delete done path=${ref.fullPath} count=${result.items.length}',
      );
    } on ImageUploadException {
      rethrow;
    } on TimeoutException {
      throw const ImageUploadException('El borrado de fotos tardó demasiado.');
    } on FirebaseException catch (error) {
      debugPrint('Storage delete failed code=${error.code} ${error.message}');
      throw ImageUploadException(_storageMessage(error, deleting: true));
    }
  }

  String _storageMessage(FirebaseException error, {bool deleting = false}) {
    final code = error.code.replaceFirst('storage/', '');
    switch (code) {
      case 'unauthorized':
      case 'permission-denied':
        return deleting
            ? 'No tenés permiso para borrar fotos.'
            : 'No tenés permiso para subir fotos.';
      case 'canceled':
        return deleting ? 'El borrado se canceló.' : 'La subida se canceló.';
      default:
        return error.message ??
            (deleting
                ? 'No se pudieron borrar las fotos.'
                : 'No se pudo subir la foto.');
    }
  }
}
