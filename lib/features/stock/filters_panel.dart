import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/filters.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';

Future<void> showFiltersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        builder: (context, controller) {
          return FiltersEditor(
            scrollController: controller,
            compact: false,
            onClose: () => Navigator.of(context).pop(),
          );
        },
      );
    },
  );
}

class FiltersEditor extends StatefulWidget {
  const FiltersEditor({
    super.key,
    this.scrollController,
    this.compact = true,
    this.onClose,
  });

  final ScrollController? scrollController;
  final bool compact;
  final VoidCallback? onClose;

  @override
  State<FiltersEditor> createState() => _FiltersEditorState();
}

class _FiltersEditorState extends State<FiltersEditor> {
  late ProductFilters _draft;
  late TextEditingController _min;
  late TextEditingController _max;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _draft = store.filters;
    _min = TextEditingController(
      text: _draft.minPrice?.toStringAsFixed(0) ?? '',
    );
    _max = TextEditingController(
      text: _draft.maxPrice?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _toggleCategory(ApparelCategory category) {
    final next = {..._draft.categories};
    if (!next.add(category)) next.remove(category);
    setState(() => _draft = _draft.copyWith(categories: next));
  }

  void _toggleSize(String size) {
    final next = {..._draft.sizes};
    if (!next.add(size)) next.remove(size);
    setState(() => _draft = _draft.copyWith(sizes: next));
  }

  void _toggleColor(String name) {
    final next = {..._draft.colorNames};
    if (!next.add(name)) next.remove(name);
    setState(() => _draft = _draft.copyWith(colorNames: next));
  }

  void _toggleBrand(String brand) {
    final next = {..._draft.brands};
    if (!next.add(brand)) next.remove(brand);
    setState(() => _draft = _draft.copyWith(brands: next));
  }

  ProductFilters _withPrices() {
    return _draft.copyWith(
      minPrice: double.tryParse(_min.text.replaceAll('.', '')),
      maxPrice: double.tryParse(_max.text.replaceAll('.', '')),
      clearPrices: _min.text.isEmpty && _max.text.isEmpty,
    );
  }

  void _apply() {
    context.read<AppStore>().applyFilters(_withPrices());
    widget.onClose?.call();
  }

  void _clear() {
    setState(() {
      _draft = const ProductFilters();
      _min.clear();
      _max.clear();
    });
    context.read<AppStore>().applyFilters(const ProductFilters());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = Theme.of(context);

    return Column(
      children: [
        if (!widget.compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
            child: Row(
              children: [
                Text(
                  'Filtros',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              _Label('Categoría'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in store.visibleCategories)
                    FilterChip(
                      label: Text(category.label),
                      selected: _draft.categories.contains(category),
                      onSelected: (_) => _toggleCategory(category),
                      showCheckmark: true,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _Label('Talle'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final size in store.allSizes)
                    FilterChip(
                      label: Text(size),
                      selected: _draft.sizes.contains(size),
                      showCheckmark: false,
                      selectedColor: AppColors.terracottaChip,
                      onSelected: (_) => _toggleSize(size),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _Label('Color'),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (final color in store.allColors)
                    if (color.isCustom)
                      FilterChip(
                        label: Text(color.name),
                        selected: _draft.colorNames.contains(color.name),
                        showCheckmark: false,
                        selectedColor: AppColors.terracottaChip,
                        onSelected: (_) => _toggleColor(color.name),
                      )
                    else
                      _ColorDot(
                        color: color.color,
                        label: color.name,
                        selected: _draft.colorNames.contains(color.name),
                        onTap: () => _toggleColor(color.name),
                      ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _Label('Marca'),
                  const Spacer(),
                  Text(
                    'Ver todas',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.terracotta,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (final brand in store.allBrands.take(6))
                CheckboxListTile(
                  value: _draft.brands.contains(brand),
                  onChanged: (_) => _toggleBrand(brand),
                  title: Text(brand),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.terracotta,
                ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _draft.onlyLowStock,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(onlyLowStock: v)),
                title: const Text('Solo bajo stock'),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.terracotta,
              ),
              const SizedBox(height: 8),
              _Label('Rango de precio'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _min,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        prefixText: r'$ ',
                        hintText: 'Mínimo',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _max,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        prefixText: r'$ ',
                        hintText: 'Máximo',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clear,
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Text('Aplicar filtros'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class WebFilterBar extends StatelessWidget {
  const WebFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: AppColors.terracotta),
              const SizedBox(width: 8),
              Text(
                'Filtros avanzados',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (!store.filters.isEmpty)
                TextButton(
                  onPressed: store.clearFilters,
                  child: const Text('Limpiar filtros'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _DropdownWrap(
                      label: 'Categoría',
                      child: DropdownButton<ApparelCategory?>(
                        value:
                            store.visibleCategories.contains(store.chipCategory)
                            ? store.chipCategory
                            : null,
                        hint: const Text('Todas'),
                        underline: const SizedBox.shrink(),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todas'),
                          ),
                          for (final c in store.visibleCategories)
                            DropdownMenuItem(value: c, child: Text(c.label)),
                        ],
                        onChanged: store.selectChipCategory,
                      ),
                    ),
                    _FilterChipRow(store: store),
                    FilterChip(
                      label: const Text('Poco stock'),
                      selected: store.filters.onlyLowStock,
                      showCheckmark: false,
                      selectedColor: AppColors.terracottaChip,
                      onSelected: (v) => store.applyFilters(
                        store.filters.copyWith(onlyLowStock: v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => showFiltersSheet(context),
                style: FilledButton.styleFrom(minimumSize: const Size(140, 40)),
                child: const Text('Aplicar filtros'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final size in const ['S', 'M', 'L'])
          FilterChip(
            label: Text(size),
            selected: store.filters.sizes.contains(size),
            showCheckmark: false,
            selectedColor: AppColors.terracottaChip,
            onSelected: (_) {
              final next = {...store.filters.sizes};
              if (!next.add(size)) next.remove(size);
              store.applyFilters(store.filters.copyWith(sizes: next));
            },
          ),
      ],
    );
  }
}

class _DropdownWrap extends StatelessWidget {
  const _DropdownWrap({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label  ',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
          ),
          child,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? AppColors.terracotta
                    : const Color(0x22000000),
                width: selected ? 2 : 1,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: color.computeLuminance() > 0.6
                        ? AppColors.charcoal
                        : Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
