import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

Future<T?> showWhiteSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (context) {
      return Theme(
        data: AppTheme.light(),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: builder(context),
        ),
      );
    },
  );
}

Future<Customer?> showCustomerPicker(BuildContext context) {
  return showWhiteSheet<Customer>(
    context: context,
    builder: (context) => const _CustomerPickerSheet(),
  );
}

Future<Customer?> showCustomerForm(BuildContext context) {
  return showWhiteSheet<Customer>(
    context: context,
    builder: (context) => const _CustomerFormSheet(),
  );
}

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet();

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final query = _name.text.trim().toLowerCase();
    final hits = store.customers.where((customer) {
      if (query.isEmpty) return true;
      return customer.name.toLowerCase().contains(query);
    }).toList();
    final canCreate = _name.text.trim().isNotEmpty;

    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Nuevo pedido',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Elegí un cliente o escribí un nombre para crear uno nuevo.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _create(store),
                    decoration: const InputDecoration(
                      hintText: 'Nombre del cliente',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: canCreate ? () => _create(store) : null,
                    child: const Text('Crear pedido'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  const ListTile(title: Text('Clientes guardados')),
                  if (hits.isEmpty)
                    const ListTile(
                      title: Text('No hay clientes con ese nombre'),
                    )
                  else
                    for (final customer in hits)
                      ListTile(
                        title: Text(customer.name),
                        subtitle: customer.detailSubtitle == null
                            ? null
                            : Text(customer.detailSubtitle!),
                        onTap: () => Navigator.pop(context, customer),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _create(AppStore store) {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final customer = store.addCustomer(name: name);
    Navigator.pop(context, customer);
  }
}

class _CustomerFormSheet extends StatefulWidget {
  const _CustomerFormSheet();

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _cuit = TextEditingController();
  final _address = TextEditingController();
  TaxCondition? _tax;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _cuit.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _name.text.trim().isNotEmpty;
    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nuevo cliente',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'El nombre es el único dato obligatorio.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.slate,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Nombre del cliente',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp (opcional)',
                hintText: '+54 9 11 0000-0000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cuit,
              decoration: const InputDecoration(
                labelText: 'CUIT (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Condición fiscal (opcional)',
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<TaxCondition?>(
                  value: _tax,
                  isExpanded: true,
                  hint: const Text('Sin especificar'),
                  items: [
                    for (final value in TaxCondition.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                  ],
                  onChanged: (value) => setState(() => _tax = value),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Dirección (opcional)',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: canSave ? _save : null,
              child: const Text('Guardar cliente'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final customer = context.read<AppStore>().addCustomer(
      name: name,
      phone: _phone.text,
      cuit: _cuit.text,
      taxCondition: _tax,
      address: _address.text,
    );
    Navigator.pop(context, customer);
  }
}
