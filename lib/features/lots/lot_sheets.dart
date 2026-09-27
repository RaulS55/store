import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../models/lot.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_snack_bar.dart';
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
  late DateTime _date;
  var _saving = false;
  var _syncing = false;

  @override
  void initState() {
    super.initState();
    final lot = widget.lot;
    _name = TextEditingController(text: lot?.name ?? '');
    _cost = TextEditingController(
      text: lot == null ? '' : MoneyFormat.grouped(lot.cost),
    );
    _quantity = TextEditingController(
      text: lot?.quantity == null ? '' : '${lot!.quantity}',
    );
    _unitCost = TextEditingController(
      text: _unitFrom(lot?.cost, lot?.quantity),
    );
    _soldElsewhere = TextEditingController(
      text: lot == null || lot.soldElsewhere <= 0
          ? ''
          : MoneyFormat.grouped(lot.soldElsewhere),
    );
    final today = DateTime.now();
    _date = lot?.calendarDate ?? DateTime(today.year, today.month, today.day);
    _cost.addListener(_recalculateUnit);
    _quantity.addListener(_recalculateUnit);
  }

  @override
  void dispose() {
    _cost.removeListener(_recalculateUnit);
    _quantity.removeListener(_recalculateUnit);
    _name.dispose();
    _cost.dispose();
    _quantity.dispose();
    _unitCost.dispose();
    _soldElsewhere.dispose();
    super.dispose();
  }

  double? _parseMoney(String raw) => MoneyFormat.parse(raw);

  String _unitFrom(double? cost, int? quantity) {
    if (cost == null || quantity == null || quantity <= 0) return '';
    return MoneyFormat.grouped(cost / quantity);
  }

  void _setText(TextEditingController controller, String value) {
    _syncing = true;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _syncing = false;
  }

  void _recalculateUnit() {
    if (_syncing) return;
    setState(() {});
    final qty = int.tryParse(_quantity.text.trim());
    final cost = _parseMoney(_cost.text);
    final next = _unitFrom(cost, qty != null && qty > 0 ? qty : null);
    if (_unitCost.text != next) _setText(_unitCost, next);
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
              editing ? 'Editar lote' : 'Nuevo lote',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'El precio de lote es obligatorio. El precio unitario se calcula solo.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
            const SizedBox(height: 16),
            InkWell(
              key: const ValueKey('lot-date'),
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(formatLotDay(_date)),
              ),
            ),
            const SizedBox(height: 12),
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
              inputFormatters: [MoneyFormat.inputFormatter],
              decoration: const InputDecoration(
                labelText: 'Precio de lote',
                hintText: 'Ej. 150.000',
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
                hintText: 'Unidades del lote',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('lot-unit-cost'),
              controller: _unitCost,
              readOnly: true,
              enableInteractiveSelection: false,
              decoration: const InputDecoration(
                labelText: 'Precio unitario',
                hintText: 'Precio de lote / cantidad',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('lot-sold-elsewhere'),
              controller: _soldElsewhere,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyFormat.inputFormatter],
              decoration: const InputDecoration(
                labelText: 'Vendido por otro medio (opcional)',
                hintText: 'Plata ya cobrada afuera',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('save-lot'),
              onPressed: canSave ? _save : null,
              child: const Text('Guardar lote'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
      helpText: 'Fecha del lote',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _save() async {
    final cost = _parseMoney(_cost.text);
    if (cost == null || cost <= 0 || _saving) return;
    setState(() => _saving = true);
    final store = context.read<AppStore>();
    final existing = widget.lot;
    final qty = int.tryParse(_quantity.text.trim());
    final quantity = qty != null && qty > 0 ? qty : null;
    final unit = quantity == null ? null : cost / quantity;
    try {
      final now = DateTime.now().toUtc();
      final lot = Lot(
        id: existing?.id ?? store.nextLotId(),
        name: _name.text.trim(),
        cost: cost,
        quantity: quantity,
        unitCost: unit,
        soldElsewhere: _parseMoney(_soldElsewhere.text) ?? 0,
        date: DateTime.utc(_date.year, _date.month, _date.day),
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
        const AppSnackBar(content: Text('No se pudo guardar el lote.')),
      );
    }
  }
}
