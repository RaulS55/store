import 'dart:typed_data';

import 'package:image/image.dart' as img;

const maxProductImages = 10;
const maxOriginalImageBytes = 10 * 1024 * 1024;
const maxProductImageEdge = 1600;
const productImageJpegQuality = 75;

class CompressedImage {
  const CompressedImage({
    required this.bytes,
    required this.originalByteCount,
    required this.compressedByteCount,
  });

  final Uint8List bytes;
  final int originalByteCount;
  final int compressedByteCount;
}

class ImageUploadException implements Exception {
  const ImageUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

CompressedImage compressProductImage(Uint8List original) {
  if (original.isEmpty) {
    throw const ImageUploadException('El archivo de imagen está vacío.');
  }
  if (original.lengthInBytes > maxOriginalImageBytes) {
    throw const ImageUploadException('La imagen supera los 10 MB.');
  }
  img.Image? decoded;
  try {
    decoded = img.decodeImage(original);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) {
    throw const ImageUploadException('El archivo no es una imagen válida.');
  }
  var frame = decoded;
  if (frame.width >= frame.height) {
    if (frame.width > maxProductImageEdge) {
      frame = img.copyResize(frame, width: maxProductImageEdge);
    }
  } else if (frame.height > maxProductImageEdge) {
    frame = img.copyResize(frame, height: maxProductImageEdge);
  }
  final encoded = img.encodeJpg(frame, quality: productImageJpegQuality);
  return CompressedImage(
    bytes: encoded,
    originalByteCount: original.lengthInBytes,
    compressedByteCount: encoded.lengthInBytes,
  );
}

String imageUploadSizeLog({
  required int originalByteCount,
  required int compressedByteCount,
}) {
  return 'Image upload originalBytes=$originalByteCount '
      'compressedBytes=$compressedByteCount';
}
