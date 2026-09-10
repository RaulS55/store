import 'product.dart';

enum PaymentMethod {
  efectivo('Efectivo', 'Pago en caja o al entregar'),
  transferencia('Transferencia', 'Transferencia bancaria (48 hs)'),
  tarjeta('Tarjeta', 'Crédito / débito (sujeto a aprobación)');

  const PaymentMethod(this.label, this.subtitle);
  final String label;
  final String subtitle;
}

enum OrderStatus {
  borrador('borrador'),
  facturado('facturado');

  const OrderStatus(this.label);
  final String label;
}

class OrderLine {
  const OrderLine({
    required this.product,
    required this.variant,
    required this.quantity,
  });

  final Product product;
  final ProductVariant variant;
  final int quantity;

  String get lineKey => '${product.id}::${variant.key}';

  String get variantSku => product.variantSku(variant);

  double get unitPrice => product.price;
  double get lineTotal => unitPrice * quantity;

  OrderLine copyWith({
    Product? product,
    ProductVariant? variant,
    int? quantity,
  }) {
    return OrderLine(
      product: product ?? this.product,
      variant: variant ?? this.variant,
      quantity: quantity ?? this.quantity,
    );
  }
}

class InvoiceRecord {
  const InvoiceRecord({
    required this.orderNumber,
    required this.issuedAt,
    required this.customerName,
    required this.total,
    required this.paymentMethod,
  });

  final String orderNumber;
  final DateTime issuedAt;
  final String customerName;
  final double total;
  final PaymentMethod paymentMethod;
}
