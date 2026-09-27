import '../models/customer.dart';
import '../models/order.dart';
import 'formatters.dart';

class InvoiceDocument {
  static const brand = 'MODA STOCK';
  static const subtitle = 'RESUMEN DE FACTURA';

  static DateTime issuedAt(DraftOrder order) =>
      order.closedAt ?? order.createdAt;

  static String issuedAtLabel(DraftOrder order) =>
      DateFormatters.invoice.format(issuedAt(order));

  static String phone(Customer customer) {
    final value = customer.phone?.trim() ?? '';
    return value.isEmpty ? '—' : value;
  }

  static String? cuit(Customer customer) {
    final value = customer.cuit?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  static String? condition(Customer customer) => customer.taxCondition?.label;

  static String lineTitle(OrderLine line, {required bool includeProductCode}) {
    return [
      if (includeProductCode && line.product.sku.trim().isNotEmpty)
        line.product.sku.trim(),
      line.product.name,
    ].join(' - ').toUpperCase();
  }

  static String lineDetail(OrderLine line) {
    return [
      if (line.product.categoryLabel.isNotEmpty) line.product.categoryLabel,
      'Talle ${line.variant.size}',
      line.variant.color,
    ].join(' · ');
  }

  static String filename(DraftOrder order) {
    final raw = order.orderNumber.trim().isEmpty
        ? order.id
        : order.orderNumber.trim();
    final safe = raw.replaceAll(RegExp(r'[^\w.\-]+'), '-');
    return 'factura-$safe.pdf';
  }
}
