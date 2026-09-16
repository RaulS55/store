import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/customer.dart';
import '../../theme/tokens.dart';
import '../order/order_actions.dart';
import '../order/order_card.dart';
import 'customer_actions.dart';
import 'customer_sheets.dart';

class CustomerDetailPage extends StatelessWidget {
  const CustomerDetailPage({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final Customer? customer = store.customerById(customerId);
    if (customer == null) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No encontramos este cliente.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/clientes'),
                child: const Text('Volver a clientes'),
              ),
            ],
          ),
        ),
      );
    }

    final history = store.ordersForCustomer(customer.id);
    final wide = AppBreakpoints.isWide(context);
    final canDelete = canDeleteCustomer(context);

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 8, wide ? 24 : 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/clientes');
                  }
                },
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  customer.name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: const ValueKey('edit-customer'),
                tooltip: 'Editar',
                onPressed: () => showCustomerForm(context, customer: customer),
                icon: const Icon(Icons.edit_outlined),
              ),
              if (canDelete)
                IconButton(
                  key: const ValueKey('delete-customer'),
                  tooltip: 'Eliminar',
                  onPressed: () => deleteCustomerWithConfirm(
                    context: context,
                    customer: customer,
                  ),
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.stockLow,
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          if (customer.detailSubtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Text(
                customer.detailSubtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
              ),
            ),
          if (customer.address != null && customer.address!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                customer.address!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
              ),
            ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Historial de pedidos',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              history.isEmpty
                  ? 'Todavía no hay pedidos para este cliente.'
                  : '${history.length} pedidos · activos y cerrados',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    color: AppColors.mutedText,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sin pedidos',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            )
          else
            for (final order in history)
              OrderSummaryCard(
                order: order,
                showCustomer: false,
                showStatus: true,
                onTap: () {
                  if (order.isActive) {
                    store.setActiveOrder(order.id);
                    context.push('/pedido/${order.id}');
                    return;
                  }
                  context.push(invoiceRoute(order.id));
                },
              ),
        ],
      ),
    );
  }
}
