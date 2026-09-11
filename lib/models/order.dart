import 'customer.dart';
import 'product.dart';

enum OrderStatus {
  borrador('Activo'),
  cerrado('Cerrado');

  const OrderStatus(this.label);
  final String label;
}

class CategoryQty {
  const CategoryQty({required this.category, required this.quantity});

  final ApparelCategory category;
  final int quantity;
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

class DraftOrder {
  DraftOrder({
    required this.id,
    required this.orderNumber,
    required this.customer,
    List<OrderLine>? lines,
    this.status = OrderStatus.borrador,
    DateTime? createdAt,
    this.closedAt,
    this.ivaEnabled = false,
    this.ivaPercent = 21,
  }) : lines = lines ?? <OrderLine>[],
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String orderNumber;
  Customer customer;
  final List<OrderLine> lines;
  OrderStatus status;
  final DateTime createdAt;
  DateTime? closedAt;
  bool ivaEnabled;
  double ivaPercent;

  bool get isClosed => status == OrderStatus.cerrado;

  bool get isActive => status == OrderStatus.borrador;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  double get subtotal => lines.fold(0, (sum, line) => sum + line.lineTotal);

  double get ivaRate => ivaEnabled ? ivaPercent / 100 : 0;

  double get iva => subtotal * ivaRate;

  double get total => subtotal + iva;

  String get ivaLabel => 'IVA ($_ivaPercentText%)';

  String get _ivaPercentText {
    if (ivaPercent == ivaPercent.roundToDouble()) {
      return ivaPercent.toInt().toString();
    }
    return ivaPercent.toString();
  }

  List<CategoryQty> get categorySummary {
    final counts = <ApparelCategory, int>{};
    for (final line in lines) {
      final category = line.product.category;
      counts[category] = (counts[category] ?? 0) + line.quantity;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in entries)
        CategoryQty(category: entry.key, quantity: entry.value),
    ];
  }
}
