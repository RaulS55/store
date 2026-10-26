import 'dart:typed_data';

enum ImageSaveStatus { downloaded, gallery, cancelled, needsGesture, failed }

class ImageDownloadResult {
  const ImageDownloadResult._(
    this.status, {
    this.bytes,
    this.filename,
    this.mimeType,
  });

  const ImageDownloadResult.downloaded() : this._(ImageSaveStatus.downloaded);

  const ImageDownloadResult.gallery() : this._(ImageSaveStatus.gallery);

  const ImageDownloadResult.cancelled() : this._(ImageSaveStatus.cancelled);

  const ImageDownloadResult.failed() : this._(ImageSaveStatus.failed);

  const ImageDownloadResult.needsGesture({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) : this._(
         ImageSaveStatus.needsGesture,
         bytes: bytes,
         filename: filename,
         mimeType: mimeType,
       );

  final ImageSaveStatus status;
  final Uint8List? bytes;
  final String? filename;
  final String? mimeType;

  String? get message {
    return switch (status) {
      ImageSaveStatus.gallery => 'Imagen guardada en la galería.',
      ImageSaveStatus.downloaded => 'Imagen descargada.',
      ImageSaveStatus.cancelled || ImageSaveStatus.needsGesture => null,
      ImageSaveStatus.failed => 'No se pudo descargar la imagen.',
    };
  }
}

bool isMobileWebUserAgent(String userAgent, {int maxTouchPoints = 0}) {
  final ua = userAgent.toLowerCase();
  if (ua.contains('android') ||
      ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod')) {
    return true;
  }
  return ua.contains('macintosh') && maxTouchPoints > 1;
}
