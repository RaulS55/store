import 'package:flutter_test/flutter_test.dart';
import 'package:store_app/data/formatters.dart';

void main() {
  test('MoneyFormat groups thousands with a dot', () {
    expect(MoneyFormat.grouped(1000), '1.000');
    expect(MoneyFormat.grouped(12500), '12.500');
    expect(MoneyFormat.compact(1000), r'$1.000');
    expect(MoneyFormat.detailed(1000.5), r'$1.000,50');
    expect(MoneyFormat.parse('1.000'), 1000);
    expect(MoneyFormat.parse('12.500'), 12500);
  });

  test('ArgentinePhone accepts a local mobile number', () {
    expect(
      ArgentinePhone.normalize('+54 9 11 5555-1234'),
      '+54 9 11 5555-1234',
    );
    expect(ArgentinePhone.normalize('11 5555-1234'), '+54 9 11 5555-1234');
    expect(ArgentinePhone.normalize('011 15 5555-1234'), '+54 9 11 5555-1234');
    expect(
      ArgentinePhone.normalize('+54 9 351 555-1234'),
      '+54 9 351 555-1234',
    );
    expect(ArgentinePhone.normalize('351 15 555-1234'), '+54 9 351 555-1234');
    expect(ArgentinePhone.normalize('hola'), isNull);
    expect(ArgentinePhone.normalize('123'), isNull);
    expect(ArgentinePhone.normalize('15 5555-1234'), isNull);
    expect(ArgentinePhone.normalize('+1 202 555 0143'), isNull);
    expect(ArgentinePhone.localInput('+54 9 11 5555-1234'), '11 5555-1234');
    expect(
      ArgentinePhone.withCountryPrefix('9 11 5555-1234'),
      '+54 9 11 5555-1234',
    );
    expect(
      ArgentinePhone.withCountryPrefix('11 5555-1234'),
      '+54 11 5555-1234',
    );
  });
}
