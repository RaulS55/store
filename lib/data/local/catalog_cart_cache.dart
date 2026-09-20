import 'package:hive_ce/hive.dart';

import 'hive_bootstrap.dart';

class CatalogCartLine {
  const CatalogCartLine({
    required this.productId,
    required this.size,
    required this.color,
    required this.quantity,
  });

  final String productId;
  final String size;
  final String color;
  final int quantity;

  String get lineKey => '$productId::$size|$color';

  CatalogCartLine copyWith({int? quantity}) {
    return CatalogCartLine(
      productId: productId,
      size: size,
      color: color,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'size': size,
      'color': color,
      'quantity': quantity,
    };
  }

  factory CatalogCartLine.fromMap(Map<dynamic, dynamic> map) {
    return CatalogCartLine(
      productId: (map['productId'] as String? ?? '').trim(),
      size: map['size'] as String? ?? '',
      color: map['color'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

abstract class CatalogCartCache {
  List<CatalogCartLine> load(String companyId);

  Future<void> save(String companyId, List<CatalogCartLine> lines);

  Future<void> clear(String companyId);
}

class MemoryCatalogCartCache implements CatalogCartCache {
  final _data = <String, List<CatalogCartLine>>{};

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
}
