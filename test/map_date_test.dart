import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/models/customer.dart';
import 'package:store_app/models/map_date.dart';

void main() {
  final stamp = DateTime.utc(2026, 9, 11, 12);

  test('parseMapDate reads ISO strings and DateTime', () {
    expect(parseMapDate(stamp), stamp);
    expect(parseMapDate(stamp.toIso8601String()), stamp);
  });

  test('parseMapDate reads Firestore timestamp maps from web', () {
    expect(
      parseMapDate({
        'seconds': stamp.millisecondsSinceEpoch / 1000,
        'nanoseconds': 0,
      }),
      stamp,
    );
    expect(
      parseMapDate({
        '_seconds': stamp.millisecondsSinceEpoch / 1000,
        '_nanoseconds': 0,
      }),
      stamp,
    );
  });

  test('parseMapDate reads epoch numbers', () {
    expect(parseMapDate(stamp.millisecondsSinceEpoch), stamp);
    expect(parseMapDate(stamp.millisecondsSinceEpoch.toDouble()), stamp);
    expect(parseMapDate(stamp.millisecondsSinceEpoch / 1000), stamp);
  });

  test('parseOptionalMapDate treats blanks as null', () {
    expect(parseOptionalMapDate(null), isNull);
    expect(parseOptionalMapDate(''), isNull);
  });

  test('Customer.fromMap reads a web Firestore timestamp', () {
    final customer = Customer.fromMap('c1', {
      'name': 'Ana',
      'createdAt': {
        'seconds': stamp.millisecondsSinceEpoch / 1000,
        'nanoseconds': 0.0,
      },
      'updatedAt': {
        'seconds': stamp.millisecondsSinceEpoch / 1000,
        'nanoseconds': 0.0,
      },
    });
    expect(customer.createdAt, stamp);
    expect(customer.updatedAt, stamp);
  });

  test('parseMapDate still rejects unknown values', () {
    expect(() => parseMapDate(true), throwsFormatException);
  });
}
