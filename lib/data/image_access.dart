import 'dart:typed_data';

abstract class ImageAccess {
  Future<String> uploadProductImage({
    required String companyId,
    required String productId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  });

  Future<void> deleteProductImages({
    required String companyId,
    required String productId,
  });

  Future<String> uploadCompanyLogo({
    required String companyId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  });

  Future<void> deleteCompanyLogo({required String companyId});
}
