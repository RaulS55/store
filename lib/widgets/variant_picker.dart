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

  VariantSelection selectSize(Product product, String colorName, String size) {
    if (color == colorName) return toggleSize(size);
    final variant = product.variantFor(size, colorName);
    if (variant == null || variant.stock <= 0) {
      return selectColor(product, colorName);
    }
    return VariantSelection(color: colorName, sizes: {size});
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
        const SizedBox(height: 4),
        Text(
          'Los talles se agrupan por color. Podés elegir varios del mismo.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 12),
        for (final color in _colorsBySwatch(product)) ...[
          _ColorGroup(
            color: color,
            stock: product.stockForColor(color.name),
            selected: selection.color == color.name,
            sizes: product.sizesForColor(color.name),
            selectedSizes: selection.color == color.name
                ? selection.sizes
                : const {},
            sizeLabel: (size) => _sizeChipLabel(product, size),
            stockForSize: (size) =>
                product.stockForSize(size, colorName: color.name),
            onTapColor: () =>
                onChanged(selection.selectColor(product, color.name)),
            onToggleSize: (size) =>
                onChanged(selection.selectSize(product, color.name, size)),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        _StockLine(
          variants: variants,
          hasColor: selection.hasColor,
          hasSizes: selection.hasSizes,
        ),
      ],
    );
  }
}

List<SwatchColor> _colorsBySwatch(Product product) {
  final index = {
    for (var i = 0; i < Swatches.all.length; i++) Swatches.all[i].name: i,
  };
  return [...product.colors]..sort((a, b) {
    final ia = index[a.name] ?? 1000;
    final ib = index[b.name] ?? 1000;
    if (ia != ib) return ia.compareTo(ib);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    super.key,
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

class _ColorGroup extends StatelessWidget {
  const _ColorGroup({
    required this.color,
    required this.stock,
    required this.selected,
    required this.sizes,
    required this.selectedSizes,
    required this.sizeLabel,
    required this.stockForSize,
    required this.onTapColor,
    required this.onToggleSize,
  });

  final SwatchColor color;
  final int stock;
  final bool selected;
  final List<String> sizes;
  final Set<String> selectedSizes;
  final String Function(String size) sizeLabel;
  final int Function(String size) stockForSize;
  final VoidCallback onTapColor;
  final ValueChanged<String> onToggleSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final out = stock <= 0;
    return Container(
      key: ValueKey('variant-color-${color.name}'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: selected && !out ? AppColors.terracotta : theme.dividerColor,
          width: selected && !out ? 2 : 1,
        ),
        color: selected && !out ? AppColors.terracottaChip : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: out ? null : onTapColor,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Row(
              children: [
                if (!color.isCustom) ...[
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: color.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AppColors.terracotta
                            : const Color(0x33000000),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    color.name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: out ? TextDecoration.lineThrough : null,
                      color: out ? AppColors.mutedText : null,
                    ),
                  ),
                ),
                Text(
                  out ? 'sin stock' : '$stock u.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: out ? AppColors.stockLow : AppColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final size in sizes)
                _SizeChip(
                  key: ValueKey('variant-size-${color.name}-$size'),
                  label: sizeLabel(size),
                  stock: stockForSize(size),
                  selected: selectedSizes.contains(size),
                  locked: false,
                  onTap: () => onToggleSize(size),
                ),
            ],
          ),
        ],
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
        ? 'Elegí los talles de un color'
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
            return SingleChildScrollView(
              child: Column(
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
                            ? 'Elegí los talles de un color.'
                            : 'Elegí uno o más talles.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
