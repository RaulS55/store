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

typedef CustomerPickerConfirm =
    Future<bool> Function(BuildContext context, Customer customer);

Future<Customer?> showCustomerPicker(
  BuildContext context, {
  Set<String> blockedCustomerIds = const {},
  CustomerPickerConfirm? confirmCustomer,
}) {
  return showWhiteSheet<Customer>(
    context: context,
    builder: (context) => _CustomerPickerSheet(
      blockedCustomerIds: blockedCustomerIds,
      confirmCustomer: confirmCustomer,
    ),
  );
}

Future<Customer?> showCustomerForm(BuildContext context, {Customer? customer}) {
  return showWhiteSheet<Customer>(
    context: context,
    builder: (context) => _CustomerFormSheet(customer: customer),
  );
}

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet({
    this.blockedCustomerIds = const {},
    this.confirmCustomer,
  });

  final Set<String> blockedCustomerIds;
  final CustomerPickerConfirm? confirmCustomer;

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _name = TextEditingController();
  var _saving = false;
  var _confirming = false;

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
    final canCreate = _name.text.trim().isNotEmpty && !_saving;

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
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
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
                        enabled: !widget.blockedCustomerIds.contains(
                          customer.id,
                        ),
                        title: Text(customer.name),
                        subtitle: _pickerSubtitle(store, customer) == null
                            ? null
                            : Text(_pickerSubtitle(store, customer)!),
                        onTap: widget.blockedCustomerIds.contains(customer.id)
                            ? null
                            : () => _select(customer),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _pickerSubtitle(AppStore store, Customer customer) {
    final lines = <String>[
      if (customer.detailSubtitle != null) customer.detailSubtitle!,
      if (store.openOrderForCustomer(customer.id) != null) 'Pedido abierto',
    ];
    if (lines.isEmpty) return null;
    return lines.join(' · ');
  }

  Future<void> _select(Customer customer) async {
    if (_confirming) return;
    final confirm = widget.confirmCustomer;
    if (confirm != null) {
      _confirming = true;
      final ok = await confirm(context, customer);
      if (!mounted) return;
      _confirming = false;
      if (!ok) return;
    }
    Navigator.pop(context, customer);
  }

  Future<void> _create(AppStore store) async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving || _confirming) return;
    setState(() => _saving = true);
    try {
      final customer = await store.addCustomer(name: name);
      if (!mounted) return;
      await _select(customer);
      if (mounted) setState(() => _saving = false);
    } catch (error, stack) {
      debugPrint('Customer create failed: $error');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el cliente.')),
      );
    }
  }
}

class _CustomerFormSheet extends StatefulWidget {
  const _CustomerFormSheet({this.customer});

  final Customer? customer;

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _cuit;
  late final TextEditingController _address;
  TaxCondition? _tax;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _name = TextEditingController(text: customer?.name ?? '');
    _phone = TextEditingController(text: customer?.phone ?? '');
    _cuit = TextEditingController(text: customer?.cuit ?? '');
    _address = TextEditingController(text: customer?.address ?? '');
    _tax = customer?.taxCondition;
  }

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
    final editing = widget.customer != null;
    final canSave = _name.text.trim().isNotEmpty && !_saving;
    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Editar cliente' : 'Nuevo cliente',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'El nombre es el único dato obligatorio.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('customer-name'),
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
              decoration: const InputDecoration(labelText: 'CUIT (opcional)'),
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
                  items: [
                    const DropdownMenuItem<TaxCondition?>(
                      value: null,
                      child: Text('Sin especificar'),
                    ),
                    for (final value in TaxCondition.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
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
              key: const ValueKey('save-customer'),
              onPressed: canSave ? _save : null,
              child: const Text('Guardar cliente'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final store = context.read<AppStore>();
    final existing = widget.customer;
    try {
      final Customer customer;
      if (existing == null) {
        customer = await store.addCustomer(
          name: name,
          phone: _phone.text,
          cuit: _cuit.text,
          taxCondition: _tax,
          address: _address.text,
        );
      } else {
        await store.upsertCustomer(
          Customer(
            id: existing.id,
            name: name,
            phone: _blankToNull(_phone.text),
            cuit: _blankToNull(_cuit.text),
            taxCondition: _tax,
            address: _blankToNull(_address.text),
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
            deletedAt: existing.deletedAt,
          ),
        );
        customer = store.customerById(existing.id) ?? existing;
      }
      if (!mounted) return;
      Navigator.pop(context, customer);
    } catch (error, stack) {
      debugPrint('Customer save failed: $error');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el cliente.')),
      );
    }
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
