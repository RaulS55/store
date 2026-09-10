import 'package:intl/intl.dart';

class MoneyFormat {
  static final NumberFormat _ars0 = NumberFormat.currency(
    locale: 'es_AR',
    symbol: r'$',
    decimalDigits: 0,
  );

  static final NumberFormat _ars2 = NumberFormat.currency(
    locale: 'es_AR',
    symbol: r'$',
    decimalDigits: 2,
  );

  static String compact(double value) => _ars0.format(value);

  static String detailed(double value) => _ars2.format(value);

  static String labeled(double value) => 'ARS${compact(value)}';
}

class DateFormatters {
  static final DateFormat invoice = DateFormat("dd/MM/yyyy HH:mm");
  static final DateFormat short = DateFormat('dd/MM/yyyy');
  static final DateFormat header = DateFormat("d 'de' MMMM 'de' y", 'es');
}
