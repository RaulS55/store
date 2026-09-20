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
      ..writeln('Subtotal: ${MoneyFormat.detailed(order.subtotal)}');
    if (order.ivaEnabled) {
      buffer.writeln('${order.ivaLabel}: ${MoneyFormat.detailed(order.iva)}');
    }
    buffer
      ..writeln('Total: ${MoneyFormat.detailed(order.total)}')
      ..writeln()
      ..writeln('Moda Stock');
    return buffer.toString();
  }

  static Uri? whatsappUri(DraftOrder order) {
    if (order.lines.isEmpty) return null;
    final digits = order.customer.whatsappDigits;
    final text = Uri.encodeComponent(message(order));
    if (digits.isEmpty) {
      return Uri.parse('https://wa.me/?text=$text');
    }
    return Uri.parse('https://wa.me/$digits?text=$text');
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
