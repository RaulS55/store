import 'dart:async';

import 'package:flutter/foundation.dart';
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

ProductImageCache? productImageCacheOf(BuildContext context) {
  try {
    return Provider.of<ProductImageCache>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}

Future<ImageDownloadResult> downloadVisibleProductImage({
  required BuildContext context,
  required String path,
  Uint8List? bytes,
  int index = 0,
}) {
  return downloadProductImage(
    path: path,
    bytes: bytes,
    cache: productImageCacheOf(context),
    index: index,
  );
}

Future<PreparedProductImage?> prepareVisibleProductImage({
  required BuildContext context,
  required String path,
  Uint8List? bytes,
  int index = 0,
}) {
  return prepareProductImageDownload(
    path: path,
    bytes: bytes,
    cache: productImageCacheOf(context),
    index: index,
  );
}

Future<ImageDownloadResult> finishProductImageDownload(
  BuildContext context,
  ImageDownloadResult result,
) async {
  if (result.status != ImageSaveStatus.needsGesture || !context.mounted) {
    return result;
  }
  final bytes = result.bytes;
  final filename = result.filename;
  final mimeType = result.mimeType;
  if (bytes == null || filename == null || mimeType == null) {
    return const ImageDownloadResult.failed();
  }
  final saved = await showDialog<ImageDownloadResult>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Guardar en la galería'),
        content: Text(_gallerySaveHint),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(const ImageDownloadResult.cancelled());
            },
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('save-image-to-gallery'),
            onPressed: () async {
              final saved = await saveProductImageBytes(
                bytes: bytes,
                filename: filename,
                mimeType: mimeType,
                allowGesturePrompt: false,
              );
              if (context.mounted) Navigator.of(context).pop(saved);
            },
            child: const Text('Guardar'),
          ),
        ],
      );
    },
  );
  return saved ?? const ImageDownloadResult.cancelled();
}

String get _gallerySaveHint {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return 'Tocá Guardar y, en el menú del celular, elegí Guardar imagen.';
  }
  return 'Tocá Guardar y elegí Galería o Fotos.';
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
  PreparedProductImage? _prepared;
  var _warmKey = '';

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _warm();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _warm() {
    final image = widget.images[_index];
    final key = '$_index|${image.path}|${image.bytes?.lengthInBytes}';
    if (key == _warmKey) return;
    _warmKey = key;
    _prepared = null;
    final index = _index;
    unawaited(() async {
      final prepared = await prepareVisibleProductImage(
        context: context,
        path: image.path,
        bytes: image.bytes,
        index: index,
      );
      if (!mounted || _index != index || _warmKey != key) return;
      setState(() => _prepared = prepared);
    }());
  }

  void _download() {
    if (_downloading) return;
    final image = widget.images[_index];
    final index = _index;
    final prepared = _prepared;
    final pending = prepared != null
        ? saveProductImageBytes(
            bytes: prepared.bytes,
            filename: prepared.filename,
            mimeType: prepared.mimeType,
          )
        : downloadVisibleProductImage(
            context: context,
            path: image.path,
            bytes: image.bytes,
            index: index,
          );
    setState(() {
      _downloading = true;
      _feedback = null;
    });
    unawaited(_completeDownload(pending));
  }

  Future<void> _completeDownload(Future<ImageDownloadResult> pending) async {
    try {
      var result = await pending;
      if (!mounted) return;
      result = await finishProductImageDownload(context, result);
      if (!mounted) return;
      final message = result.message;
      setState(() => _feedback = message);
      if (message == null) return;
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _feedback = null);
      });
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
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
              onPageChanged: (i) {
                setState(() => _index = i);
                _warm();
              },
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
