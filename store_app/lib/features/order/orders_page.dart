import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/tokens.dart';
import 'order_actions.dart';
import 'order_card.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final wide = AppBreakpoints.isWide(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 24 : 20, wide ? 20 : 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedidos',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        store.orders.isEmpty
                            ? 'Todavía no hay pedidos abiertos.'
                            : '${store.orders.length} pedidos abiertos',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.slate,
                        ),
                      ),
                    ],
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
          Expanded(
            child: store.orders.isEmpty
                ? const _EmptyOrders()
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 24 : 16,
                      8,
                      wide ? 24 : 16,
                      24,
                    ),
                    itemCount: store.orders.length,
                    itemBuilder: (context, index) {
                      final order = store.orders[index];
                      return OrderSummaryCard(
                        order: order,
                        onTap: () {
                          store.setActiveOrder(order.id);
                          context.go('/pedido/${order.id}');
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _newOrder(BuildContext context) async {
    final customer = await showCustomerPicker(context);
    if (customer == null || !context.mounted) return;
    final order = context.read<AppStore>().createOrder(customer);
    context.go('/pedido/${order.id}');
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
            const Icon(Icons.assignment_outlined, color: AppColors.mutedText, size: 40),
            const SizedBox(height: 12),
            Text(
              'No hay pedidos abiertos',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Creá un pedido y asignalo a un cliente.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

