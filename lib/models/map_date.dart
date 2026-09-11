DateTime parseMapDate(dynamic value) {
  if (value is DateTime) return value.toUtc();
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value).toUtc();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  if (value != null) {
    final toDate = (value as dynamic).toDate;
    if (toDate is Function) {
      return (toDate() as DateTime).toUtc();
    }
  }
  throw FormatException('Invalid date: $value');
}

DateTime? parseOptionalMapDate(dynamic value) {
  if (value == null) return null;
  if (value is String && value.isEmpty) return null;
  return parseMapDate(value);
}
