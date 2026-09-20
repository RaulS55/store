import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'product_image.dart';
import 'product_image_viewer.dart';

class ProductImagePager extends StatefulWidget {
  const ProductImagePager({
    super.key,
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
  State<ProductImagePager> createState() => _ProductImagePagerState();
}

class _ProductImagePagerState extends State<ProductImagePager> {
  late final PageController _controller;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.index);
  }

  @override
  void didUpdateWidget(covariant ProductImagePager oldWidget) {
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
        behavior: const ProductImagePagerScrollBehavior(),
        child: PageView.builder(
          controller: _controller,
          physics: images.length > 1
              ? const PageScrollPhysics(parent: AlwaysScrollableScrollPhysics())
              : const NeverScrollableScrollPhysics(),
          onPageChanged: (i) {
            if (_syncing) return;
            widget.onIndex(i);
          },
          itemCount: images.length,
          itemBuilder: (context, i) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return GestureDetector(
              key: ValueKey('product-pager-open-$i-${images[i]}'),
              onTap: () => showProductImageViewer(
                context: context,
                images: productImageEntries(images),
                initialIndex: i,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  ),
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
              ),
            );
          },
        ),
      ),
    );
  }
}

class ProductImagePagerScrollBehavior extends MaterialScrollBehavior {
  const ProductImagePagerScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.invertedStylus,
  };
}
