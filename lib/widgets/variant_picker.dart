import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/tokens.dart';

class VariantSelection {
  const VariantSelection({this.sizes = const {}, this.color});

  final Set<String> sizes;
  final String? color;

  bool get hasColor => color != null;

  bool get hasSizes => sizes.isNotEmpty;

  VariantSelection copyWith({Set<String>? sizes, String? color}) {
    return VariantSelection(
      sizes: sizes ?? this.sizes,
      color: color ?? this.color,
    );
  }

  VariantSelection toggleSize(String size) {
    final next = {...sizes};
    if (!next.add(size)) next.remove(size);
    return copyWith(sizes: next);
  }

  static VariantSelection effective(
    Product product,
    VariantSelection selection,
  ) {
    final color =
        selection.color ??
        (product.colors.length == 1 ? product.colors.first.name : null);
    final available = product.sizesForColor(color);
    final requested = selection.sizes.isNotEmpty
        ? selection.sizes
        : (available.length == 1 ? {available.first} : const <String>{});
    return VariantSelection(
      color: color,
      sizes: {
        for (final size in requested)
          if (available.contains(size) &&
              (product.variantFor(size, color)?.stock ?? 0) > 0)
            size,
      },
    );
  }

  VariantSelection selectColor(Product product, String colorName) {
    final available = product.sizesForColor(colorName);
    return VariantSelection(
      color: colorName,
      sizes: {
        for (final size in sizes)
          if (available.contains(size) &&
              (product.variantFor(size, colorName)?.stock ?? 0) > 0)
            size,
      },
    );
  }

  List<ProductVariant> selectedVariants(Product product) {
    if (color == null) return const [];
    return [
      for (final size in product.sizes)
        if (sizes.contains(size)) product.variantFor(size, color),
    ].whereType<ProductVariant>().toList();
  }

  List<ProductVariant> addableVariants(Product product) {
    return [
      for (final variant in selectedVariants(product))
        if (variant.stock > 0) variant,
    ];
  }

  int quantityCap(Product product) {
    final variants = addableVariants(product);
    if (variants.isEmpty) return 1;
    return variants
        .map((variant) => variant.stock)
        .reduce((a, b) => a < b ? a : b);
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

  String _sizeChipLabel(Product product, String size) {
    final equivalent = product.equivalentSizeFor(size);
    if (equivalent == size) return size;
    return '$size · $equivalent';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variants = selection.addableVariants(product);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elegí color y talles',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text('Color', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            for (final color in product.colors)
              _ColorChoice(
                color: color,
                stock: product.stockForColor(color.name),
                selected: selection.color == color.name,
                onTap: () =>
                    onChanged(selection.selectColor(product, color.name)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Talle en prenda', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          'Podés elegir varios talles del mismo color.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final size
                in selection.hasColor
                    ? product.sizesForColor(selection.color)
                    : product.sizes)
              _SizeChip(
                label: _sizeChipLabel(product, size),
                stock: product.stockForSize(size, colorName: selection.color),
                selected: selection.sizes.contains(size),
                locked: !selection.hasColor,
                onTap: () => onChanged(selection.toggleSize(size)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _StockLine(
          variants: variants,
          hasColor: selection.hasColor,
          hasSizes: selection.hasSizes,
        ),
      ],
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.stock,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final int stock;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final out = !locked && stock <= 0;
    if (locked) {
      return Chip(
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        side: BorderSide(color: Theme.of(context).dividerColor),
        backgroundColor: Theme.of(context).colorScheme.surface,
      );
    }
    return FilterChip(
      label: Text(
        out ? '$label  ·  0' : label,
        style: TextStyle(
          decoration: out ? TextDecoration.lineThrough : null,
          color: out ? AppColors.mutedText : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: selected && !out,
      showCheckmark: false,
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
                      color: selected
                          ? AppColors.terracotta
                          : const Color(0x33000000),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
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
  const _StockLine({
    required this.variants,
    required this.hasColor,
    required this.hasSizes,
  });

  final List<ProductVariant> variants;
  final bool hasColor;
  final bool hasSizes;

  @override
  Widget build(BuildContext context) {
    final available = variants.isNotEmpty;
    final message = !hasColor
        ? 'Elegí un color para ver los talles'
        : !hasSizes
        ? 'Elegí uno o más talles'
        : !available
        ? 'Esos talles no tienen stock en este color'
        : variants.length == 1
        ? 'Stock disponible: ${variants.first.stock} u.'
        : '${variants.length} talles · stock mínimo: ${variants.map((v) => v.stock).reduce((a, b) => a < b ? a : b)} u.';
    return Row(
      children: [
        Icon(
          Icons.inventory_2_outlined,
          size: 18,
          color: available ? AppColors.stockOk : AppColors.mutedText,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: available ? null : AppColors.slate,
            ),
          ),
        ),
      ],
    );
  }
}

Future<List<ProductVariant>?> showVariantPickerSheet(
  BuildContext context,
  Product product,
) {
  var selection = VariantSelection.effective(product, const VariantSelection());
  return showModalBottomSheet<List<ProductVariant>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: StatefulBuilder(
          builder: (context, setState) {
            final variants = selection.addableVariants(product);
            final canAdd = variants.isNotEmpty;
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
                  onPressed: canAdd
                      ? () => Navigator.pop(context, variants)
                      : null,
                  child: Text(
                    variants.length > 1
                        ? 'Agregar ${variants.length} al pedido'
                        : 'Agregar al pedido',
                  ),
                ),
                if (!canAdd)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      product.stock <= 0
                          ? 'No hay stock disponible.'
                          : !selection.hasColor
                          ? 'Elegí un color para ver los talles.'
                          : 'Elegí uno o más talles.',
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
