import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
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
          const _IvaSettings(),
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

class _IvaSettings extends StatefulWidget {
  const _IvaSettings();

  @override
  State<_IvaSettings> createState() => _IvaSettingsState();
}

class _IvaSettingsState extends State<_IvaSettings> {
  late final TextEditingController _percent;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _percent = TextEditingController(text: PercentFormat.of(store.ivaPercent));
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _percent.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      _commitPercent();
    }
  }

  void _commitPercent() {
    final store = context.read<AppStore>();
    final parsed = PercentFormat.tryParse(_percent.text);
    if (parsed == null) {
      _percent.text = PercentFormat.of(store.ivaPercent);
      return;
    }
    store.setIvaPercent(parsed);
    _percent.text = PercentFormat.of(store.ivaPercent);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Column(
      children: [
        SwitchListTile(
          value: store.ivaEnabled,
          onChanged: store.setIvaEnabled,
          title: const Text('IVA'),
          subtitle: Text(
            store.ivaEnabled
                ? '${PercentFormat.of(store.ivaPercent)}% sobre el subtotal del pedido'
                : 'Desactivado. El total es el subtotal.',
          ),
          activeTrackColor: AppColors.terracotta,
        ),
        if (store.ivaEnabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _percent,
              focusNode: _focus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Porcentaje de IVA',
                suffixText: '%',
              ),
              onSubmitted: (_) => _commitPercent(),
            ),
          ),
      ],
    );
  }
}
