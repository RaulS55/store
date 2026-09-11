import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../widgets/qty_stepper.dart';

class VariantDraft {
  VariantDraft({
    List<String>? sizes,
    List<SwatchColor>? colors,
    List<ProductVariant>? variants,
  })  : sizes = List.of(sizes ?? const []),
        colors = List.of(colors ?? const []),
        variants = List.of(variants ?? const []);

  final List<String> sizes;
  final List<SwatchColor> colors;
  List<ProductVariant> variants;

  static const suggestedSizes = [
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'Único',
    '36',
    '38',
    '39',
    '40',
    '41',
    '42',
  ];

  ProductVariant? find(String size, String color) {
    for (final variant in variants) {
      if (variant.size == size && variant.color == color) return variant;
    }
    return null;
  }

  void ensureCell(String size, SwatchColor color, {int stock = 0}) {
    if (find(size, color.name) != null) return;
    variants.add(
      ProductVariant(
        size: size,
        color: color.name,
        colorHex:
            '#${color.hex.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
        stock: stock,
      ),
    );
  }

  void addSize(String size) {
    if (sizes.contains(size)) return;
    sizes.add(size);
    for (final color in colors) {
      ensureCell(size, color);
    }
  }

  void removeSize(String size) {
    sizes.remove(size);
    variants.removeWhere((v) => v.size == size);
  }

  void addColor(SwatchColor color) {
    if (colors.any((c) => c.name == color.name)) return;
    colors.add(color);
    for (final size in sizes) {
      ensureCell(size, color);
    }
  }

  void removeColor(String name) {
    colors.removeWhere((c) => c.name == name);
    variants.removeWhere((v) => v.color == name);
  }

  void setStock(String size, String color, int stock) {
    variants = [
      for (final variant in variants)
        if (variant.size == size && variant.color == color)
          variant.copyWith(stock: stock)
        else
          variant,
    ];
  }

  void setSku(String size, String color, String? skuSuffix) {
    variants = [
      for (final variant in variants)
        if (variant.size == size && variant.color == color)
          variant.copyWith(skuSuffix: skuSuffix)
        else
          variant,
    ];
  }

  void removeVariant(String size, String color) {
    variants.removeWhere((v) => v.size == size && v.color == color);
  }

  void addCombination(String size, SwatchColor color) {
    addSize(size);
    addColor(color);
    ensureCell(size, color);
  }
}

class VariantEditor extends StatelessWidget {
  const VariantEditor({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.wide,
    this.baseSku = '',
  });

  final VariantDraft draft;
  final VoidCallback onChanged;
  final bool wide;
  final String baseSku;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          wide
              ? 'Stock por variante (talle × color)'
              : 'Variantes (talle × color)',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          wide
              ? 'Cada celda es una variante vendible; el pedido guarda talle + color + stock.'
              : 'Agregá talles y colores para generar las combinaciones.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.mutedText,
          ),
        ),
        const SizedBox(height: 14),
        _ChipRow(
          label: wide ? 'Talles activos' : 'Talles',
          child: _SizeChips(draft: draft, onChanged: onChanged),
        ),
        const SizedBox(height: 12),
        _ChipRow(
          label: wide ? 'Colores activos' : 'Colores',
          child: _ColorChips(draft: draft, onChanged: onChanged),
        ),
        const SizedBox(height: 16),
        if (draft.sizes.isEmpty || draft.colors.isEmpty)
          Text(
            'Agregá al menos un talle y un color.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.stockLow,
            ),
          )
        else if (wide)
          _VariantMatrix(draft: draft, onChanged: onChanged)
        else
          _VariantList(
            draft: draft,
            onChanged: onChanged,
            baseSku: baseSku,
          ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SizeChips extends StatelessWidget {
  const _SizeChips({required this.draft, required this.onChanged});
  final VariantDraft draft;
  final VoidCallback onChanged;

  List<String> get _sizes {
    return [
      ...VariantDraft.suggestedSizes,
      for (final size in draft.sizes)
        if (!VariantDraft.suggestedSizes.contains(size)) size,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final size in _sizes)
          FilterChip(
            label: Text(size),
            selected: draft.sizes.contains(size),
            showCheckmark: false,
            selectedColor: AppColors.terracottaChip,
            onSelected: (selected) {
              if (selected) {
                draft.addSize(size);
              } else {
                draft.removeSize(size);
              }
              onChanged();
            },
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 16, color: AppColors.terracotta),
          label: const Text('Talle'),
          onPressed: () => _addCustomSize(context),
        ),
      ],
    );
  }

  Future<void> _addCustomSize(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar talle'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ej. XL / 37 / Único'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
    if (value != null && value.isNotEmpty) {
      draft.addSize(value);
      onChanged();
    }
  }
}

class _ColorChips extends StatelessWidget {
  const _ColorChips({required this.draft, required this.onChanged});
  final VariantDraft draft;
  final VoidCallback onChanged;

  List<SwatchColor> get _colors {
    return [
      ...Swatches.all,
      for (final color in draft.colors)
        if (!Swatches.all.any((item) => item.name == color.name)) color,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final color in _colors)
          _Swatch(
            color: color,
            selected: draft.colors.any((item) => item.name == color.name),
            onTap: () {
              if (draft.colors.any((item) => item.name == color.name)) {
                draft.removeColor(color.name);
              } else {
                draft.addColor(color);
              }
              onChanged();
            },
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final SwatchColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: selected ? 'Quitar ${color.name}' : 'Agregar ${color.name}',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.terracotta : const Color(0x33000000),
              width: selected ? 2 : 1,
            ),
          ),
          child: selected
              ? Icon(
                  Icons.check,
                  size: 14,
                  color: color.color.computeLuminance() > 0.6
                      ? AppColors.charcoal
                      : Colors.white,
                )
              : const Icon(Icons.add, size: 14, color: Colors.white70),
        ),
      ),
    );
  }
}

class _VariantList extends StatelessWidget {
  const _VariantList({
    required this.draft,
    required this.onChanged,
    required this.baseSku,
  });

  final VariantDraft draft;
  final VoidCallback onChanged;
  final String baseSku;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        for (final variant in draft.variants)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: variant.swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x22000000)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${variant.size} · ${variant.color}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'SKU: ${baseSku.isEmpty ? '' : '$baseSku-'}${variant.effectiveSkuSuffix}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (variant.stock == 0)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.stockLow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: const Text(
                      'Sin stock',
                      style: TextStyle(
                        color: AppColors.stockLow,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                QtyStepper(
                  value: variant.stock,
                  min: 0,
                  onChanged: (v) {
                    draft.setStock(variant.size, variant.color, v);
                    onChanged();
                  },
                ),
                IconButton(
                  tooltip: 'Quitar combinación',
                  onPressed: () {
                    draft.removeVariant(variant.size, variant.color);
                    onChanged();
                  },
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => _addCombination(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Agregar combinación'),
        ),
      ],
    );
  }

  Future<void> _addCombination(BuildContext context) async {
    String? size = draft.sizes.isEmpty ? null : draft.sizes.first;
    SwatchColor? color = draft.colors.isEmpty ? null : draft.colors.first;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar combinación'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: size,
                    items: [
                      for (final s in {
                        ...draft.sizes,
                        ...VariantDraft.suggestedSizes,
                      })
                        DropdownMenuItem(value: s, child: Text(s)),
                    ],
                    onChanged: (v) => setState(() => size = v),
                    decoration: const InputDecoration(labelText: 'Talle'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: color?.name,
                    items: [
                      for (final c in Swatches.all)
                        DropdownMenuItem(value: c.name, child: Text(c.name)),
                    ],
                    onChanged: (v) {
                      setState(() {
                        color = Swatches.all.firstWhere((c) => c.name == v);
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Color'),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (size != null && color != null) {
                  draft.addCombination(size!, color!);
                  onChanged();
                }
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }
}

class _VariantMatrix extends StatelessWidget {
  const _VariantMatrix({required this.draft, required this.onChanged});

  final VariantDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 44,
        dataRowMinHeight: 56,
        dataRowMaxHeight: 56,
        columns: [
          const DataColumn(label: Text('Talle')),
          for (final color in draft.colors)
            DataColumn(
              label: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(color.name),
                ],
              ),
            ),
        ],
        rows: [
          for (final size in draft.sizes)
            DataRow(
              cells: [
                DataCell(Text(size, style: const TextStyle(fontWeight: FontWeight.w600))),
                for (final color in draft.colors)
                  DataCell(
                    _MatrixCell(
                      cellKey: '$size-${color.name}',
                      stock: draft.find(size, color.name)?.stock ?? 0,
                      tintEmpty: isDark,
                      onChanged: (value) {
                        draft.ensureCell(size, color);
                        draft.setStock(size, color.name, value);
                        onChanged();
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MatrixCell extends StatelessWidget {
  const _MatrixCell({
    required this.cellKey,
    required this.stock,
    required this.onChanged,
    required this.tintEmpty,
  });

  final String cellKey;
  final int stock;
  final ValueChanged<int> onChanged;
  final bool tintEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      decoration: BoxDecoration(
        color: stock == 0
            ? AppColors.stockLow.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextFormField(
        key: ValueKey(cellKey),
        initialValue: '$stock',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        onChanged: (v) => onChanged(int.tryParse(v) ?? 0),
      ),
    );
  }
}
