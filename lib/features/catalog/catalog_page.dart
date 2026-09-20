import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/catalog_guest_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/product_card.dart';
import '../../widgets/search_field.dart';
import 'catalog_routes.dart';

class CatalogPage extends StatelessWidget {
  const CatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = catalogStoreOf(context);
    return ChangeNotifierProvider.value(
      value: store,
      child: const _CatalogView(),
    );
  }
}

class _CatalogView extends StatefulWidget {
  const _CatalogView();

  @override
  State<_CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<_CatalogView> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: context.read<CatalogGuestStore>().searchQuery,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CatalogGuestStore>();
    final companyId = store.companyId;
    final products = store.visibleProducts;
    final wide = AppBreakpoints.isWide(context);

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        store.company?.name ?? 'Catálogo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Pedido',
                      onPressed: () => context.push(catalogCartPath(companyId)),
                      icon: Badge(
                        isLabelVisible: store.cartCount > 0,
                        label: Text('${store.cartCount}'),
                        backgroundColor: AppColors.terracotta,
                        child: const Icon(Icons.shopping_bag_outlined),
                      ),
                    ),
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
                ),
              ),
            ),
            if (store.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (store.notFound)
              const SliverFillRemaining(
                child: _Message(
                  icon: Icons.storefront_outlined,
                  title: 'No encontramos este catálogo.',
                  body: 'Pedile al negocio un enlace nuevo.',
                ),
              )
            else if (products.isEmpty)
              SliverFillRemaining(
                child: _Message(
                  icon: Icons.search_off,
                  title: store.products.isEmpty
                      ? 'Todavía no hay prendas'
                      : 'No encontramos prendas',
                  body: store.products.isEmpty
                      ? 'Este negocio todavía no publicó su catálogo.'
                      : 'Probá con otro nombre, SKU o marca.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: wide ? 4 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.62,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final product = products[index];
                    return ProductCard(
                      product: product,
                      dense: true,
                      onTap: () => context.push(
                        catalogProductPath(companyId, product.id),
                      ),
                    );
                  }, childCount: products.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.mutedText),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}
