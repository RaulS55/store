import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/tokens.dart';

class VariantSelection {
  const VariantSelection({this.picks = const {}});

  /// Color → talles marcados. Varios colores pueden convivir.
  final Map<String, Set<String>> picks;

  bool get hasSizes => picks.values.any((sizes) => sizes.isNotEmpty);

  Set<String> sizesOf(String color) => picks[color] ?? const {};

  bool isSelected(String color, String size) =>
      picks[color]?.contains(size) ?? false;

  static VariantSelection effective(
    Product product,
    VariantSelection selection,
  ) {
    final kept = <String, Set<String>>{};
    for (final color in product.colors) {
      final requested = selection.picks[color.name];
      if (requested == null || requested.isEmpty) continue;
      final available = product.sizesForColor(color.name);
      final sizes = <String>{
        for (final size in requested)
          if (available.contains(size) &&
              (product.variantFor(size, color.name)?.stock ?? 0) > 0)
            size,
      };
      if (sizes.isNotEmpty) kept[color.name] = sizes;
    }
    if (kept.isNotEmpty) return VariantSelection(picks: kept);
    if (product.colors.length == 1) {
      final color = product.colors.first.name;
      final available = [
        for (final size in product.sizesForColor(color))
          if ((product.variantFor(size, color)?.stock ?? 0) > 0) size,
      ];
      if (available.length == 1) {
        return VariantSelection(
          picks: {
            color: {available.first},
          },
        );
      }
    }
    return const VariantSelection();
  }

  /// Marca todos los talles con stock de [colorName], o los saca si ya
  /// estaban todos. No toca los demás colores.
  VariantSelection selectColor(Product product, String colorName) {
    final available = [
      for (final size in product.sizesForColor(colorName))
        if ((product.variantFor(size, colorName)?.stock ?? 0) > 0) size,
    ];
    if (available.isEmpty) return this;
    final current = picks[colorName] ?? const <String>{};
    final allSelected = available.every(current.contains);
    final next = <String, Set<String>>{
      for (final entry in picks.entries)
        if (entry.key != colorName && entry.value.isNotEmpty)
          entry.key: {...entry.value},
    };
    if (!allSelected) next[colorName] = available.toSet();
    return VariantSelection(picks: next);
  }

  VariantSelection selectSize(Product product, String colorName, String size) {
    final variant = product.variantFor(size, colorName);
    if (variant == null || variant.stock <= 0) return this;
    final next = <String, Set<String>>{
      for (final entry in picks.entries) entry.key: {...entry.value},
    };
    final sizes = next.putIfAbsent(colorName, () => <String>{});
    if (!sizes.add(size)) {
      sizes.remove(size);
      if (sizes.isEmpty) next.remove(colorName);
    }
    return VariantSelection(picks: next);
  }

  List<ProductVariant> selectedVariants(Product product) {
    return [
      for (final color in _colorsBySwatch(product))
        for (final size in product.sizesForColor(color.name))
          if (isSelected(color.name, size))
            product.variantFor(size, color.name),
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
          'Podés mezclar colores y talles. El número de cada talle es lo que queda.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 12),
        for (final color in _colorsBySwatch(product)) ...[
          _ColorGroup(
            color: color,
            stock: product.stockForColor(color.name),
            selected: selection.sizesOf(color.name).isNotEmpty,
            sizes: product.sizesForColor(color.name),
            selectedSizes: selection.sizesOf(color.name),
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
        _StockLine(variants: variants, hasSizes: selection.hasSizes),
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
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              decoration: out ? TextDecoration.lineThrough : null,
              color: out ? AppColors.mutedText : null,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!out) ...[
            const SizedBox(width: 6),
            Text(
              stock > 10 ? '+9u' : '${stock}u',
              style: const TextStyle(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: out
                        ? AppColors.stockLow
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
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
  const _StockLine({required this.variants, required this.hasSizes});

  final List<ProductVariant> variants;
  final bool hasSizes;

  @override
  Widget build(BuildContext context) {
    final available = variants.isNotEmpty;
    final minStock = available
        ? variants
              .map((variant) => variant.stock)
              .reduce((a, b) => a < b ? a : b)
        : 0;
    final colorCount = variants.map((variant) => variant.color).toSet().length;
    final message = !hasSizes
        ? 'Elegí uno o más talles'
        : !available
        ? 'Esos talles no tienen stock'
        : variants.length == 1
        ? '${variants.first.size} ${variants.first.color}: ${variants.first.stock} u.'
        : colorCount == 1
        ? '${variants.length} talles · stock mínimo: $minStock u.'
        : '${variants.length} variantes · stock mínimo: $minStock u.';
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
