import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../theme/tokens.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            'Configuración',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            value: store.themeMode == ThemeMode.dark,
            onChanged: (_) => store.toggleTheme(),
            title: const Text('Modo oscuro'),
            subtitle: const Text('Mismas superficies y acento terracota'),
            activeTrackColor: AppColors.terracotta,
          ),
          const Divider(),
          const ListTile(
            title: Text('IVA'),
            subtitle: Text('21% sobre el subtotal del pedido'),
          ),
          const ListTile(
            title: Text('Moneda'),
            subtitle: Text('Pesos argentinos (ARS)'),
          ),
          const ListTile(
            title: Text('Datos'),
            subtitle: Text('Catálogo y pedidos viven en memoria local'),
          ),
        ],
      ),
    );
  }
}
