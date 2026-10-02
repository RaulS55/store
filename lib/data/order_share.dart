import 'package:url_launcher/url_launcher.dart';

import '../models/order.dart';
import 'formatters.dart';

class OrderShare {
  static String message(DraftOrder order, {bool? includeProductCode}) {
    final showCode = includeProductCode ?? order.includeProductCodeInInvoice;
    final buffer = StringBuffer()
      ..writeln('Hola ${order.customer.name},')
      ..writeln('te envío el resumen de tu pedido ${order.orderNumber}:')
      ..writeln();
    for (final line in order.sortedLines) {
      buffer.writeln(
        '• ${line.quantity}× ${_itemName(line, showCode)} '
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
    buffer.writeln('Total: ${MoneyFormat.detailed(order.total)}');
    if (order.hasSena) {
      buffer
        ..writeln('Seña: ${MoneyFormat.detailed(order.sena ?? 0)}')
        ..writeln('Restante: ${MoneyFormat.detailed(order.remaining)}');
    }
    buffer
      ..writeln()
      ..writeln('Moda Stock');
    return buffer.toString();
  }

  static String _itemName(OrderLine line, bool includeProductCode) {
    final sku = line.product.sku.trim();
    if (!includeProductCode || sku.isEmpty) return line.product.name;
    return '$sku - ${line.product.name}';
  }

  static Uri? whatsappUri(DraftOrder order, {bool? includeProductCode}) {
    if (order.lines.isEmpty) return null;
    final digits = order.customer.whatsappDigits;
    final text = Uri.encodeComponent(
      message(order, includeProductCode: includeProductCode),
    );
    if (digits.isEmpty) {
      return Uri.parse('https://wa.me/?text=$text');
    }
    return Uri.parse('https://wa.me/$digits?text=$text');
  }

  static Future<bool> openWhatsApp(
    DraftOrder order, {
    bool? includeProductCode,
  }) async {
    return openUri(whatsappUri(order, includeProductCode: includeProductCode));
  }

  static String catalogMessage(
    DraftOrder order, {
    bool updated = false,
    List<OrderLine>? addedLines,
  }) {
    final headline = updated
        ? 'Actualicé el pedido ${order.orderNumber}:'
        : 'Quiero este pedido ${order.orderNumber}:';
    final lines = OrderLine.sorted(addedLines ?? order.lines);
    final total = lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
    final buffer = StringBuffer()
      ..writeln('Hola, soy ${order.customer.name}.')
      ..writeln(headline)
      ..writeln();
    for (final line in lines) {
      buffer.writeln(
        '• ${line.quantity}× ${line.product.name} '
        '(${line.variant.size} · ${line.variant.color}) — '
        '${MoneyFormat.detailed(line.lineTotal)}',
      );
    }
    buffer
      ..writeln()
      ..writeln('Total: ${MoneyFormat.detailed(total)}');
    return buffer.toString();
  }

  static Uri? catalogWhatsAppUri(
    DraftOrder order,
    String? phone, {
    bool updated = false,
    List<OrderLine>? addedLines,
  }) {
    final lines = addedLines ?? order.lines;
    if (lines.isEmpty) return null;
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    final text = Uri.encodeComponent(
      catalogMessage(order, updated: updated, addedLines: addedLines),
    );
    return Uri.parse('https://wa.me/$digits?text=$text');
  }

  static Future<bool> openCatalogWhatsApp(
    DraftOrder order,
    String? phone,
  ) async {
    return openUri(catalogWhatsAppUri(order, phone));
  }

  static Future<bool> openUri(Uri? uri) async {
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
