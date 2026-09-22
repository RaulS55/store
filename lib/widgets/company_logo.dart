import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, required this.url, this.size = 56});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(
      size >= 72 ? AppRadii.lg : AppRadii.md,
    );
    final muted = ColoredBox(
      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
    );
    final fallback = ColoredBox(
      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
      child: Icon(
        Icons.storefront_outlined,
        color: isDark ? Colors.white38 : AppColors.mutedText,
        size: size * 0.42,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (_, _, _) => fallback,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return muted;
            },
          ),
        ),
      ),
    );
  }
}
