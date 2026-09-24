import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/order.dart';
import '../../theme/tokens.dart';
import 'order_actions.dart';
import 'order_card.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final wide = AppBreakpoints.isWide(context);
    final openOrders = store.orders;
    final closedOrders = store.closedOrders;
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
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pedidos',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _newOrder(context),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo pedido'),
                  ),
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
                Tab(
                  key: const ValueKey('orders-tab-closed'),
                  text: 'Cerrados',
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _OrdersList(
                    orders: openOrders,
                    empty: const _EmptyOrders(),
                    onTap: (order) {
                      store.setActiveOrder(order.id);
                      context.go('/pedido/${order.id}');
                    },
                  ),
                  _OrdersList(
                    orders: closedOrders,
                    empty: const _EmptyClosedOrders(),
                    showStatus: true,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este cliente ya tiene un pedido abierto.'),
        ),
      );
    }
    context.go('/pedido/${order.id}');
  }
}

String _tabLabel(String label, int count) {
  return count == 0 ? label : '$label ($count)';
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.empty,
    required this.onTap,
    this.showStatus = false,
    this.itemKey,
  });

  final List<DraftOrder> orders;
  final Widget empty;
  final ValueChanged<DraftOrder> onTap;
  final bool showStatus;
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
