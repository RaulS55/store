import 'package:image_picker/image_picker.dart';

import 'picked_image_file.dart';

Future<List<PickedImageFile>> pickGalleryImages({required int limit}) async {
  final files = await ImagePicker().pickMultiImage(requestFullMetadata: false);
  final picked = <PickedImageFile>[];
  for (final file in files.take(limit)) {
    picked.add(
      PickedImageFile(name: file.name, bytes: await file.readAsBytes()),
    );
  }
  return picked;
}
