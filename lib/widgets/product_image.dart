import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';

class ProductImage extends StatelessWidget {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : null;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : null;
        final preview = bytes;
        final cached = preview == null || preview.isEmpty
            ? _appStoreOf(context)?.cachedProductImage(path)
            : null;
        final Widget image;
        if (preview != null && preview.isNotEmpty) {
          image = Image.memory(
            preview,
            key: ValueKey('memory:$path:${preview.length}'),
            fit: fit,
            width: width,
            height: height,
            gaplessPlayback: false,
            errorBuilder: (_, _, _) => fallback,
          );
        } else if (cached != null && cached.isNotEmpty) {
          image = Image.memory(
            cached,
            key: ValueKey('cached:$path:${cached.length}'),
            fit: fit,
            width: width,
            height: height,
            gaplessPlayback: false,
            errorBuilder: (_, _, _) => fallback,
          );
        } else if (path.isEmpty) {
          image = fallback;
        } else if (_isNetworkPath(path)) {
          image = Image.network(
            path,
            key: ValueKey('network:$path'),
            fit: fit,
            width: width,
            height: height,
            gaplessPlayback: false,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (_, error, _) {
              debugPrint('Product image network failed: $path $error');
              return fallback;
            },
          );
        } else {
          image = Image.asset(
            path,
            key: ValueKey('asset:$path'),
            fit: fit,
            width: width,
            height: height,
            gaplessPlayback: false,
            errorBuilder: (_, _, _) => fallback,
          );
        }

        if (borderRadius == null) return image;
        return ClipRRect(borderRadius: borderRadius!, child: image);
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

bool _isNetworkPath(String path) {
  final uri = Uri.tryParse(path);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}
