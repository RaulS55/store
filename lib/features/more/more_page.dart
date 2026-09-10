import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/tokens.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            'Más',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: store.themeMode == ThemeMode.dark,
            onChanged: (_) => store.toggleTheme(),
            title: const Text('Modo oscuro'),
            subtitle: Text(
              store.themeMode == ThemeMode.dark ? 'Activado' : 'Desactivado',
            ),
            activeTrackColor: AppColors.terracotta,
          ),
          ListTile(
            leading: const Icon(Icons.people_alt_outlined),
            title: const Text('Clientes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/clientes'),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Configuración'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/config'),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Pedidos cerrados'),
            subtitle: Text(
              store.closedOrders.isEmpty
                  ? 'Todavía no hay pedidos cerrados en esta sesión'
                  : '${store.closedOrders.length} en esta sesión',
            ),
          ),
          if (store.closedOrders.isNotEmpty)
            for (final order in store.closedOrders)
              ListTile(
                dense: true,
                title: Text(order.orderNumber),
                subtitle: Text(order.customer.name),
                onTap: () => context.go('/pedido/${order.id}'),
              ),
        ],
      ),
    );
  }
}
