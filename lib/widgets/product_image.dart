import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../data/image_compress.dart';
import '../data/product_image_cache.dart';
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
    if (_cache == null ||
        !_cache!.allowRemoteFetch ||
        path.isEmpty ||
        !isNetworkProductImageUrl(path)) {
      return;
    }
    if (_requested == path) return;
    _requested = path;
    _loading = true;
    _cache!.load(path).then((bytes) {
      if (!mounted || _requested != path) return;
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
        // Keep one decode size for remote/cached JPEGs so the viewer reuses cache.
        final layoutDecode = _decodeSize(width, height, dpr);
        const sharedDecode = (width: maxProductImageEdge, height: null);
        final Widget image;
        if (preview != null && preview.isNotEmpty) {
          image = Image.memory(
            preview,
            key: ValueKey('memory:${widget.path}:${preview.length}'),
            fit: widget.fit,
            width: width,
            height: height,
            cacheWidth: layoutDecode.width,
            cacheHeight: layoutDecode.height,
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
            cacheWidth: sharedDecode.width,
            cacheHeight: sharedDecode.height,
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
            cacheWidth: sharedDecode.width,
            cacheHeight: sharedDecode.height,
            gaplessPlayback: true,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
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
            cacheWidth: sharedDecode.width,
            cacheHeight: sharedDecode.height,
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

int? _cachePx(double? size, double dpr) {
  if (size == null || !size.isFinite || size <= 0) return null;
  return (size * dpr).round().clamp(1, 4096);
}

({int? width, int? height}) _decodeSize(
  double? width,
  double? height,
  double dpr,
) {
  final cacheWidth = _cachePx(width, dpr);
  final cacheHeight = _cachePx(height, dpr);
  if (cacheWidth != null && cacheHeight != null) {
    if (cacheWidth >= cacheHeight) {
      return (width: cacheWidth, height: null);
    }
    return (width: null, height: cacheHeight);
  }
  return (width: cacheWidth, height: cacheHeight);
}
