import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'picked_image_file.dart';

Future<List<PickedImageFile>> pickGalleryImages({required int limit}) {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp,image/*'
    ..multiple = true;
  final completer = Completer<List<PickedImageFile>>();

  void finish(List<PickedImageFile> files) {
    if (!completer.isCompleted) completer.complete(files);
    input.remove();
  }

  input.onchange = (web.Event _) {
    final list = input.files;
    if (list == null || list.length == 0) {
      finish(const []);
      return;
    }
    final n = list.length < limit ? list.length : limit;
    () async {
      try {
        final picked = <PickedImageFile>[];
        for (var i = 0; i < n; i++) {
          final file = list.item(i);
          if (file == null) continue;
          final buffer = await file.arrayBuffer().toDart;
          picked.add(
            PickedImageFile(
              name: file.name,
              bytes: Uint8List.view(buffer.toDart),
            ),
          );
        }
        finish(picked);
      } catch (error, stack) {
        if (!completer.isCompleted) {
          completer.completeError(error, stack);
        }
        input.remove();
      }
    }();
  }.toJS;

  input.oncancel = (web.Event _) {
    finish(const []);
  }.toJS;

  input.onerror = (web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(
        StateError('No se pudo abrir el selector de fotos.'),
      );
    }
    input.remove();
  }.toJS;

  input.style.display = 'none';
  web.document.body?.append(input);
  input.click();
  return completer.future;
}
