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

class ArgentinePhone {
  static const countryPrefix = '+54';
  static const hint = '+54 9 11 5555-1234';
  static const localHint = '11 5555-1234';

  static final localInputFormatter = _ArgentineLocalPhoneFormatter();
  static final _chars = RegExp(r'^[0-9+\s().-]+$');

  /// Drops a leading country code so the field can show [countryPrefix] fixed.
  /// Also drops the mobile 9 that follows +54 in the international form.
  static String localInput(String raw) {
    var text = raw;
    var hadCountry = false;
    if (text.startsWith(countryPrefix)) {
      hadCountry = true;
      text = text.substring(countryPrefix.length);
    } else if (RegExp(r'^54[\s-]').hasMatch(text)) {
      hadCountry = true;
      text = text.substring(2);
    }
    text = text.replaceFirst(RegExp(r'^[\s-]+'), '');
    if (hadCountry && RegExp(r'^9(?:[\s-]|$)').hasMatch(text)) {
      text = text.substring(1).replaceFirst(RegExp(r'^[\s-]+'), '');
    }
    return text;
  }

  static String withCountryPrefix(String raw) {
    final local = localInput(raw).trim();
    if (local.isEmpty) return '';
    if (local.startsWith('+')) return local;
    return '$countryPrefix $local';
  }

  static bool isValid(String raw) => normalize(raw) != null;

  /// Canonical Argentine mobile form, or null when [raw] is not a local number.
  static String? normalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || !_chars.hasMatch(trimmed)) return null;
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('54')) {
      digits = digits.substring(2);
      if (digits.startsWith('0')) digits = digits.substring(1);
      if (digits.startsWith('9') && digits.length > 10) {
        digits = digits.substring(1);
      }
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    } else if (digits.startsWith('9') && digits.length == 11) {
      digits = digits.substring(1);
    }
    final parsed = _national(digits);
    if (parsed == null) return null;
    return _format(parsed.$1, parsed.$2);
  }

  static (String, int)? _national(String digits) {
    if (digits.length == 10 && _isNational(digits)) {
      return (digits, digits.startsWith('11') ? 2 : 3);
    }
    if (digits.length != 12) return null;
    for (final areaLength in [2, 3, 4]) {
      if (digits.length < areaLength + 2) continue;
      if (digits.substring(areaLength, areaLength + 2) != '15') continue;
      final area = digits.substring(0, areaLength);
      if (!_validArea(area, areaLength)) continue;
      final national = area + digits.substring(areaLength + 2);
      if (national.length == 10 && _isNational(national)) {
        return (national, areaLength);
      }
    }
    return null;
  }

  static bool _validArea(String area, int length) {
    if (length == 2) return area == '11';
    return area.startsWith('2') || area.startsWith('3');
  }

  static bool _isNational(String digits) {
    if (digits.length != 10) return false;
    if (digits.startsWith('11')) return true;
    return digits.startsWith('2') || digits.startsWith('3');
  }

  static String _format(String national, int areaLength) {
    final area = national.substring(0, areaLength);
    final local = national.substring(areaLength);
    final head = local.length > 4 ? local.length - 4 : 0;
    final pretty = head == 0
        ? local
        : '${local.substring(0, head)}-${local.substring(head)}';
    return '+54 9 $area $pretty';
  }
}

class _ArgentineLocalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = ArgentinePhone.localInput(newValue.text);
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class DateFormatters {
  static final DateFormat invoice = DateFormat("dd/MM/yyyy HH:mm");
  static final DateFormat short = DateFormat('dd/MM/yyyy');
  static final DateFormat header = DateFormat("d 'de' MMMM 'de' y", 'es');
}
