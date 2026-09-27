import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/image_download.dart';
import '../data/product_image_cache.dart';
import '../theme/tokens.dart';
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

Future<bool> downloadVisibleProductImage({
  required BuildContext context,
  required String path,
  Uint8List? bytes,
  int index = 0,
}) {
  ProductImageCache? cache;
  try {
    cache = Provider.of<ProductImageCache>(context, listen: false);
  } on ProviderNotFoundException {
    cache = null;
  }
  return downloadProductImage(
    path: path,
    bytes: bytes,
    cache: cache,
    index: index,
  );
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
  var _downloading = false;
  String? _feedback;

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

  Future<void> _download() async {
    if (_downloading) return;
    final image = widget.images[_index];
    setState(() => _downloading = true);
    final ok = await downloadVisibleProductImage(
      context: context,
      path: image.path,
      bytes: image.bytes,
      index: _index,
    );
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _feedback = ok ? 'Imagen descargada.' : 'No se pudo descargar la imagen.';
    });
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _feedback = null);
    });
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
                    IconButton(
                      key: const ValueKey('product-image-viewer-download'),
                      tooltip: 'Descargar',
                      onPressed: _downloading ? null : _download,
                      color: Colors.white,
                      icon: _downloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_outlined),
                    ),
                  ],
                ),
              ),
            ),
            if (_feedback != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Text(
                          _feedback!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
