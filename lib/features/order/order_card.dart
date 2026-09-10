import 'package:flutter/material.dart';

import '../../data/formatters.dart';
import '../../models/order.dart';
import '../../theme/tokens.dart';

class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showCustomer = true,
    this.showStatus = false,
  });

  final DraftOrder order;
  final VoidCallback onTap;
  final bool showCustomer;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final names = order.lines.map((line) => line.product.name).toList();
    final date = order.closedAt ?? order.createdAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showCustomer) ...[
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.terracottaChip,
                        child: Text(
                          order.customer.initials,
                          style: const TextStyle(
                            color: AppColors.terracotta,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            showCustomer ? order.customer.name : order.orderNumber,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            [
                              if (showCustomer) order.orderNumber,
                              DateFormatters.short.format(date),
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.slate),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          MoneyFormat.detailed(order.total),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.terracotta,
                          ),
                        ),
                        Text(
                          order.itemCount == 1
                              ? '1 prenda'
                              : '${order.itemCount} prendas',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.mutedText),
                        ),
                      ],
                    ),
                  ],
                ),
                if (showStatus) ...[
                  const SizedBox(height: 10),
                  _StatusChip(order: order),
                ],
                if (order.categorySummary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final item in order.categorySummary)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkMuted
                                : AppColors.terracottaChip,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            '${item.category.label} ×${item.quantity}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                              color: AppColors.terracotta,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (names.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    names.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.order});

  final DraftOrder order;

  @override
  Widget build(BuildContext context) {
    final closed = order.isClosed;
    final color = closed ? AppColors.slate : AppColors.stockOk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        order.status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
