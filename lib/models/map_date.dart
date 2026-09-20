DateTime parseMapDate(dynamic value) {
  final parsed = tryParseMapDate(value);
  if (parsed != null) return parsed;
  throw FormatException('Invalid date: $value');
}

DateTime? parseOptionalMapDate(dynamic value) {
  if (value == null) return null;
  if (value is String && value.isEmpty) return null;
  return parseMapDate(value);
}

DateTime? tryParseMapDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  if (value is String) {
    if (value.isEmpty) return null;
    return DateTime.parse(value).toUtc();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  if (value is num) {
    return _fromEpochNumber(value);
  }
  if (value is Map) {
    final seconds = _asNum(value['seconds'] ?? value['_seconds']);
    if (seconds != null) {
      final nanos = _asNum(value['nanoseconds'] ?? value['_nanoseconds']) ?? 0;
      return _fromTimestamp(seconds, nanos);
    }
  }
  try {
    final date = (value as dynamic).toDate();
    if (date is DateTime) return date.toUtc();
  } catch (_) {}
  try {
    final seconds = _asNum((value as dynamic).seconds);
    if (seconds != null) {
      final nanos = _asNum((value as dynamic).nanoseconds) ?? 0;
      return _fromTimestamp(seconds, nanos);
    }
  } catch (_) {}
  return null;
}

DateTime _fromEpochNumber(num value) {
  if (value.abs() >= 1e12) {
    return DateTime.fromMillisecondsSinceEpoch(value.round(), isUtc: true);
  }
  if (value.abs() >= 1e9) {
    return _fromTimestamp(value, 0);
  }
  return DateTime.fromMillisecondsSinceEpoch(value.round(), isUtc: true);
}

DateTime _fromTimestamp(num seconds, num nanoseconds) {
  return DateTime.fromMicrosecondsSinceEpoch(
    seconds.round() * 1000000 + nanoseconds.round() ~/ 1000,
    isUtc: true,
  );
}

num? _asNum(dynamic value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}
