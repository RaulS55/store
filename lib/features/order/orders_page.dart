import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/order.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/search_field.dart';
import 'order_actions.dart';
import 'order_card.dart';

enum OrderListSort {
  date('Fecha'),
  customer('Cliente'),
  balance('Falta pagar');

  const OrderListSort(this.label);
  final String label;
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _search = TextEditingController();
  OrderListSort _sort = OrderListSort.date;
  OrderListSort? _sortBeforeRemaining;
  bool _showRemaining = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final wide = AppBreakpoints.isWide(context);
    final query = _search.text.trim().toLowerCase();
    final openOrders = [
      for (final order in store.orders)
        if (_matchesOrderQuery(order, query)) order,
    ]..sort((a, b) => _compareOrders(a, b, open: true));
    final closedOrders = [
      for (final order in store.closedOrders)
        if (_matchesOrderQuery(order, query)) order,
    ]..sort((a, b) => _compareOrders(a, b, open: false));
    final searching = query.isNotEmpty;
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? 24 : 20,
                wide ? 20 : 16,
                wide ? 24 : 20,
                8,
              ),
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: _title(context)),
                        _remainingToggle(),
                        _searchRow(width: 360),
                        const SizedBox(width: 8),
                        _newOrderButton(context),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _title(context)),
                            _remainingToggle(),
                            _newOrderButton(context),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _searchRow(),
                      ],
                    ),
            ),
            TabBar(
              labelColor: AppColors.terracotta,
              unselectedLabelColor: AppColors.slate,
              indicatorColor: AppColors.terracotta,
              dividerColor: Theme.of(context).dividerColor,
              labelStyle: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              unselectedLabelStyle: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              tabs: [
                Tab(
                  key: const ValueKey('orders-tab-open'),
                  text: _tabLabel('Abiertos', openOrders.length),
                ),
                Tab(key: const ValueKey('orders-tab-closed'), text: 'Cerrados'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _OrdersList(
                    orders: openOrders,
                    empty: searching
                        ? const _EmptyOrderSearch()
                        : const _EmptyOrders(),
                    showRemaining: _showRemaining,
                    onTap: (order) {
                      store.setActiveOrder(order.id);
                      context.go('/pedido/${order.id}');
                    },
                  ),
                  _OrdersList(
                    orders: closedOrders,
                    empty: searching
                        ? const _EmptyOrderSearch()
                        : const _EmptyClosedOrders(),
                    showStatus: true,
                    showRemaining: _showRemaining,
                    itemKey: (order) => ValueKey('closed-order-${order.id}'),
                    onTap: (order) => context.push(invoiceRoute(order.id)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _newOrder(BuildContext context) async {
    final customer = await showCustomerPicker(context);
    if (customer == null || !context.mounted) return;
    final store = context.read<AppStore>();
    final existing = store.openOrderForCustomer(customer.id);
    final order = store.createOrder(customer);
    if (existing != null) {
      AppSnackBar.show(
        context,
        content: Text('Este cliente ya tiene un pedido abierto.'),
      );
    }
    context.go('/pedido/${order.id}');
  }

  Widget _title(BuildContext context) {
    return Text(
      'Pedidos',
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _searchRow({double? width}) {
    final field = _searchField();
    return Row(
      children: [
        if (width == null)
          Expanded(child: field)
        else
          SizedBox(width: width, child: field),
        _sortButton(),
      ],
    );
  }

  Widget _searchField() {
    return SearchField(
      key: const ValueKey('orders-search'),
      controller: _search,
      hint: 'Buscar cliente o número de pedido...',
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _remainingToggle() {
    return IconButton(
      key: const ValueKey('orders-remaining-view'),
      tooltip: _showRemaining ? 'Ver prendas' : 'Ver restante',
      onPressed: _toggleRemainingView,
      style: IconButton.styleFrom(
        backgroundColor: _showRemaining ? AppColors.terracottaChip : null,
        foregroundColor: _showRemaining
            ? AppColors.terracotta
            : AppColors.slate,
      ),
      icon: Icon(
        _showRemaining
            ? Icons.account_balance_wallet
            : Icons.account_balance_wallet_outlined,
      ),
    );
  }

  void _toggleRemainingView() {
    setState(() {
      if (_showRemaining) {
        _showRemaining = false;
        _sort = _sortBeforeRemaining ?? _sort;
        _sortBeforeRemaining = null;
        return;
      }
      _sortBeforeRemaining = _sort;
      _showRemaining = true;
      _sort = OrderListSort.balance;
    });
  }

  Widget _sortButton() {
    return PopupMenuButton<OrderListSort>(
      key: const ValueKey('orders-sort'),
      tooltip: 'Ordenar',
      initialValue: _sort,
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.sort, color: AppColors.slate),
      onSelected: (value) => setState(() => _sort = value),
      itemBuilder: (context) => [
        for (final sort in OrderListSort.values)
          CheckedPopupMenuItem(
            value: sort,
            checked: sort == _sort,
            child: Text(sort.label),
          ),
      ],
    );
  }

  int _compareOrders(DraftOrder a, DraftOrder b, {required bool open}) {
    switch (_sort) {
      case OrderListSort.date:
        return _orderDate(b, open: open).compareTo(_orderDate(a, open: open));
      case OrderListSort.customer:
        final byName = a.customer.name.toLowerCase().compareTo(
          b.customer.name.toLowerCase(),
        );
        if (byName != 0) return byName;
        return _orderDate(b, open: open).compareTo(_orderDate(a, open: open));
      case OrderListSort.balance:
        final byDue = b.remaining.compareTo(a.remaining);
        if (byDue != 0) return byDue;
        return _orderDate(b, open: open).compareTo(_orderDate(a, open: open));
    }
  }

  DateTime _orderDate(DraftOrder order, {required bool open}) {
    if (open) return order.createdAt;
    return order.closedAt ?? order.createdAt;
  }

  Widget _newOrderButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _newOrder(context),
      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Nuevo pedido'),
    );
  }
}

String _tabLabel(String label, int count) {
  return count == 0 ? label : '$label ($count)';
}

bool _matchesOrderQuery(DraftOrder order, String query) {
  if (query.isEmpty) return true;
  if (order.customer.name.toLowerCase().contains(query)) return true;
  if (order.orderNumber.toLowerCase().contains(query)) return true;
  if (_digitsContain(order.customer.phone, query)) return true;
  if (_digitsContain(order.customer.cuit, query)) return true;
  for (final line in order.lines) {
    if (line.product.name.toLowerCase().contains(query)) return true;
    if (line.product.matchesCodeQuery(query)) return true;
  }
  return false;
}

bool _digitsContain(String? value, String query) {
  if (value == null || value.isEmpty) return false;
  if (value.toLowerCase().contains(query)) return true;
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final queryDigits = query.replaceAll(RegExp(r'\D'), '');
  return queryDigits.isNotEmpty && digits.contains(queryDigits);
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.empty,
    required this.onTap,
    this.showStatus = false,
    this.showRemaining = false,
    this.itemKey,
  });

  final List<DraftOrder> orders;
  final Widget empty;
  final ValueChanged<DraftOrder> onTap;
  final bool showStatus;
  final bool showRemaining;
  final Key Function(DraftOrder order)? itemKey;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return empty;
    final wide = AppBreakpoints.isWide(context);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 12, wide ? 24 : 16, 24),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderSummaryCard(
          key: itemKey?.call(order),
          order: order,
          showStatus: showStatus,
          showRemaining: showRemaining,
          onTap: () => onTap(order),
        );
      },
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assignment_outlined,
              color: AppColors.mutedText,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Todavía no hay pedidos abiertos.',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Creá un pedido y asignalo a un cliente.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrderSearch extends StatelessWidget {
  const _EmptyOrderSearch();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: AppColors.mutedText, size: 40),
            const SizedBox(height: 12),
            Text(
              'No encontramos pedidos',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Probá con otro cliente o número de pedido.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyClosedOrders extends StatelessWidget {
  const _EmptyClosedOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              color: AppColors.mutedText,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Sin pedidos cerrados',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Todavía no hay pedidos cerrados',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}
