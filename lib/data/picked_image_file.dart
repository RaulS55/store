import 'dart:typed_data';

class PickedImageFile {
  const PickedImageFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}
