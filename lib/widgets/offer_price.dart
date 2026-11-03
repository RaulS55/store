import 'package:flutter/material.dart';

import '../data/formatters.dart';
import '../models/product.dart';
import '../theme/tokens.dart';

class OfferPrice extends StatelessWidget {
  const OfferPrice({
    super.key,
    required this.product,
    this.saleStyle,
    this.labeled = false,
    this.showBadge = true,
    this.alignment = CrossAxisAlignment.start,
    this.prefix,
  });

  final Product product;
  final TextStyle? saleStyle;
  final bool labeled;
  final bool showBadge;
  final CrossAxisAlignment alignment;
  final String? prefix;

  String _money(double value) =>
      labeled ? MoneyFormat.labeled(value) : MoneyFormat.compact(value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceStyle =
        saleStyle ??
        theme.textTheme.titleSmall?.copyWith(
          color: AppColors.terracotta,
          fontWeight: FontWeight.w700,
        );
    final sku = prefix?.trim() ?? '';
    if (!product.onSale) {
      final amount = _money(product.price);
      return Text(sku.isEmpty ? amount : '$sku · $amount', style: priceStyle);
    }

    final listStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.mutedText,
      decoration: TextDecoration.lineThrough,
      decorationColor: AppColors.mutedText,
    );
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sku.isNotEmpty)
          Text(
            sku,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.mutedText,
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBadge) ...[const OfferBadge(), const SizedBox(width: 6)],
            Text(
              _money(product.price),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: listStyle,
            ),
          ],
        ),
        Text(
          _money(product.sellingPrice),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: priceStyle,
        ),
      ],
    );
  }
}

class OfferBadge extends StatelessWidget {
  const OfferBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.terracotta,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        'Oferta',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          height: 1.1,
        ),
      ),
    );
  }
}
