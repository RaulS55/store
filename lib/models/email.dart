String normalizeEmail(String email) => email.trim().toLowerCase();

bool isValidEmail(String email) {
  final normalized = normalizeEmail(email);
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized);
}
