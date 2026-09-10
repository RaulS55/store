import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/tokens.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final customers = context.watch<AppStore>().customers;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            'Clientes',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Agenda local para facturar. Todavía no hay backend.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.slate,
            ),
          ),
          const SizedBox(height: 16),
          for (final customer in customers)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.terracottaChip,
                  child: Text(
                    customer.name.substring(0, 1),
                    style: const TextStyle(
                      color: AppColors.terracotta,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(customer.name),
                subtitle: Text(
                  'CUIT ${customer.cuit}\n${customer.taxCondition.label}'
                  '${customer.address == null ? '' : '\n${customer.address}'}',
                ),
                isThreeLine: true,
              ),
            ),
        ],
      ),
    );
  }
}
