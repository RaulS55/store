import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/customer.dart';
import '../../theme/tokens.dart';
import '../../widgets/search_field.dart';
import 'customer_sheets.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final query = _search.text.trim().toLowerCase();
    final customers = [
      for (final customer in store.customers)
        if (_matchesCustomerQuery(customer, query)) customer,
    ];
    final wide = AppBreakpoints.isWide(context);
    final hPad = wide ? 24.0 : 20.0;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, wide ? 20 : 16, hPad, 8),
            child: wide
                ? Row(
                    children: [
                      Expanded(child: _title(context)),
                      SizedBox(width: 360, child: _searchField()),
                      const SizedBox(width: 8),
                      _newCustomerButton(context),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _title(context)),
                          _newCustomerButton(context),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _searchField(),
                    ],
                  ),
          ),
          Expanded(
            child: customers.isEmpty
                ? _EmptyCustomers(searching: query.isNotEmpty)
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return Card(
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
                          isThreeLine:
                              customer.detailSubtitle != null &&
                              context
                                  .read<AppStore>()
                                  .ordersForCustomer(customer.id)
                                  .isNotEmpty,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go('/clientes/${customer.id}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _title(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clientes',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Agenda de clientes para armar pedidos.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
        ),
      ],
    );
  }

  Widget _searchField() {
    return SearchField(
      key: const ValueKey('customers-search'),
      controller: _search,
      hint: 'Buscar cliente, CUIT o teléfono...',
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _newCustomerButton(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => showCustomerForm(context),
      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Nuevo cliente'),
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

bool _matchesCustomerQuery(Customer customer, String query) {
  if (query.isEmpty) return true;
  if (customer.name.toLowerCase().contains(query)) return true;
  if (customer.address?.toLowerCase().contains(query) ?? false) return true;
  if (customer.taxCondition?.label.toLowerCase().contains(query) ?? false) {
    return true;
  }
  if (_digitsContain(customer.phone, query)) return true;
  if (_digitsContain(customer.cuit, query)) return true;
  return false;
}

bool _digitsContain(String? value, String query) {
  if (value == null || value.isEmpty) return false;
  if (value.toLowerCase().contains(query)) return true;
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final queryDigits = query.replaceAll(RegExp(r'\D'), '');
  return queryDigits.isNotEmpty && digits.contains(queryDigits);
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.people_outline,
              size: 40,
              color: AppColors.mutedText,
            ),
            const SizedBox(height: 12),
            Text(
              searching ? 'No encontramos clientes' : 'Todavía no hay clientes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              searching
                  ? 'Probá con otro nombre, CUIT o teléfono.'
                  : 'Cargá el primer cliente para armar pedidos.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}
