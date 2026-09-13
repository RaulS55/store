import 'dart:typed_data';

import 'package:store_app/data/image_access.dart';

class FakeUploadedImage {
  const FakeUploadedImage({
    required this.companyId,
    required this.productId,
    required this.fileName,
    required this.bytes,
    required this.contentType,
  });

  final String companyId;
  final String productId;
  final String fileName;
  final Uint8List bytes;
  final String contentType;

  String get url =>
      'https://example.com/companies/$companyId/products/$productId/$fileName';
}

class FakeImageAccess implements ImageAccess {
  final uploads = <FakeUploadedImage>[];

  @override
  Future<String> uploadProductImage({
    required String companyId,
    required String productId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final upload = FakeUploadedImage(
      companyId: companyId,
      productId: productId,
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      contentType: contentType,
    );
    uploads.add(upload);
    return upload.url;
  }

  @override
  Future<void> deleteProductImages({
    required String companyId,
    required String productId,
  }) async {
    uploads.removeWhere(
      (upload) =>
          upload.companyId == companyId && upload.productId == productId,
    );
  }
}
