import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'product_image.dart';

class ProductImageEntry {
  const ProductImageEntry({this.path = '', this.bytes});

  final String path;
  final Uint8List? bytes;

  bool get hasContent {
    final preview = bytes;
    return (preview != null && preview.isNotEmpty) || path.isNotEmpty;
  }
}

List<ProductImageEntry> productImageEntries(Iterable<String> paths) {
  return [for (final path in paths) ProductImageEntry(path: path)];
}

Future<void> showProductImageViewer({
  required BuildContext context,
  required List<ProductImageEntry> images,
  int initialIndex = 0,
}) {
  final visible = <ProductImageEntry>[];
  var start = 0;
  for (var i = 0; i < images.length; i++) {
    if (!images[i].hasContent) continue;
    if (i <= initialIndex) start = visible.length;
    visible.add(images[i]);
  }
  if (visible.isEmpty) return Future<void>.value();
  start = start.clamp(0, visible.length - 1);
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (context) {
      return ProductImageViewer(images: visible, initialIndex: start);
    },
  );
}

class ProductImageViewer extends StatefulWidget {
  const ProductImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<ProductImageEntry> images;
  final int initialIndex;

  @override
  State<ProductImageViewer> createState() => _ProductImageViewerState();
}

class _ProductImageViewerState extends State<ProductImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Material(
        key: const ValueKey('product-image-viewer'),
        color: Colors.transparent,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: images.length,
              itemBuilder: (context, i) {
                final image = images[i];
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: SizedBox.expand(
                    child: ProductImage(
                      key: ValueKey(
                        'product-image-viewer-image-$i-${image.path}',
                      ),
                      path: image.path,
                      bytes: image.bytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('product-image-viewer-close'),
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      color: Colors.white,
                      icon: const Icon(Icons.close),
                    ),
                    const Spacer(),
                    if (images.length > 1)
                      Text(
                        '${_index + 1} / ${images.length}',
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: Colors.white),
                      ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
