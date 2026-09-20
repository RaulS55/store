import 'package:flutter/material.dart';

import '../data/formatters.dart';
import '../models/product.dart';
import '../theme/tokens.dart';
import 'product_image.dart';
import 'stock_dot.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.dense = false,
  });

  final Product product;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ProductImage(
                        path: product.image,
                        fit: BoxFit.contain,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadii.md),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.55)
                              : Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 12,
                              color: product.isLowStock
                                  ? AppColors.stockLow
                                  : AppColors.stockOk,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${product.stock}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, dense ? 10 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${product.sku}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                    if (!dense &&
                        (product.categoryLabel.isNotEmpty ||
                            product.audienceLabel.isNotEmpty)) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (product.categoryLabel.isNotEmpty)
                            product.categoryLabel,
                          if (product.audienceLabel.isNotEmpty)
                            product.audienceLabel,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.slate,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    StockLabel(stock: product.stock),
                    const SizedBox(height: 6),
                    Text(
                      MoneyFormat.labeled(product.price),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.terracotta,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
