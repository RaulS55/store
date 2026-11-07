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
    this.showRemaining = false,
  });

  final DraftOrder order;
  final VoidCallback onTap;
  final bool showCustomer;
  final bool showStatus;
  final bool showRemaining;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final names = order.lines.map((line) => line.product.name).toList();
    final date = order.closedAt ?? order.createdAt;
    final remaining = order.remaining;
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
              border: _summaryBorder(
                order,
                isDark: isDark,
                showRemaining: showRemaining,
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
                            showCustomer
                                ? order.customer.name
                                : order.orderNumber,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            [
                              if (showCustomer) order.orderNumber,
                              DateFormatters.short.format(date),
                              if (order.isCatalog) 'Catálogo',
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
                if (showRemaining) ...[
                  if (order.paidLines.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final line in order.paidLines)
                      _AmountRow(label: line.label, amount: line.amount),
                  ],
                  const SizedBox(height: 6),
                  _AmountRow(
                    label: 'Restante',
                    amount: remaining,
                    emphasize: remaining > 0,
                  ),
                ] else ...[
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
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _reservedDueAlert = 20000.0;

/// Amount that paints the card border. A deposit or payment only covers
/// reserved stock. With neither, the full remaining balance counts.
double _borderBalance(DraftOrder order) {
  if (!order.hasSena && !order.hasPayments) return order.remaining;
  return order.reservedDue;
}

Border _summaryBorder(
  DraftOrder order, {
  required bool isDark,
  required bool showRemaining,
}) {
  final neutral = isDark ? AppColors.darkBorder : AppColors.lightBorder;
  final due = _borderBalance(order);
  if (!showRemaining || !order.isActive || due <= 0) {
    return Border.all(color: neutral);
  }
  final alert = due <= _reservedDueAlert
      ? AppColors.stockGap
      : AppColors.stockLow;
  return Border.all(color: alert, width: 2);
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });

  final String label;
  final double amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
          ),
          const Spacer(),
          Text(
            MoneyFormat.detailed(amount),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: emphasize ? AppColors.terracotta : AppColors.slate,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
