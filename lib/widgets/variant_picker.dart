import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/tokens.dart';

class VariantSelection {
  const VariantSelection({this.size, this.color});

  final String? size;
  final String? color;

  VariantSelection copyWith({String? size, String? color}) {
    return VariantSelection(
      size: size ?? this.size,
      color: color ?? this.color,
    );
  }
}

class VariantPicker extends StatelessWidget {
  const VariantPicker({
    super.key,
    required this.product,
    required this.selection,
    required this.onChanged,
  });

  final Product product;
  final VariantSelection selection;
  final ValueChanged<VariantSelection> onChanged;

  ProductVariant? get selected =>
      product.variantFor(selection.size, selection.color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegí variante',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text('Talle', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final size in product.sizes)
              _SizeChip(
                label: size,
                stock: product.stockForSize(size, colorName: selection.color),
                selected: selection.size == size,
                onTap: () => onChanged(selection.copyWith(size: size)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Color', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            for (final color in product.colors)
              _ColorChoice(
                color: color,
                stock: product.stockForColor(color.name, size: selection.size),
                selected: selection.color == color.name,
                onTap: () => onChanged(selection.copyWith(color: color.name)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _StockLine(variant: selected, hasSelection: selected != null),
      ],
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.stock,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int stock;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final out = stock <= 0;
    return ChoiceChip(
      label: Text(
        out ? '$label  ·  0' : label,
        style: TextStyle(
          decoration: out ? TextDecoration.lineThrough : null,
          color: out ? AppColors.mutedText : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected && !out,
      onSelected: out ? null : (_) => onTap(),
      selectedColor: AppColors.terracottaChip,
      side: BorderSide(
        color: selected && !out
            ? AppColors.terracotta
            : Theme.of(context).dividerColor,
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.stock,
    required this.selected,
    required this.onTap,
  });

  final SwatchColor color;
  final int stock;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final out = stock <= 0;
    if (color.isCustom) {
      return ChoiceChip(
        label: Text(
          out ? '${color.name}  ·  0' : color.name,
          style: TextStyle(
            decoration: out ? TextDecoration.lineThrough : null,
            color: out ? AppColors.mutedText : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        selected: selected && !out,
        onSelected: out ? null : (_) => onTap(),
        selectedColor: AppColors.terracottaChip,
        side: BorderSide(
          color: selected && !out
              ? AppColors.terracotta
              : Theme.of(context).dividerColor,
        ),
      );
    }
    return InkWell(
      onTap: out ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.terracotta : const Color(0x33000000),
                      width: selected ? 2 : 1,
                    ),
                  ),
                ),
                if (out)
                  const Icon(Icons.close, size: 16, color: AppColors.stockLow)
                else if (selected)
                  Icon(
                    Icons.check,
                    size: 16,
                    color: color.color.computeLuminance() > 0.6
                        ? AppColors.charcoal
                        : Colors.white,
                  ),
                if (!out)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Text(
                        '$stock',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              color.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(
              out ? 'sin stock' : '$stock u.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: out ? AppColors.stockLow : AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockLine extends StatelessWidget {
  const _StockLine({required this.variant, required this.hasSelection});

  final ProductVariant? variant;
  final bool hasSelection;

  @override
  Widget build(BuildContext context) {
    final available = variant != null && variant!.stock > 0;
    return Row(
      children: [
        Icon(
          Icons.inventory_2_outlined,
          size: 18,
          color: available ? AppColors.stockOk : AppColors.mutedText,
        ),
        const SizedBox(width: 8),
        Text(
          !hasSelection
              ? 'Elegí talle y color para ver el stock'
              : available
                  ? 'Stock disponible: ${variant!.stock} u.'
                  : 'Sin stock en esta combinación',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: available ? null : AppColors.slate,
          ),
        ),
      ],
    );
  }
}

Future<ProductVariant?> showVariantPickerSheet(
  BuildContext context,
  Product product,
) {
  var selection = VariantSelection(
    size: product.sizes.length == 1 ? product.sizes.first : null,
    color: product.colors.length == 1 ? product.colors.first.name : null,
  );
  return showModalBottomSheet<ProductVariant>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: StatefulBuilder(
          builder: (context, setState) {
            final variant = product.variantFor(selection.size, selection.color);
            final canAdd = variant != null && variant.stock > 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                VariantPicker(
                  product: product,
                  selection: selection,
                  onChanged: (next) => setState(() => selection = next),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: canAdd ? () => Navigator.pop(context, variant) : null,
                  child: const Text('Agregar al pedido'),
                ),
                if (!canAdd)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Si no hay selección, el botón se desactiva.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    },
  );
}
