import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';

class ProductHolder {
  const ProductHolder({
    required this.order,
    required this.variant,
    required this.quantity,
  });

  final DraftOrder order;
  final ProductVariant variant;
  final int quantity;

  String get key => '${order.id}::${variant.key}';
}

/// Orders, open and closed, that include [productId].
List<ProductHolder> holdersForProduct(
  String productId,
  Iterable<DraftOrder> orders,
) {
  final byKey = <String, ProductHolder>{};
  for (final order in orders) {
    if (order.isDeleted) continue;
    for (final line in order.lines) {
      if (line.product.id != productId || line.quantity <= 0) continue;
      final holder = ProductHolder(
        order: order,
        variant: line.variant,
        quantity: line.quantity,
      );
      final existing = byKey[holder.key];
      if (existing == null) {
        byKey[holder.key] = holder;
      } else {
        byKey[holder.key] = ProductHolder(
          order: order,
          variant: line.variant,
          quantity: existing.quantity + line.quantity,
        );
      }
    }
  }
  final holders = byKey.values.toList();
  holders.sort((a, b) {
    final byColor = Swatches.compareName(a.variant.color, b.variant.color);
    if (byColor != 0) return byColor;
    final bySize = ApparelSizes.compare(a.variant.size, b.variant.size);
    if (bySize != 0) return bySize;
    final byName = a.order.customer.name.toLowerCase().compareTo(
      b.order.customer.name.toLowerCase(),
    );
    if (byName != 0) return byName;
    return b.order.createdAt.compareTo(a.order.createdAt);
  });
  return holders;
}

Future<void> showProductHoldersSheet(BuildContext context, String productId) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _ProductHoldersSheet(productId: productId),
  );
}

class _ProductHoldersSheet extends StatelessWidget {
  const _ProductHoldersSheet({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final product = store.productById(productId);
    final holders = holdersForProduct(productId, [
      ...store.orders,
      ...store.closedOrders,
    ]);
    final name = product?.name ?? 'esta prenda';

    return SizedBox(
      key: const ValueKey('product-holders-sheet'),
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: const Text('Quién se la llevó'),
            subtitle: Text(name),
          ),
          Expanded(
            child: holders.isEmpty
                ? const _EmptyHolders()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      _HoldersSummary(holders: holders),
                      const SizedBox(height: 12),
                      for (final group in _groups(holders)) ...[
                        _ColorHeader(
                          color: group.first.variant.color,
                          swatch: group.first.variant.swatch,
                          units: group.fold(
                            0,
                            (sum, item) => sum + item.quantity,
                          ),
                        ),
                        for (final holder in group)
                          _HolderTile(holder: holder, product: product),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHolders extends StatelessWidget {
  const _EmptyHolders();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline,
            color: AppColors.mutedText,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            'Todavía ningún cliente se llevó esta prenda.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Cuando un pedido la incluya, vas a ver el color, el talle y el cliente.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}

class _HoldersSummary extends StatelessWidget {
  const _HoldersSummary({required this.holders});

  final List<ProductHolder> holders;

  @override
  Widget build(BuildContext context) {
    final customers = {for (final holder in holders) holder.order.customer.id};
    final units = holders.fold(0, (sum, holder) => sum + holder.quantity);
    final clientLabel = customers.length == 1
        ? '1 cliente'
        : '${customers.length} clientes';
    final unitLabel = units == 1 ? '1 prenda' : '$units prendas';
    return Text(
      '$clientLabel · $unitLabel',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
    );
  }
}

class _ColorHeader extends StatelessWidget {
  const _ColorHeader({
    required this.color,
    required this.swatch,
    required this.units,
  });

  final String color;
  final Color swatch;
  final int units;

  @override
  Widget build(BuildContext context) {
    final label = color.trim().isEmpty ? 'Sin color' : color;
    final unitLabel = units == 1 ? '1 u.' : '$units u.';
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: swatch,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.lightBorder),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            unitLabel,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

class _HolderTile extends StatelessWidget {
  const _HolderTile({required this.holder, required this.product});

  final ProductHolder holder;
  final Product? product;

  @override
  Widget build(BuildContext context) {
    final size = holder.variant.size.trim();
    final equivalent = product?.equivalentSizeFor(size) ?? size;
    final sizeLabel = size.isEmpty
        ? 'Sin talle'
        : (equivalent == size ? 'Talle $size' : 'Talle $size ($equivalent)');
    final units = holder.quantity == 1 ? '1 u.' : '${holder.quantity} u.';
    final color = holder.variant.color.trim().isEmpty
        ? 'Sin color'
        : holder.variant.color.trim();
    final number = holder.order.orderNumber.trim();
    final orderLabel = number.isEmpty ? 'Pedido' : number;

    return ListTile(
      key: ValueKey('product-holder-${holder.key}'),
      contentPadding: EdgeInsets.zero,
      title: Text(holder.order.customer.name),
      subtitle: Text(
        '$color · $sizeLabel · $units\n$orderLabel · ${holder.order.status.label}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        final router = GoRouter.maybeOf(context);
        Navigator.of(context).pop();
        router?.push('/pedido/${holder.order.id}');
      },
    );
  }
}

List<List<ProductHolder>> _groups(List<ProductHolder> holders) {
  final groups = <List<ProductHolder>>[];
  for (final holder in holders) {
    if (groups.isEmpty ||
        groups.last.first.variant.color != holder.variant.color) {
      groups.add([holder]);
    } else {
      groups.last.add(holder);
    }
  }
  return groups;
}
