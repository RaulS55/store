import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String path;
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

    final image = path.isEmpty
        ? fallback
        : _isNetworkPath(path)
        ? Image.network(
            path,
            fit: fit,
            errorBuilder: (_, _, _) => fallback,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return fallback;
            },
          )
        : Image.asset(path, fit: fit, errorBuilder: (_, _, _) => fallback);

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  bool _isNetworkPath(String path) {
    final uri = Uri.tryParse(path);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
