import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/tokens.dart';

class StockDot extends StatelessWidget {
  const StockDot({super.key, required this.low, this.color});

  final bool low;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color ?? (low ? AppColors.stockLow : AppColors.stockOk),
        shape: BoxShape.circle,
      ),
    );
  }
}

class StockLabel extends StatelessWidget {
  const StockLabel({super.key, required this.stock, this.compact = true});

  final int stock;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final out = stock <= 0;
    final low = !out && stock <= Product.lowStockThreshold;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: out
          ? AppColors.stockLow
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
      fontWeight: out ? FontWeight.w700 : null,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StockDot(low: out || low),
        const SizedBox(width: 6),
        Text(
          out ? 'Sin stock' : (compact ? '$stock u.' : '$stock unidades'),
          style: style,
        ),
      ],
    );
  }
}
