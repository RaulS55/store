import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/tokens.dart';

class StockDot extends StatelessWidget {
  const StockDot({super.key, required this.low});

  final bool low;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: low ? AppColors.stockLow : AppColors.stockOk,
        shape: BoxShape.circle,
      ),
    );
  }
}

class StockLabel extends StatelessWidget {
  const StockLabel({
    super.key,
    required this.stock,
    this.compact = true,
  });

  final int stock;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final low = stock <= Product.lowStockThreshold;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StockDot(low: low),
        const SizedBox(width: 6),
        Text(compact ? '$stock u.' : '$stock unidades', style: style),
      ],
    );
  }
}
