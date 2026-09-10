import 'package:url_launcher/url_launcher.dart';

import '../models/order.dart';
import 'formatters.dart';

class OrderShare {
  static String message(DraftOrder order) {
    final buffer = StringBuffer()
      ..writeln('Hola ${order.customer.name},')
      ..writeln('te envío el resumen de tu pedido ${order.orderNumber}:')
      ..writeln();
    for (final line in order.lines) {
      buffer.writeln(
        '• ${line.quantity}× ${line.product.name} '
        '(${line.variant.size} · ${line.variant.color}) — '
        '${MoneyFormat.detailed(line.lineTotal)}',
      );
    }
    buffer
      ..writeln()
      ..writeln('Subtotal: ${MoneyFormat.detailed(order.subtotal)}')
      ..writeln('IVA 21%: ${MoneyFormat.detailed(order.iva)}')
      ..writeln('Total: ${MoneyFormat.detailed(order.total)}')
      ..writeln()
      ..writeln('Moda Stock');
    return buffer.toString();
  }

  static Uri? whatsappUri(DraftOrder order) {
    final digits = order.customer.whatsappDigits;
    if (digits.isEmpty || order.lines.isEmpty) return null;
    return Uri.parse(
      'https://wa.me/$digits?text=${Uri.encodeComponent(message(order))}',
    );
  }

  static Future<bool> openWhatsApp(DraftOrder order) async {
    final uri = whatsappUri(order);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
