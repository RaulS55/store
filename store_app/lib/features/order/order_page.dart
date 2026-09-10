import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../models/customer.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../widgets/product_image.dart';
import '../../widgets/qty_stepper.dart';
import '../../widgets/search_field.dart';
import '../../widgets/variant_picker.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = AppBreakpoints.isWide(context);
    return wide ? _WebOrder(query: _query, onQuery: _setQuery, search: _search)
        : _MobileOrder(query: _query, onQuery: _setQuery, search: _search);
  }

  void _setQuery(String value) => setState(() => _query = value);
}

class _MobileOrder extends StatelessWidget {
  const _MobileOrder({
    required this.query,
    required this.onQuery,
    required this.search,
  });

  final String query;
  final ValueChanged<String> onQuery;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    'Armar pedido',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _DraftBadge(number: store.orderNumber),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchField(
              controller: search,
              hint: 'Buscar productos para agregar...',
              onChanged: onQuery,
            ),
          ),
          if (query.isNotEmpty) _SearchHits(query: query),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                _CustomerTile(customer: store.selectedCustomer),
                const SizedBox(height: 10),
                if (store.lines.isEmpty)
                  const _EmptyLines()
                else
                  for (final line in store.lines) _LineTile(line: line),
                const SizedBox(height: 12),
                _Totals(store: store),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton(
              onPressed: store.lines.isEmpty
                  ? null
                  : () => context.go('/pedido/facturar'),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continuar a facturar'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebOrder extends StatelessWidget {
  const _WebOrder({
    required this.query,
    required this.onQuery,
    required this.search,
  });

  final String query;
  final ValueChanged<String> onQuery;
  final TextEditingController search;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Armar pedido / facturar',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
                          'Buscar productos y armar pedido',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        SearchField(
                          controller: search,
                          hint: 'Buscar por nombre, código, SKU o categoría...',
                          onChanged: onQuery,
                        ),
                        if (query.isNotEmpty) _SearchHits(query: query),
                        const SizedBox(height: 12),
                        Text(
                          'Líneas del pedido (${store.lines.length})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: store.lines.isEmpty
                              ? const _EmptyLines()
                              : ListView(
                                  children: [
                                    for (final line in store.lines)
                                      _LineTile(line: line, dense: false),
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
                          'Datos de facturación y pago',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        _CustomerTile(customer: store.selectedCustomer),
                        const SizedBox(height: 16),
                        Text(
                          'Resumen del pedido',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _Totals(store: store),
                        const SizedBox(height: 16),
                        Text(
                          'Método de pago',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _PaymentPicker(store: store),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: store.lines.isEmpty ||
                                  store.selectedCustomer == null
                              ? null
                              : () => context.go('/pedido/facturar'),
                          child: Text(
                            'Confirmar y facturar  ${MoneyFormat.detailed(store.total)}',
                          ),
                        ),
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
  const _SearchHits({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final q = query.toLowerCase();
    final hits = store.products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q) ||
            p.category.label.toLowerCase().contains(q))
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
        for (final product in hits) _HitTile(product: product),
      ],
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.product});
  final Product product;

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
    context.read<AppStore>().addToOrder(product, variant);
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer});
  final Customer? customer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _pickCustomer(context),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md),
          color: isDark ? AppColors.darkElevated : AppColors.lightSurface,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline, color: AppColors.slate),
            const SizedBox(width: 10),
            Expanded(
              child: customer == null
                  ? const Text('Cliente / facturar')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cliente / facturar',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.mutedText),
                        ),
                        Text(
                          customer!.name.toUpperCase(),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'CUIT ${customer!.cuit}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.slate),
                        ),
                      ],
                    ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomer(BuildContext context) async {
    final store = context.read<AppStore>();
    final selected = await showModalBottomSheet<Customer>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          children: [
            const ListTile(title: Text('Elegí un cliente')),
            for (final customer in store.customers)
              ListTile(
                title: Text(customer.name),
                subtitle: Text('CUIT ${customer.cuit} · ${customer.taxCondition.label}'),
                onTap: () => Navigator.pop(context, customer),
              ),
          ],
        );
      },
    );
    if (selected != null) store.selectCustomer(selected);
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line, this.dense = true});
  final OrderLine line;
  final bool dense;

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
                  'SKU: ${line.variantSku}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
                Text(
                  '${line.product.name} · ${line.variant.size} · ${line.variant.color}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              QtyStepper(
                value: line.quantity,
                min: 1,
                max: context.watch<AppStore>()
                        .productById(line.product.id)
                        ?.variantFor(line.variant.size, line.variant.color)
                        ?.stock ??
                    line.variant.stock,
                onChanged: (q) => store.setLineQty(line.lineKey, q),
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
          IconButton(
            onPressed: () => store.removeLine(line.lineKey),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Subtotal', MoneyFormat.detailed(store.subtotal), false),
      ('IVA 21%', MoneyFormat.detailed(store.iva), false),
      ('Total', MoneyFormat.detailed(store.total), true),
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

class _PaymentPicker extends StatelessWidget {
  const _PaymentPicker({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RadioGroup<PaymentMethod>(
          groupValue: store.paymentMethod,
          onChanged: (v) {
            if (v != null) store.setPaymentMethod(v);
          },
          child: Column(
            children: [
              for (final method in PaymentMethod.values)
                RadioListTile<PaymentMethod>(
                  value: method,
                  title: Text(method.label),
                  subtitle: Text(method.subtitle),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DraftBadge extends StatelessWidget {
  const _DraftBadge({required this.number});
  final String number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.terracotta.withValues(alpha: 0.4)),
      ),
      child: Text(
        '#$number / borrador',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.terracotta,
        ),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.slate,
            ),
          ),
        ],
      ),
    );
  }
}
