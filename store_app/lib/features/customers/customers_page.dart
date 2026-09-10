import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/customer.dart';
import '../../theme/tokens.dart';
import 'customer_sheets.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<AppStore>().customers;
    final wide = AppBreakpoints.isWide(context);
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 24 : 20, wide ? 20 : 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clientes',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Agenda de clientes para armar pedidos. Todavía no hay backend.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => showCustomerForm(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo cliente'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final customer in customers)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.terracottaChip,
                  child: Text(
                    customer.initials,
                    style: const TextStyle(
                      color: AppColors.terracotta,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(customer.name),
                subtitle: _subtitle(context, customer) == null
                    ? null
                    : Text(_subtitle(context, customer)!),
                isThreeLine: customer.detailSubtitle != null &&
                    context.read<AppStore>().ordersForCustomer(customer.id).isNotEmpty,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/clientes/${customer.id}'),
              ),
            ),
        ],
      ),
    );
  }

  String? _subtitle(BuildContext context, Customer customer) {
    final history = context.read<AppStore>().ordersForCustomer(customer.id);
    final lines = <String>[
      if (customer.detailSubtitle != null) customer.detailSubtitle!,
      if (history.isNotEmpty)
        history.length == 1 ? '1 pedido' : '${history.length} pedidos',
    ];
    if (lines.isEmpty) return null;
    return lines.join('\n');
  }
}
