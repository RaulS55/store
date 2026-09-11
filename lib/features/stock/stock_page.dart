import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/filters.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../widgets/product_card.dart';
import '../../widgets/search_field.dart';
import 'filters_panel.dart';
import 'product_table.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late final TextEditingController _search;

  static const _chips = [
    ApparelCategory.remeras,
    ApparelCategory.pantalones,
    ApparelCategory.calzado,
    ApparelCategory.abrigos,
    ApparelCategory.buzos,
    ApparelCategory.camperas,
  ];

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: context.read<AppStore>().searchQuery);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = AppBreakpoints.isWide(context);
    return wide ? _buildWeb(context) : _buildMobile(context);
  }

  Widget _buildMobile(BuildContext context) {
    final store = context.watch<AppStore>();
    final products = store.filteredProducts;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Stock',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const Spacer(),
                  _CartButton(count: store.cartCount),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SearchField(
                controller: _search,
                hint: 'Buscar prenda, SKU o marca...',
                onChanged: store.setSearch,
                trailing: IconButton(
                  tooltip: 'Filtros',
                  onPressed: () => showFiltersSheet(context),
                  icon: Badge(
                    isLabelVisible: store.filters.activeCount > 0,
                    label: Text('${store.filters.activeCount}'),
                    child: const Icon(Icons.tune, size: 20),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _CategoryChips(chips: _chips)),
          if (products.isEmpty)
            SliverFillRemaining(
              child: _EmptyStock(hasCatalog: store.products.isNotEmpty),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = products[index];
                    return ProductCard(
                      product: product,
                      dense: true,
                      onTap: () => context.go('/producto/${product.id}'),
                    );
                  },
                  childCount: products.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeb(BuildContext context) {
    final store = context.watch<AppStore>();
    final products = store.pagedProducts;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gestioná el inventario de prendas y calzado',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.slate),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: SearchField(
                      controller: _search,
                      hint: 'Buscar por nombre, SKU o referencia...',
                      onChanged: store.setSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: store.themeMode == ThemeMode.dark
                        ? 'Modo claro'
                        : 'Modo oscuro',
                    onPressed: store.toggleTheme,
                    icon: Icon(
                      store.themeMode == ThemeMode.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                  ),
                  _CartButton(count: store.cartCount),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(28, 8, 28, 8),
              child: WebFilterBar(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
              child: Row(
                children: [
                  Text(
                    'Mostrando ${products.isEmpty ? 0 : store.page * store.pageSize + 1}–${store.page * store.pageSize + products.length} de ${store.filteredCount} prendas',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate,
                    ),
                  ),
                  const Spacer(),
                  DropdownButton<StockSort>(
                    value: store.sort,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final sort in StockSort.values)
                        DropdownMenuItem(
                          value: sort,
                          child: Text('Ordenar: ${sort.label}'),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) store.setSort(v);
                    },
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<StockViewMode>(
                    segments: const [
                      ButtonSegment(
                        value: StockViewMode.cards,
                        icon: Icon(Icons.grid_view_rounded, size: 18),
                        label: Text('Tarjetas'),
                      ),
                      ButtonSegment(
                        value: StockViewMode.table,
                        icon: Icon(Icons.table_rows_outlined, size: 18),
                        label: Text('Tabla'),
                      ),
                    ],
                    selected: {store.viewMode},
                    onSelectionChanged: (v) => store.setViewMode(v.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (products.isEmpty)
            SliverFillRemaining(
              child: _EmptyStock(hasCatalog: store.products.isNotEmpty),
            )
          else if (store.viewMode == StockViewMode.table)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
              sliver: SliverToBoxAdapter(child: ProductTable(products: products)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.68,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = products[index];
                    return ProductCard(
                      product: product,
                      onTap: () => context.go('/producto/${product.id}'),
                    );
                  },
                  childCount: products.length,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: _Pagination(
                page: store.page,
                pageCount: store.pageCount,
                onChanged: store.setPage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.chips});

  final List<ApparelCategory> chips;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: store.chipCategory == null
                  ? const Icon(Icons.check, size: 16)
                  : null,
              label: const Text('Todo'),
              selected: store.chipCategory == null,
              onSelected: (_) => store.selectChipCategory(null),
            ),
          ),
          for (final category in chips)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category.label),
                selected: store.chipCategory == category,
                onSelected: (_) => store.selectChipCategory(category),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Pedidos',
      onPressed: () => context.go('/pedido'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: AppColors.terracotta,
        child: const Icon(Icons.shopping_bag_outlined),
      ),
    );
  }
}

class _EmptyStock extends StatelessWidget {
  const _EmptyStock({required this.hasCatalog});

  final bool hasCatalog;

  @override
  Widget build(BuildContext context) {
    if (!hasCatalog) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.checkroom_outlined,
                size: 40,
                color: AppColors.mutedText,
              ),
              const SizedBox(height: 12),
              Text(
                'Todavía no hay prendas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Cargá la primera prenda para armar el catálogo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/producto/nuevo'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Nueva prenda'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 40, color: AppColors.mutedText),
            const SizedBox(height: 12),
            Text(
              'No encontramos prendas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Probá con otro nombre, SKU o limpiá los filtros.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.slate,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: context.read<AppStore>().clearFilters,
              child: const Text('Limpiar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.pageCount,
    required this.onChanged,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final pages = <int>[];
    for (var i = 0; i < pageCount; i++) {
      if (i == 0 || i == pageCount - 1 || (i - page).abs() <= 1) {
        pages.add(i);
      }
    }
    final unique = <int>[];
    for (final p in pages) {
      if (unique.isEmpty || unique.last != p) unique.add(p);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: page > 0 ? () => onChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        for (var i = 0; i < unique.length; i++) ...[
          if (i > 0 && unique[i] - unique[i - 1] > 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('…'),
            ),
          _PagePill(
            label: '${unique[i] + 1}',
            selected: unique[i] == page,
            onTap: () => onChanged(unique[i]),
          ),
        ],
        IconButton(
          onPressed: page < pageCount - 1 ? () => onChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _PagePill extends StatelessWidget {
  const _PagePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Ink(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: selected ? AppColors.terracotta : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
