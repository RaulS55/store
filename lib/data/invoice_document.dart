import '../models/customer.dart';
import '../models/order.dart';
import 'formatters.dart';

class InvoiceLineGroup {
  const InvoiceLineGroup(this.lines);

  final List<OrderLine> lines;

  OrderLine get first => lines.first;

  int get quantity => lines.fold(0, (sum, line) => sum + line.quantity);

  double get unitPrice => first.unitPrice;

  double get total =>
      lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
}

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

  static List<InvoiceLineGroup> groupedLines(Iterable<OrderLine> lines) {
    final groups = <InvoiceLineGroup>[];
    List<OrderLine>? current;
    for (final line in lines) {
      if (current == null) {
        current = [line];
        continue;
      }
      final last = current.last;
      if (last.product.id == line.product.id &&
          last.unitPrice == line.unitPrice) {
        current.add(line);
      } else {
        groups.add(InvoiceLineGroup(current));
        current = [line];
      }
    }
    if (current != null && current.isNotEmpty) {
      groups.add(InvoiceLineGroup(current));
    }
    return groups;
  }

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

  static String combinationDetail(OrderLine line) {
    final detail = lineDetail(line);
    if (line.quantity <= 1) return detail;
    return '$detail ×${line.quantity}';
  }

  static String filename(DraftOrder order) {
    final raw = order.orderNumber.trim().isEmpty
        ? order.id
        : order.orderNumber.trim();
    final safe = raw.replaceAll(RegExp(r'[^\w.\-]+'), '-');
    return 'factura-$safe.pdf';
  }
}
