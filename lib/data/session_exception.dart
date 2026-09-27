class SessionException implements Exception {
  const SessionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CatalogOrderLockedException extends SessionException {
  const CatalogOrderLockedException()
    : super('Ese pedido ya no se puede modificar.');
}
