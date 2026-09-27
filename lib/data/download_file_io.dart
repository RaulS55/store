import 'dart:io';
import 'dart:typed_data';

import 'package:url_launcher/url_launcher.dart';

Future<bool> downloadBytes({
  required Uint8List bytes,
  required String filename,
  String mimeType = 'application/octet-stream',
}) async {
  if (bytes.isEmpty || filename.isEmpty) return false;
  try {
    final dir = _downloadDirectory();
    if (dir == null) return false;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final safe = filename.replaceAll(RegExp(r'[/\\]'), '_');
    final file = File('${dir.path}${Platform.pathSeparator}$safe');
    await file.writeAsBytes(bytes, flush: true);
    return true;
  } catch (_) {
    return false;
  }
}

Future<bool> downloadFromUrl({
  required String url,
  required String filename,
}) async {
  if (url.isEmpty) return false;
  try {
    return await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

Directory? _downloadDirectory() {
  if (Platform.isMacOS || Platform.isLinux) {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return null;
    return Directory('$home/Downloads');
  }
  if (Platform.isWindows) {
    final home = Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) return null;
    return Directory('$home${Platform.pathSeparator}Downloads');
  }
  return Directory.systemTemp;
}
