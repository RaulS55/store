import 'map_date.dart';
import 'map_value.dart';

/// Units of one lot still on hand for a single size and color.
class StockLayer {
  const StockLayer({
    required this.lotId,
    required this.quantity,
    required this.receivedAt,
  });

  final String lotId;
  final int quantity;
  final DateTime receivedAt;

  StockLayer copyWith({String? lotId, int? quantity, DateTime? receivedAt}) {
    return StockLayer(
      lotId: lotId ?? this.lotId,
      quantity: quantity ?? this.quantity,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }

  factory StockLayer.fromMap(Map<String, dynamic> map) {
    final data = coerceStringKeyMap(map);
    return StockLayer(
      lotId: (data['lotId'] as String? ?? '').trim(),
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      receivedAt:
          parseOptionalMapDate(data['receivedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lotId': lotId.trim(),
      'quantity': quantity,
      'receivedAt': receivedAt.toUtc().toIso8601String(),
    };
  }
}

/// Units taken from one lot layer when stock is reserved or sold.
class LotAllocation {
  const LotAllocation({
    required this.lotId,
    required this.quantity,
    required this.receivedAt,
  });

  final String lotId;
  final int quantity;
  final DateTime receivedAt;

  LotAllocation copyWith({String? lotId, int? quantity, DateTime? receivedAt}) {
    return LotAllocation(
      lotId: lotId ?? this.lotId,
      quantity: quantity ?? this.quantity,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }

  factory LotAllocation.fromMap(Map<String, dynamic> map) {
    final data = coerceStringKeyMap(map);
    return LotAllocation(
      lotId: (data['lotId'] as String? ?? '').trim(),
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      receivedAt:
          parseOptionalMapDate(data['receivedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lotId': lotId.trim(),
      'quantity': quantity,
      'receivedAt': receivedAt.toUtc().toIso8601String(),
    };
  }
}

class StockConsumption {
  const StockConsumption({
    required this.layers,
    required this.taken,
    required this.shortage,
  });

  final List<StockLayer> layers;
  final List<LotAllocation> taken;
  final int shortage;
}

class AllocationSplit {
  const AllocationSplit({required this.kept, required this.returned});

  final List<LotAllocation> kept;
  final List<LotAllocation> returned;
}

class VariantStockPlan {
  const VariantStockPlan({required this.layers, required this.needsLot});

  final List<StockLayer> layers;
  final bool needsLot;
}

class StockLayers {
  const StockLayers._();

  static int quantityOf(Iterable<StockLayer> layers) {
    var sum = 0;
    for (final layer in layers) {
      if (layer.quantity > 0) sum += layer.quantity;
    }
    return sum;
  }

  static bool sameMoment(DateTime a, DateTime b) {
    return a.toUtc().isAtSameMomentAs(b.toUtc());
  }

  static List<StockLayer> sorted(Iterable<StockLayer> layers) {
    final merged = <StockLayer>[];
    for (final layer in layers) {
      if (layer.quantity <= 0) continue;
      final index = merged.indexWhere(
        (item) =>
            item.lotId == layer.lotId &&
            sameMoment(item.receivedAt, layer.receivedAt),
      );
      if (index >= 0) {
        merged[index] = merged[index].copyWith(
          quantity: merged[index].quantity + layer.quantity,
        );
      } else {
        merged.add(layer);
      }
    }
    merged.sort((a, b) {
      final byDate = a.receivedAt.compareTo(b.receivedAt);
      if (byDate != 0) return byDate;
      return a.lotId.compareTo(b.lotId);
    });
    return merged;
  }

  static String oldestLotId(Iterable<StockLayer> layers) {
    StockLayer? oldest;
    for (final layer in sorted(layers)) {
      if (layer.lotId.trim().isEmpty) continue;
      if (oldest == null || layer.receivedAt.isBefore(oldest.receivedAt)) {
        oldest = layer;
      }
    }
    return oldest?.lotId ?? '';
  }

  static String? lastLotId(Iterable<StockLayer> layers) {
    final ordered = sorted(layers);
    for (var i = ordered.length - 1; i >= 0; i--) {
      final id = ordered[i].lotId.trim();
      if (id.isNotEmpty) return id;
    }
    return null;
  }

  static List<StockLayer> receive({
    required List<StockLayer> layers,
    required String lotId,
    required int quantity,
    required DateTime receivedAt,
  }) {
    if (quantity <= 0) return sorted(layers);
    final id = lotId.trim();
    final current = sorted(layers);
    final open = current.indexWhere(
      (layer) => layer.lotId == id && layer.quantity > 0,
    );
    if (open >= 0) {
      final layer = current[open];
      current[open] = layer.copyWith(quantity: layer.quantity + quantity);
      return current;
    }
    current.add(
      StockLayer(lotId: id, quantity: quantity, receivedAt: receivedAt.toUtc()),
    );
    return sorted(current);
  }

  static List<StockLayer> claimUnassigned(
    List<StockLayer> layers,
    String lotId,
  ) {
    final id = lotId.trim();
    if (id.isEmpty) return sorted(layers);
    return sorted([
      for (final layer in layers)
        if (layer.quantity > 0 && layer.lotId.trim().isEmpty)
          layer.copyWith(lotId: id)
        else
          layer,
    ]);
  }

  static StockConsumption consume(List<StockLayer> layers, int quantity) {
    if (quantity <= 0) {
      return StockConsumption(
        layers: sorted(layers),
        taken: const [],
        shortage: 0,
      );
    }
    final current = [...sorted(layers)];
    final taken = <LotAllocation>[];
    var left = quantity;
    for (var i = 0; i < current.length && left > 0; i++) {
      final layer = current[i];
      final used = layer.quantity < left ? layer.quantity : left;
      taken.add(
        LotAllocation(
          lotId: layer.lotId,
          quantity: used,
          receivedAt: layer.receivedAt,
        ),
      );
      current[i] = layer.copyWith(quantity: layer.quantity - used);
      left -= used;
    }
    return StockConsumption(
      layers: sorted(current),
      taken: taken,
      shortage: left,
    );
  }

  static List<StockLayer> restore(
    List<StockLayer> layers,
    List<LotAllocation> returned,
  ) {
    final current = [...sorted(layers)];
    for (final allocation in returned) {
      if (allocation.quantity <= 0) continue;
      final index = current.indexWhere(
        (layer) =>
            layer.lotId == allocation.lotId &&
            sameMoment(layer.receivedAt, allocation.receivedAt),
      );
      if (index >= 0) {
        current[index] = current[index].copyWith(
          quantity: current[index].quantity + allocation.quantity,
        );
      } else {
        current.add(
          StockLayer(
            lotId: allocation.lotId,
            quantity: allocation.quantity,
            receivedAt: allocation.receivedAt,
          ),
        );
      }
    }
    return sorted(current);
  }

  static List<StockLayer> removeAllocations(
    List<StockLayer> layers,
    List<LotAllocation> allocations,
  ) {
    var current = sorted(layers);
    for (final allocation in allocations) {
      var left = allocation.quantity;
      if (left <= 0) continue;
      final index = current.indexWhere(
        (layer) =>
            layer.lotId == allocation.lotId &&
            sameMoment(layer.receivedAt, allocation.receivedAt),
      );
      if (index >= 0) {
        final layer = current[index];
        final used = layer.quantity < left ? layer.quantity : left;
        left -= used;
        current[index] = layer.copyWith(quantity: layer.quantity - used);
        current = sorted(current);
      }
      if (left <= 0) continue;
      final ordered = [...current];
      for (var i = 0; i < ordered.length && left > 0; i++) {
        if (ordered[i].lotId != allocation.lotId) continue;
        final used = ordered[i].quantity < left ? ordered[i].quantity : left;
        ordered[i] = ordered[i].copyWith(quantity: ordered[i].quantity - used);
        left -= used;
      }
      current = sorted(ordered);
    }
    return current;
  }

  static List<LotAllocation> mergeAllocations(
    Iterable<LotAllocation> allocations,
  ) {
    final merged = <LotAllocation>[];
    for (final allocation in allocations) {
      if (allocation.quantity <= 0) continue;
      final index = merged.indexWhere(
        (item) =>
            item.lotId == allocation.lotId &&
            sameMoment(item.receivedAt, allocation.receivedAt),
      );
      if (index >= 0) {
        merged[index] = merged[index].copyWith(
          quantity: merged[index].quantity + allocation.quantity,
        );
      } else {
        merged.add(allocation);
      }
    }
    return merged;
  }

  static AllocationSplit release(
    List<LotAllocation> allocations,
    int quantity,
  ) {
    var left = quantity;
    final kept = [...allocations];
    final returned = <LotAllocation>[];
    for (var i = kept.length - 1; i >= 0 && left > 0; i--) {
      final allocation = kept[i];
      if (allocation.quantity <= 0) {
        kept.removeAt(i);
        continue;
      }
      final give = allocation.quantity < left ? allocation.quantity : left;
      returned.add(allocation.copyWith(quantity: give));
      final remain = allocation.quantity - give;
      if (remain <= 0) {
        kept.removeAt(i);
      } else {
        kept[i] = allocation.copyWith(quantity: remain);
      }
      left -= give;
    }
    return AllocationSplit(kept: kept, returned: returned);
  }
}

String? lotForNewUnits({
  required bool requireLot,
  required String? addedLotId,
  required List<StockLayer> layers,
  required String fallbackLotId,
}) {
  final chosen = addedLotId?.trim() ?? '';
  if (requireLot) {
    if (chosen.isEmpty) return null;
    return chosen;
  }
  if (chosen.isNotEmpty) return chosen;
  final last = StockLayers.lastLotId(layers);
  if (last != null) return last;
  return fallbackLotId.trim();
}

VariantStockPlan planVariantStock({
  required List<StockLayer> previousLayers,
  required bool isNew,
  required int nextStock,
  required String? addedLotId,
  required bool requireLot,
  required bool claimUnassignedLots,
  required String fallbackLotId,
  required DateTime receivedAt,
}) {
  var target = nextStock;
  if (target < 0) target = 0;
  if (target > 999999) target = 999999;
  if (isNew) {
    if (target == 0) {
      return const VariantStockPlan(layers: [], needsLot: false);
    }
    final lot = lotForNewUnits(
      requireLot: requireLot,
      addedLotId: addedLotId,
      layers: const [],
      fallbackLotId: fallbackLotId,
    );
    if (lot == null) {
      return const VariantStockPlan(layers: [], needsLot: true);
    }
    return VariantStockPlan(
      layers: [
        StockLayer(lotId: lot, quantity: target, receivedAt: receivedAt),
      ],
      needsLot: false,
    );
  }

  final prior = StockLayers.sorted(previousLayers);
  final delta = target - StockLayers.quantityOf(prior);
  if (delta == 0) {
    final chosen = addedLotId?.trim() ?? '';
    final layers = claimUnassignedLots && chosen.isNotEmpty
        ? StockLayers.claimUnassigned(prior, chosen)
        : prior;
    return VariantStockPlan(layers: layers, needsLot: false);
  }
  if (delta > 0) {
    final chosen = addedLotId?.trim() ?? '';
    final base = claimUnassignedLots && chosen.isNotEmpty
        ? StockLayers.claimUnassigned(prior, chosen)
        : prior;
    final lot = lotForNewUnits(
      requireLot: requireLot,
      addedLotId: addedLotId,
      layers: base,
      fallbackLotId: fallbackLotId,
    );
    if (lot == null) {
      return VariantStockPlan(layers: base, needsLot: true);
    }
    return VariantStockPlan(
      layers: StockLayers.receive(
        layers: base,
        lotId: lot,
        quantity: delta,
        receivedAt: receivedAt,
      ),
      needsLot: false,
    );
  }
  return VariantStockPlan(
    layers: StockLayers.consume(prior, -delta).layers,
    needsLot: false,
  );
}
