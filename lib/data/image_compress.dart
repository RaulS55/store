import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

const maxProductImages = 3;
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

Future<CompressedImage> compressProductImage(Uint8List original) async {
  if (original.isEmpty) {
    throw const ImageUploadException('El archivo de imagen está vacío.');
  }
  if (original.lengthInBytes > maxOriginalImageBytes) {
    throw const ImageUploadException('La imagen supera los 10 MB.');
  }

  ui.Image decoded;
  try {
    final codec = await ui.instantiateImageCodec(original);
    final frame = await codec.getNextFrame();
    decoded = frame.image;
    codec.dispose();
  } catch (_) {
    throw const ImageUploadException('El archivo no es una imagen válida.');
  }

  var image = decoded;
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > maxProductImageEdge) {
    final scale = maxProductImageEdge / longest;
    final width = (image.width * scale).round().clamp(1, maxProductImageEdge);
    final height = (image.height * scale).round().clamp(1, maxProductImageEdge);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final resized = await picture.toImage(width, height);
    picture.dispose();
    image.dispose();
    image = resized;
  }

  try {
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) {
      throw const ImageUploadException('El archivo no es una imagen válida.');
    }
    final raster = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    final encoded = img.encodeJpg(raster, quality: productImageJpegQuality);
    return CompressedImage(
      bytes: encoded,
      originalByteCount: original.lengthInBytes,
      compressedByteCount: encoded.lengthInBytes,
    );
  } finally {
    image.dispose();
  }
}

String imageUploadSizeLog({
  required int originalByteCount,
  required int compressedByteCount,
}) {
  return 'Image upload originalBytes=$originalByteCount '
      'compressedBytes=$compressedByteCount';
}
