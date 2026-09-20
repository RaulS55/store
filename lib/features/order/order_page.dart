import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/product_image.dart';
import '../../widgets/qty_stepper.dart';
import '../../widgets/search_field.dart';
import '../../widgets/variant_picker.dart';
import 'order_actions.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final order = context.read<AppStore>().orderById(widget.orderId);
      if (order != null && order.isActive) {
        context.read<AppStore>().setActiveOrder(widget.orderId);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final order = store.orderById(widget.orderId);
    if (order == null) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No encontramos este pedido.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/pedido'),
                child: const Text('Volver a pedidos'),
              ),
            ],
          ),
        ),
      );
    }
    final wide = AppBreakpoints.isWide(context);
    return wide
        ? _WebOrder(
            order: order,
            query: _query,
            onQuery: _setQuery,
            search: _search,
          )
        : _MobileOrder(
            order: order,
            query: _query,
            onQuery: _setQuery,
            search: _search,
          );
  }

  void _setQuery(String value) => setState(() => _query = value);
}

void _leaveOrder(BuildContext context, DraftOrder order) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  if (order.isClosed) {
    context.go('/clientes/${order.customer.id}');
    return;
  }
  context.go('/pedido');
}

class _MobileOrder extends StatelessWidget {
  const _MobileOrder({
    required this.order,
    required this.query,
    required this.onQuery,
    required this.search,
  });

  final DraftOrder order;
  final String query;
  final ValueChanged<String> onQuery;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _leaveOrder(context, order),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    order.isClosed ? 'Pedido cerrado' : 'Armar pedido',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _StatusBadge(order: order),
              ],
            ),
          ),
          if (!order.isClosed) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SearchField(
                controller: search,
                hint: 'Buscar productos para agregar...',
                onChanged: onQuery,
              ),
            ),
            if (query.isNotEmpty) _SearchHits(query: query, orderId: order.id),
          ],
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                _CustomerTile(order: order, readOnly: order.isClosed),
                const SizedBox(height: 10),
                if (order.lines.isEmpty)
                  const _EmptyLines()
                else
                  for (final line in order.lines)
                    _LineTile(
                      orderId: order.id,
                      line: line,
                      readOnly: order.isClosed,
                    ),
                const SizedBox(height: 12),
                _Totals(order: order),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: WhatsAppButton(order: order),
          ),
          if (!order.isClosed) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: FilledButton(
                onPressed: order.lines.isEmpty
                    ? null
                    : () => closeOrderFlow(context, order),
                child: const Text('Cerrar pedido'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: CancelOrderButton(order: order),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () => openInvoice(context, order.id),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Ver factura'),
              ),
            ),
        ],
      ),
    );
  }
}

class _WebOrder extends StatelessWidget {
  const _WebOrder({
    required this.order,
    required this.query,
    required this.onQuery,
    required this.search,
  });

  final DraftOrder order;
  final String query;
  final ValueChanged<String> onQuery;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _leaveOrder(context, order),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.isClosed ? 'Pedido cerrado' : 'Armar pedido',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusBadge(order: order),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.isClosed
                              ? 'Prendas del pedido'
                              : 'Buscar productos y armar pedido',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (!order.isClosed) ...[
                          const SizedBox(height: 12),
                          SearchField(
                            controller: search,
                            hint:
                                'Buscar por nombre, código, SKU o categoría...',
                            onChanged: onQuery,
                          ),
                          if (query.isNotEmpty)
                            _SearchHits(query: query, orderId: order.id),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Líneas del pedido (${order.lines.length})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: order.lines.isEmpty
                              ? const _EmptyLines()
                              : ListView(
                                  children: [
                                    for (final line in order.lines)
                                      _LineTile(
                                        orderId: order.id,
                                        line: line,
                                        readOnly: order.isClosed,
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _Panel(
                    child: ListView(
                      children: [
                        Text(
                          'Cliente y resumen',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        _CustomerTile(order: order, readOnly: order.isClosed),
                        const SizedBox(height: 16),
                        Text(
                          'Resumen del pedido',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _Totals(order: order),
                        const SizedBox(height: 20),
                        WhatsAppButton(order: order),
                        if (!order.isClosed) ...[
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: order.lines.isEmpty
                                ? null
                                : () => closeOrderFlow(context, order),
                            child: const Text('Cerrar pedido'),
                          ),
                          const SizedBox(height: 4),
                          CancelOrderButton(order: order),
                        ] else ...[
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => openInvoice(context, order.id),
                            icon: const Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                            ),
                            label: const Text('Ver factura'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: child,
    );
  }
}

class _SearchHits extends StatelessWidget {
  const _SearchHits({required this.query, required this.orderId});
  final String query;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final q = query.toLowerCase();
    final hits = store.products
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q) ||
              p.brand.toLowerCase().contains(q) ||
              p.categoryLabel.toLowerCase().contains(q) ||
              p.audienceLabel.toLowerCase().contains(q),
        )
        .take(6)
        .toList();
    if (hits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Sin resultados para agregar'),
      );
    }
    return Column(
      children: [
        for (final product in hits)
          _HitTile(product: product, orderId: orderId),
      ],
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.product, required this.orderId});
  final Product product;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => _pickAndAdd(context, product),
      leading: SizedBox(
        width: 40,
        height: 40,
        child: ProductImage(
          path: product.image,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      title: Text(product.name),
      subtitle: Text('${product.sku} · ${MoneyFormat.compact(product.price)}'),
      trailing: const Icon(Icons.add, color: AppColors.terracotta),
    );
  }

  Future<void> _pickAndAdd(BuildContext context, Product product) async {
    final variant = await showVariantPickerSheet(context, product);
    if (variant == null || !context.mounted) return;
    context.read<AppStore>().addToOrder(product, variant, orderId: orderId);
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.order, this.readOnly = false});
  final DraftOrder order;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final customer = order.customer;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.person_outline,
                size: 16,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (customer.detailSubtitle != null)
                    Text(
                      customer.detailSubtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.slate,
                      ),
                    ),
                ],
              ),
            ),
            if (!readOnly)
              TextButton(
                key: const ValueKey('change-order-customer'),
                onPressed: () => _pickCustomer(context),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  foregroundColor: AppColors.slate,
                  textStyle: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Cambiar'),
              ),
          ],
        ),
        if (!readOnly)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 2),
            child: Text(
              'Se pedirá confirmación antes de cambiar el cliente.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
            ),
          ),
      ],
    );
  }

  Future<void> _pickCustomer(BuildContext context) async {
    final store = context.read<AppStore>();
    final current = order.customer;
    final blocked = {
      for (final open in store.orders)
        if (open.customer.id != current.id) open.customer.id,
    };
    final selected = await showCustomerPicker(
      context,
      blockedCustomerIds: blocked,
      confirmCustomer: (dialogContext, selected) {
        if (selected.id == current.id) return Future.value(true);
        return showAppConfirmDialog(
          context: dialogContext,
          title: 'Cambiar cliente',
          message:
              'El pedido se va a asignar a ${selected.name}. Confirmá para completar el cambio.',
          confirmLabel: 'Confirmar',
          icon: Icons.swap_horiz,
          destructive: false,
        );
      },
    );
    if (selected == null || !context.mounted) return;
    if (selected.id == current.id) return;
    final ok = context.read<AppStore>().selectCustomer(order.id, selected);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este cliente ya tiene un pedido abierto.'),
        ),
      );
    }
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.orderId,
    required this.line,
    this.readOnly = false,
  });
  final String orderId;
  final OrderLine line;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: ProductImage(
              path: line.product.image,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    if (line.product.categoryLabel.isNotEmpty)
                      line.product.categoryLabel,
                    'SKU: ${line.variantSku}',
                  ].join(' · '),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
                Text(
                  '${line.variant.size} · ${line.variant.color}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (readOnly)
                Text(
                  '×${line.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                )
              else
                QtyStepper(
                  value: line.quantity,
                  min: 1,
                  max:
                      context
                          .watch<AppStore>()
                          .productById(line.product.id)
                          ?.variantFor(line.variant.size, line.variant.color)
                          ?.stock ??
                      line.variant.stock,
                  onChanged: (q) => store.setLineQty(orderId, line.lineKey, q),
                ),
              const SizedBox(height: 6),
              Text(
                MoneyFormat.detailed(line.unitPrice),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                MoneyFormat.detailed(line.lineTotal),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (!readOnly)
            IconButton(
              onPressed: () => store.removeLine(orderId, line.lineKey),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.order});
  final DraftOrder order;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Subtotal', MoneyFormat.detailed(order.subtotal), false),
      if (order.ivaEnabled)
        (order.ivaLabel, MoneyFormat.detailed(order.iva), false),
      ('Total', MoneyFormat.detailed(order.total), true),
    ];
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  row.$1,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: row.$3 ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                const Spacer(),
                Text(
                  row.$2,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: row.$3 ? AppColors.terracotta : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.order});
  final DraftOrder order;

  @override
  Widget build(BuildContext context) {
    final closed = order.isClosed;
    final color = closed ? AppColors.slate : AppColors.terracotta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '#${order.orderNumber} / ${order.status.label.toLowerCase()}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _EmptyLines extends StatelessWidget {
  const _EmptyLines();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.shopping_bag_outlined, color: AppColors.mutedText),
          const SizedBox(height: 8),
          Text(
            'Todavía no hay prendas en el pedido',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            'Buscá un producto para agregarlo.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
          ),
        ],
      ),
    );
  }
}
