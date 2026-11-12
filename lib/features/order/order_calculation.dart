import 'package:flutter/material.dart';

import '../../data/formatters.dart';
import '../../models/order.dart';
import '../../theme/tokens.dart';

String orderPaidCaption(String label) => '$label (Pagado)';

class OrderCalculationCard extends StatelessWidget {
  const OrderCalculationCard({super.key, required this.order});

  final DraftOrder order;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.terracotta.withValues(alpha: 0.28),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: AppColors.charcoal.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: OrderCalculationBody(order: order),
      ),
    );
  }
}

class OrderCalculationBody extends StatelessWidget {
  const OrderCalculationBody({
    super.key,
    required this.order,
    this.compact = false,
  });

  final DraftOrder order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gap = compact ? 4.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuietAmount(
          label: 'Subtotal',
          amount: MoneyFormat.detailed(order.subtotal),
          compact: compact,
        ),
        if (order.ivaEnabled) ...[
          SizedBox(height: gap),
          _QuietAmount(
            label: order.ivaLabel,
            amount: MoneyFormat.detailed(order.iva),
            compact: compact,
          ),
        ],
        for (final line in order.paidLines) ...[
          SizedBox(height: gap),
          OrderPaidAmount(
            label: line.label,
            amount: line.amount,
            compact: compact,
          ),
        ],
        Padding(
          padding: EdgeInsets.only(top: gap),
          child: Divider(
            height: 1,
            thickness: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightMuted,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: gap),
          child: OrderDueAmount(amount: order.remaining, compact: compact),
        ),
      ],
    );
  }
}

class _QuietAmount extends StatelessWidget {
  const _QuietAmount({
    required this.label,
    required this.amount,
    required this.compact,
  });

  final String label;
  final String amount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final base = compact
        ? Theme.of(context).textTheme.bodySmall
        : Theme.of(context).textTheme.bodyMedium;
    final style = base?.copyWith(color: AppColors.slate);
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(amount, style: style?.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class OrderPaidAmount extends StatelessWidget {
  const OrderPaidAmount({
    super.key,
    required this.label,
    required this.amount,
    this.compact = false,
  });

  final String label;
  final double amount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = compact
        ? Theme.of(context).textTheme.bodySmall
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Icon(
          Icons.payments_outlined,
          size: compact ? 14 : 16,
          color: AppColors.stockOk,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            orderPaidCaption(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: base?.copyWith(
              color: AppColors.slate,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.stockOk.withValues(alpha: isDark ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: compact ? 1 : 2,
            ),
            child: Text(
              MoneyFormat.detailed(-amount),
              style: base?.copyWith(
                color: AppColors.stockOk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class OrderDueAmount extends StatelessWidget {
  const OrderDueAmount({super.key, required this.amount, this.compact = false});

  final double amount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final owed = amount > 0;
    final amountBase = compact
        ? Theme.of(context).textTheme.bodySmall
        : Theme.of(context).textTheme.bodyMedium;
    final amountStyle = amountBase?.copyWith(
      color: owed ? AppColors.terracotta : AppColors.stockOk,
      fontWeight: compact ? FontWeight.w700 : FontWeight.w600,
    );
    return Row(
      children: [
        Text(
          'FALTA COBRAR',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.slate,
            fontWeight: FontWeight.w700,
            letterSpacing: compact ? 0.4 : 0.6,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(MoneyFormat.detailed(amount), style: amountStyle),
            ),
          ),
        ),
      ],
    );
  }
}
