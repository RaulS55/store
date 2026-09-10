import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.checkroom_outlined,
          color: AppColors.terracotta,
          size: compact ? 20 : 22,
        ),
        if (!compact) ...[
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Moda ', style: title),
                TextSpan(
                  text: 'Stock',
                  style: title?.copyWith(color: AppColors.terracotta),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
