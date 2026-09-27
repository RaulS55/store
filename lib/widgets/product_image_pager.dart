import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_snack_bar.dart';
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
            return Stack(
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
                GestureDetector(
                  key: ValueKey('product-pager-open-$i-${images[i]}'),
                  onTap: () => showProductImageViewer(
                    context: context,
                    images: productImageEntries(images),
                    initialIndex: i,
                  ),
                  child: const ColoredBox(color: Color(0x00000000)),
                ),
                if (images[i].isNotEmpty)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _PagerDownloadButton(path: images[i], index: i),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PagerDownloadButton extends StatefulWidget {
  const _PagerDownloadButton({required this.path, required this.index});

  final String path;
  final int index;

  @override
  State<_PagerDownloadButton> createState() => _PagerDownloadButtonState();
}

class _PagerDownloadButtonState extends State<_PagerDownloadButton> {
  var _downloading = false;

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final ok = await downloadVisibleProductImage(
      context: context,
      path: widget.path,
      index: widget.index,
    );
    if (!mounted) return;
    setState(() => _downloading = false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      AppSnackBar(
        content: Text(
          ok ? 'Imagen descargada.' : 'No se pudo descargar la imagen.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: IconButton(
        key: ValueKey('product-pager-download-${widget.index}-${widget.path}'),
        tooltip: 'Descargar',
        onPressed: _downloading ? null : _download,
        color: Colors.white,
        icon: _downloading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download_outlined),
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
