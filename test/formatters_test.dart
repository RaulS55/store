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
}
