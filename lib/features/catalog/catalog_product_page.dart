import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/catalog_guest_store.dart';
import '../../data/formatters.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../widgets/product_image.dart';
import '../../widgets/product_image_pager.dart';
import '../../widgets/qty_stepper.dart';
import '../../widgets/stock_dot.dart';
import '../../widgets/variant_picker.dart';
import 'catalog_routes.dart';

class CatalogProductPage extends StatelessWidget {
  const CatalogProductPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final store = catalogStoreOf(context);
    return ChangeNotifierProvider.value(
      value: store,
      child: _CatalogProductView(id: id),
    );
  }
}

class _CatalogProductView extends StatefulWidget {
  const _CatalogProductView({required this.id});

  final String id;

  @override
  State<_CatalogProductView> createState() => _CatalogProductViewState();
}

class _CatalogProductViewState extends State<_CatalogProductView> {
  int _index = 0;
  VariantSelection _selection = const VariantSelection();
  int _qty = 1;
  String? _prefetchedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefetchGallery();
  }

  @override
  void didUpdateWidget(covariant _CatalogProductView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _prefetchedId = null;
      _prefetchGallery();
    }
  }

  void _prefetchGallery() {
    final product = context.read<CatalogGuestStore>().productById(widget.id);
    if (product == null || _prefetchedId == product.id) return;
    _prefetchedId = product.id;
    prefetchProductGallery(context, product);
  }

  VariantSelection _effective(Product product) {
    return VariantSelection(
      size:
          _selection.size ??
          (product.sizes.length == 1 ? product.sizes.first : null),
      color:
          _selection.color ??
          (product.colors.length == 1 ? product.colors.first.name : null),
    );
  }

  void _add(CatalogGuestStore store, Product product, ProductVariant? variant) {
    if (variant == null || variant.stock <= 0) return;
    store.addToCart(product, variant, quantity: _qty);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey('catalog-added-snackbar'),
        behavior: SnackBarBehavior.floating,
        content: Text('Agregamos ${product.name} al pedido.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CatalogGuestStore>();
    final product = store.productById(widget.id);
    if (product == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => _back(context, store.companyId),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              const Expanded(
                child: Center(child: Text('No encontramos esta prenda.')),
              ),
            ],
          ),
        ),
      );
    }

    final selection = _effective(product);
    final images = product.images.isEmpty ? [''] : product.images;
    final variant = product.variantFor(selection.size, selection.color);
    final canAdd = variant != null && variant.stock > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _back(context, store.companyId),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Text(
                      store.company?.name ?? 'Catálogo',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Pedido',
                    onPressed: () =>
                        context.push(catalogCartPath(store.companyId)),
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  ProductImagePager(
                    images: images,
                    index: _index,
                    onIndex: (i) => setState(() => _index = i),
                    aspectRatio: 1.15,
                  ),
                  if (images.length > 1) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < images.length; i++)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _index
                                  ? AppColors.terracotta
                                  : AppColors.mutedText.withValues(alpha: 0.4),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final selected = i == _index;
                          return InkWell(
                            key: ValueKey('product-gallery-thumb-$i'),
                            onTap: () => setState(() => _index = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 72,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.terracotta
                                      : AppColors.lightBorder,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: ProductImage(
                                path: images[i],
                                fit: BoxFit.contain,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Row(
                        children: [
                          StockDot(low: product.isLowStock),
                          const SizedBox(width: 6),
                          Text(
                            product.stock <= 0 ? 'Sin stock' : 'Disponible',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: product.isLowStock
                                      ? AppColors.stockLow
                                      : AppColors.stockOk,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    MoneyFormat.compact(product.price),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.terracotta,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (product.categoryLabel.isNotEmpty)
                    _Attr('Categoría', product.categoryLabel),
                  if (product.audienceLabel.isNotEmpty)
                    _Attr('Público', product.audienceLabel),
                  if (product.brand.trim().isNotEmpty)
                    _Attr('Marca', product.brand),
                  if (product.sizes.isNotEmpty)
                    _Attr('Talle en prenda', product.sizeLabel),
                  const SizedBox(height: 12),
                  VariantPicker(
                    product: product,
                    selection: selection,
                    onChanged: (s) => setState(() {
                      _selection = s;
                      _qty = 1;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Cantidad',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const Spacer(),
                      QtyStepper(
                        value: _qty,
                        min: 1,
                        max: variant?.stock ?? 1,
                        onChanged: (q) => setState(() => _qty = q),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: canAdd ? () => _add(store, product, variant) : null,
            icon: const Icon(Icons.add_shopping_cart_outlined),
            label: Text(canAdd ? 'Agregar al pedido' : 'Sin stock'),
          ),
        ),
      ),
    );
  }

  void _back(BuildContext context, String companyId) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(catalogPath(companyId));
    }
  }
}

class _Attr extends StatelessWidget {
  const _Attr(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
