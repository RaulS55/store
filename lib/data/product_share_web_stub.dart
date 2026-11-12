/// VM stand-in for the browser share call. Production web replaces this file.
Future<bool>? startWebShare(String text, String url) {
  throw UnsupportedError('Web share is only available in the browser.');
}
