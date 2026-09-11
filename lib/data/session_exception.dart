class SessionException implements Exception {
  const SessionException(this.message);

  final String message;

  @override
  String toString() => message;
}
