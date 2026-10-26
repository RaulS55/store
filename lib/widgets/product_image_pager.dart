import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/image_download.dart';
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
  PreparedProductImage? _prepared;
  var _warmKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _warm();
  }

  @override
  void didUpdateWidget(covariant _PagerDownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.index != widget.index) {
      _prepared = null;
      _warmKey = '';
      _warm();
    }
  }

  void _warm() {
    final key = '${widget.index}|${widget.path}';
    if (key == _warmKey) return;
    _warmKey = key;
    _prepared = null;
    final path = widget.path;
    final index = widget.index;
    unawaited(() async {
      final prepared = await prepareVisibleProductImage(
        context: context,
        path: path,
        index: index,
      );
      if (!mounted || widget.path != path || widget.index != index) return;
      setState(() => _prepared = prepared);
    }());
  }

  void _download() {
    if (_downloading) return;
    final prepared = _prepared;
    final pending = prepared != null
        ? saveProductImageBytes(
            bytes: prepared.bytes,
            filename: prepared.filename,
            mimeType: prepared.mimeType,
          )
        : downloadVisibleProductImage(
            context: context,
            path: widget.path,
            index: widget.index,
          );
    setState(() => _downloading = true);
    unawaited(_completeDownload(pending));
  }

  Future<void> _completeDownload(Future<ImageDownloadResult> pending) async {
    try {
      var result = await pending;
      if (!mounted) return;
      result = await finishProductImageDownload(context, result);
      if (!mounted) return;
      final message = result.message;
      if (message == null) return;
      AppSnackBar.show(context, content: Text(message));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
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
