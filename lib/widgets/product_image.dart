import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../data/image_compress.dart';
import '../data/product_image_cache.dart';
import '../models/product.dart';
import '../theme/tokens.dart';

class ProductImage extends StatefulWidget {
  const ProductImage({
    super.key,
    this.path = '',
    this.bytes,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String path;
  final Uint8List? bytes;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  State<ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<ProductImage> {
  ProductImageCache? _cache;
  Uint8List? _resolved;
  var _loading = false;
  String? _requested;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cache = _imageCacheOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant ProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path == widget.path && oldWidget.bytes == widget.bytes) {
      return;
    }
    _requested = null;
    _resolved = null;
    _loading = false;
    _sync();
  }

  void _sync() {
    final preview = widget.bytes;
    if (preview != null && preview.isNotEmpty) {
      _resolved = preview;
      _loading = false;
      return;
    }
    final path = widget.path;
    final peeked =
        _cache?.peek(path) ?? _appStoreOf(context)?.cachedProductImage(path);
    if (peeked != null && peeked.isNotEmpty) {
      _resolved = peeked;
      _loading = false;
      return;
    }
    if (path.isEmpty || !isNetworkProductImageUrl(path)) return;
    if (_requested == path) return;
    _requested = path;
    _loading = false;
    final cache = _cache;
    if (cache == null || !cache.allowRemoteFetch) return;
    cache.load(path).then((bytes) {
      if (!mounted || _requested != path || bytes == null || bytes.isEmpty) {
        return;
      }
      setState(() {
        _loading = false;
        _resolved = bytes;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallback = ColoredBox(
      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
      child: Center(
        child: Icon(
          Icons.checkroom_outlined,
          color: isDark ? Colors.white24 : AppColors.mutedText,
          size: 36,
        ),
      ),
    );
    final muted = ColoredBox(
      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : null;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : null;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final preview = widget.bytes;
        final cached = preview == null || preview.isEmpty ? _resolved : null;
        final decode = _decodeSize(width, height, dpr);
        final Widget image;
        if (preview != null && preview.isNotEmpty) {
          image = Image.memory(
            preview,
            key: ValueKey('memory:${widget.path}:${preview.length}'),
            fit: widget.fit,
            width: width,
            height: height,
            cacheWidth: decode.width,
            cacheHeight: decode.height,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => fallback,
          );
        } else if (cached != null && cached.isNotEmpty) {
          image = Image.memory(
            cached,
            key: ValueKey('cached:${widget.path}:${cached.length}'),
            fit: widget.fit,
            width: width,
            height: height,
            cacheWidth: decode.width,
            cacheHeight: decode.height,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => fallback,
          );
        } else if (widget.path.isEmpty) {
          image = fallback;
        } else if (_loading && isNetworkProductImageUrl(widget.path)) {
          image = muted;
        } else if (_isNetworkPath(widget.path)) {
          image = Image.network(
            widget.path,
            key: ValueKey('network:${widget.path}'),
            fit: widget.fit,
            width: width,
            height: height,
            // On web, skip ResizeImage so stock, detail and the browser HTTP
            // cache share one key. Native still decodes to the painted size.
            cacheWidth: kIsWeb ? null : decode.width,
            cacheHeight: kIsWeb ? null : decode.height,
            gaplessPlayback: true,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (_, error, _) {
              debugPrint('Product image network failed: ${widget.path} $error');
              return fallback;
            },
          );
        } else {
          image = Image.asset(
            widget.path,
            key: ValueKey('asset:${widget.path}'),
            fit: widget.fit,
            width: width,
            height: height,
            cacheWidth: decode.width,
            cacheHeight: decode.height,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => fallback,
          );
        }

        if (widget.borderRadius == null) return image;
        return ClipRRect(borderRadius: widget.borderRadius!, child: image);
      },
    );
  }
}

AppStore? _appStoreOf(BuildContext context) {
  try {
    return Provider.of<AppStore>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}

ProductImageCache? _imageCacheOf(BuildContext context) {
  try {
    return Provider.of<ProductImageCache>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}

bool _isNetworkPath(String path) => isNetworkProductImageUrl(path);

void prefetchProductGallery(BuildContext context, Product product) {
  try {
    final cache = Provider.of<ProductImageCache>(context, listen: false);
    unawaited(cache.prefetchProductImages([product], coversOnly: false));
  } on ProviderNotFoundException {
    return;
  }
}

const _thumbLogical = 100.0;
const _cardMaxLogical = 400.0;

int? _cachePx(double? size, double dpr) {
  if (size == null || !size.isFinite || size <= 0) return null;
  return (size * dpr).round().clamp(1, maxProductImageEdge);
}

({int? width, int? height}) _decodeSize(
  double? width,
  double? height,
  double dpr,
) {
  final longest = [
    if (width != null && width.isFinite && width > 0) width,
    if (height != null && height.isFinite && height > 0) height,
  ].fold<double>(0, (a, b) => a > b ? a : b);
  // Cards stay at the painted size so a restart does not decode 1600px
  // for every tile. Detail/viewer keep the full bucket.
  if (longest > 0 && longest < _cardMaxLogical) {
    final logical = longest < _thumbLogical ? _thumbLogical : longest;
    return (width: _cachePx(logical, dpr), height: null);
  }
  return (width: maxProductImageEdge, height: null);
}
