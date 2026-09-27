import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class MoneyFormat {
  static String compact(double value) => _format(value, decimals: 0);

  static String detailed(double value) => _format(value, decimals: 2);

  static String labeled(double value) => 'ARS${compact(value)}';

  static String grouped(num value) =>
      groupDigits(value.round().abs().toString());

  static String groupDigits(String digits) {
    if (digits.isEmpty) return '';
    final normalized = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < normalized.length; i++) {
      final remaining = normalized.length - i;
      if (i > 0 && remaining % 3 == 0) buffer.write('.');
      buffer.write(normalized[i]);
    }
    return buffer.toString();
  }

  static double? parse(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  static final TextInputFormatter inputFormatter =
      TextInputFormatter.withFunction((oldValue, newValue) {
        final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isEmpty) return const TextEditingValue();
        final formatted = groupDigits(digits);
        return TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      });

  static String _format(double value, {required int decimals}) {
    final sign = value < 0 ? '-' : '';
    final abs = value.abs();
    if (decimals <= 0) return '$sign\$${grouped(abs)}';
    final cents = (abs * 100).round();
    final whole = cents ~/ 100;
    final fraction = (cents % 100).toString().padLeft(2, '0');
    return '$sign\$${groupDigits('$whole')},$fraction';
  }
}

class PercentFormat {
  static String of(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return NumberFormat('0.##', 'es_AR').format(value);
  }

  static double? tryParse(String raw) {
    final trimmed = raw.trim().replaceAll('%', '').replaceAll(' ', '');
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed.replaceAll(',', '.'));
  }
}

class DateFormatters {
  static final DateFormat invoice = DateFormat("dd/MM/yyyy HH:mm");
  static final DateFormat short = DateFormat('dd/MM/yyyy');
  static final DateFormat header = DateFormat("d 'de' MMMM 'de' y", 'es');
}
