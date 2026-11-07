import 'dart:math';

const shareCodeAlphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
const shareCodeLength = 5;

bool isShareCode(String code) {
  if (code.length != shareCodeLength) return false;
  for (final unit in code.codeUnits) {
    if (!shareCodeAlphabet.contains(String.fromCharCode(unit))) return false;
  }
  return true;
}

String? readShareCode(Object? raw) {
  if (raw is! String) return null;
  final code = raw.trim();
  return isShareCode(code) ? code : null;
}

String generateShareCode(Random random) {
  return String.fromCharCodes([
    for (var i = 0; i < shareCodeLength; i++)
      shareCodeAlphabet.codeUnitAt(random.nextInt(shareCodeAlphabet.length)),
  ]);
}
