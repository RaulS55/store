import 'customer.dart';
import 'map_date.dart';
import 'map_value.dart';
import 'product.dart';
import 'record_source.dart';
import 'sync_record.dart';

enum OrderStatus {
  borrador('Activo'),
  cerrado('Cerrado');

  const OrderStatus(this.label);
  final String label;

  static OrderStatus fromStorage(String value) {
    for (final status in OrderStatus.values) {
      if (status.name == value) return status;
    }
    throw FormatException('Unknown order status: $value');
  }
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

  factory OrderLine.fromMap(Map<String, dynamic> map) {
    final data = coerceStringKeyMap(map);
    final productMap = coerceStringKeyMap(data['product']);
    final productId = (productMap['id'] as String?)?.trim() ?? '';
    final variantMap = coerceStringKeyMap(data['variant']);
    return OrderLine(
      product: Product.fromMap(productId, productMap),
      variant: ProductVariant.fromMap(variantMap),
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product': product.toMap(),
      'variant': variant.toMap(),
      'quantity': quantity,
    };
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
    DateTime? updatedAt,
    this.closedAt,
    this.deletedAt,
    this.ivaEnabled = false,
    this.ivaPercent = 21,
    this.source = RecordSource.staff,
  }) : lines = lines ?? <OrderLine>[],
       createdAt = createdAt ?? DateTime.now().toUtc(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now().toUtc();

  final String id;
  final String orderNumber;
  Customer customer;
  final List<OrderLine> lines;
  OrderStatus status;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? closedAt;
  DateTime? deletedAt;
  bool ivaEnabled;
  double ivaPercent;
  RecordSource source;

  bool get isClosed => status == OrderStatus.cerrado;

  bool get isActive => status == OrderStatus.borrador;

  bool get isDeleted => deletedAt != null;

  bool get isCatalog => source == RecordSource.catalog;

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
      if (category == null) continue;
      counts[category] = (counts[category] ?? 0) + line.quantity;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in entries)
        CategoryQty(category: entry.key, quantity: entry.value),
    ];
  }

  factory DraftOrder.fromMap(String id, Map<String, dynamic> map) {
    final data = coerceStringKeyMap(map);
    final record = SyncRecord.fromMap(id, data);
    final customerMap = coerceStringKeyMap(data['customer']);
    final customerId = (customerMap['id'] as String?)?.trim() ?? '';
    final rawLines = data['lines'] as List<dynamic>? ?? const [];
    final rawStatus = data['status'] as String? ?? OrderStatus.borrador.name;
    return DraftOrder(
      id: record.id,
      orderNumber: (data['orderNumber'] as String? ?? '').trim(),
      customer: Customer.fromMap(customerId, customerMap),
      lines: [
        for (final line in rawLines)
          if (line is Map) OrderLine.fromMap(coerceStringKeyMap(line)),
      ],
      status: OrderStatus.fromStorage(rawStatus),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
      closedAt: parseOptionalMapDate(data['closedAt']),
      deletedAt: record.deletedAt,
      ivaEnabled: data['ivaEnabled'] as bool? ?? false,
      ivaPercent: (data['ivaPercent'] as num?)?.toDouble() ?? 21,
      source: RecordSource.fromStorage(data['source'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...SyncRecord(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      ).toMap(),
      'orderNumber': orderNumber.trim(),
      'customer': customer.toMap(),
      'lines': [for (final line in lines) line.toMap()],
      'status': status.name,
      'closedAt': closedAt?.toUtc().toIso8601String(),
      'ivaEnabled': ivaEnabled,
      'ivaPercent': ivaPercent,
      'source': source.name,
    };
  }
}
