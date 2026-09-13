import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../widgets/product_image.dart';
import '../../widgets/qty_stepper.dart';
import '../../widgets/stock_dot.dart';
import '../../widgets/variant_picker.dart';
import '../order/order_actions.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.id});

  final String id;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _index = 0;
  VariantSelection _selection = const VariantSelection();
  int _qty = 1;

  VariantSelection _effective(Product product) {
    return VariantSelection(
      size: _selection.size ??
          (product.sizes.length == 1 ? product.sizes.first : null),
      color: _selection.color ??
          (product.colors.length == 1 ? product.colors.first.name : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final product = store.productById(widget.id);
    if (product == null) {
      return const Center(child: Text('No encontramos esta prenda.'));
    }
    final selection = _effective(product);

    final images = product.images.isEmpty ? [''] : product.images;
    final variant = product.variantFor(selection.size, selection.color);
    final canAdd = variant != null && variant.stock > 0;
    final wide = AppBreakpoints.isWide(context);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    wide ? 'Moda Stock' : 'Detalle de producto',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: wide ? AppColors.terracotta : null,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => context.go('/pedido'),
                  icon: Badge(
                    isLabelVisible: store.cartCount > 0,
                    label: Text('${store.cartCount}'),
                    backgroundColor: AppColors.terracotta,
                    child: const Icon(Icons.assignment_outlined),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (wide)
                  _WideDetail(
                    product: product,
                    images: images,
                    index: _index,
                    onIndex: (i) => setState(() => _index = i),
                    selection: selection,
                    onSelection: (s) => setState(() {
                      _selection = s;
                      _qty = 1;
                    }),
                    qty: _qty,
                    onQty: (q) => setState(() => _qty = q),
                    canAdd: canAdd,
                    variant: variant,
                    onAdd: () => _add(store, product, variant),
                    onEdit: () => context.go('/producto/${product.id}/editar'),
                  )
                else ...[
                  _ProductImagePager(
                    images: images,
                    index: _index,
                    onIndex: (i) => setState(() => _index = i),
                    aspectRatio: 1.15,
                  ),
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
                            product.status.label,
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
                  Text(
                    'SKU: ${product.sku}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedText,
                    ),
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
                  _Attr('Categoría', product.category.label, Icons.category_outlined),
                  _Attr('Marca', product.brand, Icons.storefront_outlined),
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
                      Text('Cantidad', style: Theme.of(context).textTheme.labelLarge),
                      const Spacer(),
                      QtyStepper(
                        value: _qty,
                        min: 1,
                        max: variant?.stock ?? 1,
                        onChanged: (q) => setState(() => _qty = q),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Galería',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!wide)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    FilledButton.icon(
                      onPressed: canAdd
                          ? () => _add(store, product, variant)
                          : null,
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text('Agregar al pedido'),
                    ),
                    if (!canAdd)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Si no hay selección, el botón se desactiva.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.mutedText),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () =>
                          context.go('/producto/${product.id}/editar'),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _add(
    AppStore store,
    Product product,
    ProductVariant? variant,
  ) async {
    if (variant == null) return;
    var order = store.activeOrder;
    if (order == null) {
      order = await showOrderTargetSheet(context);
      if (order == null || !mounted) return;
    }
    final ok = store.addToOrder(
      product,
      variant,
      quantity: _qty,
      orderId: order.id,
    );
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Agregada a ${order.customer.name}: ${product.name} · ${variant.size} · ${variant.color}',
        ),
      ),
    );
    context.go('/pedido/${order.id}');
  }
}

class _WideDetail extends StatelessWidget {
  const _WideDetail({
    required this.product,
    required this.images,
    required this.index,
    required this.onIndex,
    required this.selection,
    required this.onSelection,
    required this.qty,
    required this.onQty,
    required this.canAdd,
    required this.variant,
    required this.onAdd,
    required this.onEdit,
  });

  final Product product;
  final List<String> images;
  final int index;
  final ValueChanged<int> onIndex;
  final VariantSelection selection;
  final ValueChanged<VariantSelection> onSelection;
  final int qty;
  final ValueChanged<int> onQty;
  final bool canAdd;
  final ProductVariant? variant;
  final VoidCallback onAdd;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _ProductImagePager(
                images: images,
                index: index,
                onIndex: onIndex,
                aspectRatio: 1,
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final selected = i == index;
                    return InkWell(
                      key: ValueKey('product-gallery-thumb-$i'),
                      onTap: () => onIndex(i),
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
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.mutedText,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'SKU: ${variant == null ? product.sku : product.variantSku(variant!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                MoneyFormat.compact(product.price),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.terracotta,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              VariantPicker(
                product: product,
                selection: selection,
                onChanged: onSelection,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  QtyStepper(
                    value: qty,
                    min: 1,
                    max: variant?.stock ?? 1,
                    onChanged: onQty,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canAdd ? onAdd : null,
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      label: const Text('Agregar al pedido'),
                    ),
                  ),
                ],
              ),
              TextButton(onPressed: onEdit, child: const Text('Editar prenda')),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductImagePager extends StatefulWidget {
  const _ProductImagePager({
    required this.images,
    required this.index,
    required this.onIndex,
    required this.aspectRatio,
  });

  final List<String> images;
  final int index;
  final ValueChanged<int> onIndex;
  final double aspectRatio;

  @override
  State<_ProductImagePager> createState() => _ProductImagePagerState();
}

class _ProductImagePagerState extends State<_ProductImagePager> {
  late final PageController _controller;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.index);
  }

  @override
  void didUpdateWidget(covariant _ProductImagePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_controller.hasClients) return;
    if (widget.index == oldWidget.index) return;
    final current = _controller.page?.round() ?? _controller.initialPage;
    if (current == widget.index) return;
    _syncing = true;
    _controller.jumpToPage(widget.index);
    _syncing = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ScrollConfiguration(
        behavior: const _PagerScrollBehavior(),
        child: PageView.builder(
          controller: _controller,
          physics: images.length > 1
              ? const PageScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                )
              : const NeverScrollableScrollPhysics(),
          onPageChanged: (i) {
            if (_syncing) return;
            widget.onIndex(i);
          },
          itemCount: images.length,
          itemBuilder: (context, i) {
            return Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: ProductImage(
                    key: ValueKey('product-pager-image-$i-${images[i]}'),
                    path: images[i],
                    fit: BoxFit.contain,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                ),
                const ColoredBox(color: Color(0x00000000)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PagerScrollBehavior extends MaterialScrollBehavior {
  const _PagerScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.invertedStylus,
  };
}

class _Attr extends StatelessWidget {
  const _Attr(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mutedText),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.mutedText,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
