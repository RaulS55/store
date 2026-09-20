import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/lot.dart';
import '../../theme/tokens.dart';
import '../customers/customer_sheets.dart';

Future<Lot?> showLotForm(BuildContext context, {Lot? lot}) {
  return showWhiteSheet<Lot>(
    context: context,
    builder: (context) => _LotFormSheet(lot: lot),
  );
}

class _LotFormSheet extends StatefulWidget {
  const _LotFormSheet({this.lot});

  final Lot? lot;

  @override
  State<_LotFormSheet> createState() => _LotFormSheetState();
}

class _LotFormSheetState extends State<_LotFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _cost;
  late final TextEditingController _quantity;
  late final TextEditingController _unitCost;
  late final TextEditingController _soldElsewhere;
  var _saving = false;
  var _syncing = false;

  @override
  void initState() {
    super.initState();
    final lot = widget.lot;
    _name = TextEditingController(text: lot?.name ?? '');
    _cost = TextEditingController(
      text: lot == null ? '' : lot.cost.round().toString(),
    );
    _quantity = TextEditingController(
      text: lot?.quantity == null ? '' : '${lot!.quantity}',
    );
    final unit = lot?.derivedUnitCost;
    _unitCost = TextEditingController(
      text: unit == null ? '' : unit.round().toString(),
    );
    _soldElsewhere = TextEditingController(
      text: lot == null || lot.soldElsewhere <= 0
          ? ''
          : lot.soldElsewhere.round().toString(),
    );
    _cost.addListener(_onCostChanged);
    _quantity.addListener(_onQuantityChanged);
    _unitCost.addListener(_onUnitChanged);
  }

  @override
  void dispose() {
    _cost.removeListener(_onCostChanged);
    _quantity.removeListener(_onQuantityChanged);
    _unitCost.removeListener(_onUnitChanged);
    _name.dispose();
    _cost.dispose();
    _quantity.dispose();
    _unitCost.dispose();
    _soldElsewhere.dispose();
    super.dispose();
  }

  bool get _hasQuantity {
    final qty = int.tryParse(_quantity.text.trim());
    return qty != null && qty > 0;
  }

  double? _parseMoney(String raw) {
    final digits = raw.trim();
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  void _setText(TextEditingController controller, String value) {
    _syncing = true;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _syncing = false;
  }

  void _onQuantityChanged() {
    if (_syncing) return;
    setState(() {});
    final qty = int.tryParse(_quantity.text.trim());
    if (qty == null || qty <= 0) return;
    final unit = _parseMoney(_unitCost.text);
    if (unit != null) {
      _setText(_cost, (unit * qty).round().toString());
      return;
    }
    final cost = _parseMoney(_cost.text);
    if (cost != null) {
      _setText(_unitCost, (cost / qty).round().toString());
    }
  }

  void _onCostChanged() {
    if (_syncing) return;
    setState(() {});
    final qty = int.tryParse(_quantity.text.trim());
    final cost = _parseMoney(_cost.text);
    if (qty == null || qty <= 0 || cost == null) return;
    _setText(_unitCost, (cost / qty).round().toString());
  }

  void _onUnitChanged() {
    if (_syncing) return;
    final qty = int.tryParse(_quantity.text.trim());
    final unit = _parseMoney(_unitCost.text);
    if (qty == null || qty <= 0 || unit == null) return;
    _setText(_cost, (unit * qty).round().toString());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.lot != null;
    final canSave = _parseMoney(_cost.text) != null && !_saving;
    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Editar montón' : 'Nuevo montón',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'El precio de costo es obligatorio. La cantidad habilita el precio unitario.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('lot-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre (opcional)',
                hintText: 'Ej. Lote feria marzo',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('lot-cost'),
              controller: _cost,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Precio de costo',
                hintText: 'Ej. 150000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('lot-quantity'),
              controller: _quantity,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cantidad (opcional)',
                hintText: 'Unidades del montón',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('lot-unit-cost'),
              controller: _unitCost,
              enabled: _hasQuantity,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Precio unitario (opcional)',
                hintText: 'Si cargás cantidad',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('lot-sold-elsewhere'),
              controller: _soldElsewhere,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Vendido por otro medio (opcional)',
                hintText: 'Plata ya cobrada afuera',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('save-lot'),
              onPressed: canSave ? _save : null,
              child: const Text('Guardar montón'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final cost = _parseMoney(_cost.text);
    if (cost == null || cost <= 0 || _saving) return;
    setState(() => _saving = true);
    final store = context.read<AppStore>();
    final existing = widget.lot;
    final qty = int.tryParse(_quantity.text.trim());
    final quantity = qty != null && qty > 0 ? qty : null;
    final unit = quantity == null ? null : _parseMoney(_unitCost.text);
    try {
      final now = DateTime.now().toUtc();
      final lot = Lot(
        id: existing?.id ?? store.nextLotId(),
        name: _name.text.trim(),
        cost: cost,
        quantity: quantity,
        unitCost: unit,
        soldElsewhere: _parseMoney(_soldElsewhere.text) ?? 0,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        deletedAt: existing?.deletedAt,
      );
      await store.upsertLot(lot);
      if (!mounted) return;
      Navigator.pop(context, store.lotById(lot.id) ?? lot);
    } catch (error, stack) {
      debugPrint('Lot save failed: $error');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el montón.')),
      );
    }
  }
}
