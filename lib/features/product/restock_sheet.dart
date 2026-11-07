import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/lot.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/qty_stepper.dart';
import '../customers/customer_sheets.dart';

Future<void> showRestockSheet(BuildContext context, String productId) {
  return showWhiteSheet<void>(
    context: context,
    builder: (context) => _RestockSheet(productId: productId),
  );
}

class _RestockSheet extends StatefulWidget {
  const _RestockSheet({required this.productId});

  final String productId;

  @override
  State<_RestockSheet> createState() => _RestockSheetState();
}

class _RestockSheetState extends State<_RestockSheet> {
  final _adds = <String, int>{};
  String _lotQuery = '';
  String? _error;
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final product = store.productById(widget.productId);
    if (product == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No encontramos esta prenda.'),
      );
    }
    final variants = [...product.variants]..sort(ProductVariant.compare);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Reponer stock',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Las unidades que sumes entran en el lote elegido. El stock anterior sigue en su lote.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            Text('Lote', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Autocomplete<Lot>(
              displayStringForOption: (lot) => lot.displayName,
              optionsBuilder: (value) => store.lotSuggestions(value.text),
              onSelected: (lot) => _lotQuery = lot.displayName,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      key: const ValueKey('restock-lot'),
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Ej. Lote feria',
                      ),
                      onChanged: (value) => _lotQuery = value,
                      onFieldSubmitted: (_) => onFieldSubmitted(),
                    );
                  },
            ),
            const SizedBox(height: 16),
            for (final variant in variants) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${variant.size} · ${variant.color}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${variant.stock} en stock',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                  QtyStepper(
                    value: _adds[variant.key] ?? 0,
                    min: 0,
                    max: 999,
                    onChanged: (value) {
                      setState(() => _adds[variant.key] = value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.stockLow)),
              const SizedBox(height: 12),
            ],
            FilledButton(
              key: const ValueKey('confirm-restock'),
              onPressed: _saving ? null : () => _save(store, product),
              child: Text(_saving ? 'Guardando…' : 'Reponer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(AppStore store, Product product) async {
    final lot = store.resolveLot(_lotQuery);
    if (lot == null) {
      setState(() => _error = 'Elegí un lote de la lista');
      return;
    }
    final quantities = {
      for (final entry in _adds.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    if (quantities.isEmpty) {
      setState(() => _error = 'Indicá cuántas unidades sumar');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await store.restockProduct(
      productId: product.id,
      lotId: lot.id,
      quantities: quantities,
    );
    if (!mounted) return;
    if (!saved) {
      setState(() {
        _saving = false;
        _error = 'No se pudo reponer el stock.';
      });
      return;
    }
    Navigator.of(context).pop();
    AppSnackBar.show(context, content: const Text('Stock repuesto'));
  }
}
