import 'package:hive_ce/hive.dart';

import 'hive_bootstrap.dart';

class CatalogCartLine {
  const CatalogCartLine({
    required this.productId,
    required this.size,
    required this.color,
    required this.quantity,
    this.requested = false,
    this.awaiting = false,
  });

  final String productId;
  final String size;
  final String color;
  final int quantity;
  final bool requested;
  final bool awaiting;

  String get lineKey => '$productId::$size|$color';

  CatalogCartLine copyWith({int? quantity, bool? requested, bool? awaiting}) {
    return CatalogCartLine(
      productId: productId,
      size: size,
      color: color,
      quantity: quantity ?? this.quantity,
      requested: requested ?? this.requested,
      awaiting: awaiting ?? this.awaiting,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'size': size,
      'color': color,
      'quantity': quantity,
      'requested': requested,
      'awaiting': awaiting,
    };
  }

  factory CatalogCartLine.fromMap(Map<dynamic, dynamic> map) {
    return CatalogCartLine(
      productId: (map['productId'] as String? ?? '').trim(),
      size: map['size'] as String? ?? '',
      color: map['color'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      requested: map['requested'] as bool? ?? false,
      awaiting: map['awaiting'] as bool? ?? false,
    );
  }
}

class CatalogOpenOrder {
  const CatalogOpenOrder({
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.orderCreatedAt,
    required this.customerCreatedAt,
  });

  final String orderId;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final DateTime orderCreatedAt;
  final DateTime customerCreatedAt;

  CatalogOpenOrder copyWith({String? customerName, String? customerPhone}) {
    return CatalogOpenOrder(
      orderId: orderId,
      orderNumber: orderNumber,
      customerId: customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      orderCreatedAt: orderCreatedAt,
      customerCreatedAt: customerCreatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'orderNumber': orderNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'orderCreatedAt': orderCreatedAt.toUtc().toIso8601String(),
      'customerCreatedAt': customerCreatedAt.toUtc().toIso8601String(),
    };
  }

  static CatalogOpenOrder? fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return null;
    final orderId = (map['orderId'] as String? ?? '').trim();
    final orderNumber = (map['orderNumber'] as String? ?? '').trim();
    final customerId = (map['customerId'] as String? ?? '').trim();
    final customerName = (map['customerName'] as String? ?? '').trim();
    final customerPhone = (map['customerPhone'] as String?)?.trim();
    final orderCreatedAt = DateTime.tryParse(
      (map['orderCreatedAt'] as String? ?? '').trim(),
    )?.toUtc();
    final customerCreatedAt = DateTime.tryParse(
      (map['customerCreatedAt'] as String? ?? '').trim(),
    )?.toUtc();
    if (orderId.isEmpty ||
        orderNumber.isEmpty ||
        customerId.isEmpty ||
        customerName.length < 2 ||
        orderCreatedAt == null ||
        customerCreatedAt == null) {
      return null;
    }
    return CatalogOpenOrder(
      orderId: orderId,
      orderNumber: orderNumber,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone == null || customerPhone.isEmpty
          ? null
          : customerPhone,
      orderCreatedAt: orderCreatedAt,
      customerCreatedAt: customerCreatedAt,
    );
  }
}

abstract class CatalogCartCache {
  List<CatalogCartLine> load(String companyId);

  Future<void> save(String companyId, List<CatalogCartLine> lines);

  Future<void> clear(String companyId);

  CatalogOpenOrder? loadOpenOrder(String companyId);

  Future<void> saveOpenOrder(String companyId, CatalogOpenOrder? order);

  Map<String, dynamic>? loadPendingRequest(String companyId);

  Future<void> savePendingRequest(String companyId, Map<String, dynamic>? data);
}

class MemoryCatalogCartCache implements CatalogCartCache {
  final _data = <String, List<CatalogCartLine>>{};
  final _openOrders = <String, CatalogOpenOrder>{};
  final _pendingRequests = <String, Map<String, dynamic>>{};

  @override
  List<CatalogCartLine> load(String companyId) {
    return [for (final line in _data[companyId] ?? const []) line];
  }

  @override
  Future<void> save(String companyId, List<CatalogCartLine> lines) async {
    _data[companyId] = [...lines];
  }

  @override
  Future<void> clear(String companyId) async {
    _data.remove(companyId);
  }

  @override
  CatalogOpenOrder? loadOpenOrder(String companyId) => _openOrders[companyId];

  @override
  Future<void> saveOpenOrder(String companyId, CatalogOpenOrder? order) async {
    if (order == null) {
      _openOrders.remove(companyId);
      return;
    }
    _openOrders[companyId] = order;
  }

  @override
  Map<String, dynamic>? loadPendingRequest(String companyId) {
    final data = _pendingRequests[companyId];
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<void> savePendingRequest(
    String companyId,
    Map<String, dynamic>? data,
  ) async {
    if (data == null) {
      _pendingRequests.remove(companyId);
      return;
    }
    _pendingRequests[companyId] = Map<String, dynamic>.from(data);
  }
}

class HiveCatalogCartCache implements CatalogCartCache {
  HiveCatalogCartCache({this.boxName = catalogGuestCartsBox});

  final String boxName;
  final MemoryCatalogCartCache _memory = MemoryCatalogCartCache();
  Box<dynamic>? _box;

  Future<void> ensureOpen() async {
    if (_box != null) return;
    try {
      if (Hive.isBoxOpen(boxName)) {
        _box = Hive.box<dynamic>(boxName);
      } else {
        _box = await Hive.openBox<dynamic>(boxName);
      }
    } catch (_) {
      _box = null;
    }
  }

  @override
  List<CatalogCartLine> load(String companyId) {
    final box = _box;
    if (box == null) return _memory.load(companyId);
    final raw = box.get(companyId);
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) CatalogCartLine.fromMap(item),
    ].where((line) => line.productId.isNotEmpty && line.quantity > 0).toList();
  }

  @override
  Future<void> save(String companyId, List<CatalogCartLine> lines) async {
    await ensureOpen();
    final box = _box;
    if (box == null) {
      await _memory.save(companyId, lines);
      return;
    }
    await box.put(companyId, [for (final line in lines) line.toMap()]);
  }

  @override
  Future<void> clear(String companyId) async {
    await ensureOpen();
    final box = _box;
    if (box == null) {
      await _memory.clear(companyId);
      return;
    }
    await box.delete(companyId);
  }

  String _openOrderKey(String companyId) => '$companyId::__openOrder';

  @override
  CatalogOpenOrder? loadOpenOrder(String companyId) {
    final box = _box;
    if (box == null) return _memory.loadOpenOrder(companyId);
    final raw = box.get(_openOrderKey(companyId));
    if (raw is! Map) return null;
    return CatalogOpenOrder.fromMap(raw);
  }

  @override
  Future<void> saveOpenOrder(String companyId, CatalogOpenOrder? order) async {
    await ensureOpen();
    final box = _box;
    if (box == null) {
      await _memory.saveOpenOrder(companyId, order);
      return;
    }
    final key = _openOrderKey(companyId);
    if (order == null) {
      await box.delete(key);
      return;
    }
    await box.put(key, order.toMap());
  }

  String _pendingKey(String companyId) => '$companyId::__pendingRequest';

  @override
  Map<String, dynamic>? loadPendingRequest(String companyId) {
    final box = _box;
    if (box == null) return _memory.loadPendingRequest(companyId);
    final raw = box.get(_pendingKey(companyId));
    if (raw is! Map) return null;
    return raw.map((key, value) => MapEntry('$key', value));
  }

  @override
  Future<void> savePendingRequest(
    String companyId,
    Map<String, dynamic>? data,
  ) async {
    await ensureOpen();
    final box = _box;
    if (box == null) {
      await _memory.savePendingRequest(companyId, data);
      return;
    }
    final key = _pendingKey(companyId);
    if (data == null) {
      await box.delete(key);
      return;
    }
    await box.put(key, data);
  }
}
