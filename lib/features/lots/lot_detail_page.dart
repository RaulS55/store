import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../models/lot.dart';
import '../../models/lot_stats.dart';
import '../../theme/tokens.dart';
import 'lot_actions.dart';
import 'lot_sheets.dart';

class LotDetailPage extends StatelessWidget {
  const LotDetailPage({super.key, required this.lotId});

  final String lotId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final lot = store.lotById(lotId);
    if (lot == null) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No encontramos este lote.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/lotes'),
                child: const Text('Volver a lotes'),
              ),
            ],
          ),
        ),
      );
    }

    final stats = store.statsForLot(lot);
    final showStats = canViewLotStats(context);
    final wide = AppBreakpoints.isWide(context);
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 8, wide ? 24 : 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/lotes');
                  }
                },
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lot.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.slate,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          lot.dateLabel,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.slate),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar',
                onPressed: () => showLotForm(context, lot: lot),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: ValueKey('delete-lot-${lot.id}'),
                tooltip: 'Eliminar',
                onPressed: () async {
                  await deleteLotWithConfirm(context: context, lot: lot);
                  if (!context.mounted) return;
                  if (context.read<AppStore>().lotById(lot.id) != null) return;
                  context.go('/lotes');
                },
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.stockLow,
                ),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (showStats)
            _LotStats(lot: lot, stats: stats, wide: wide)
          else
            _Section(
              title: 'Prendas',
              icon: Icons.checkroom_outlined,
              children: [
                Text(
                  _summary(lot, stats),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _summary(Lot lot, LotStats stats) {
    final quantity = lot.quantity == null
        ? 'Cantidad no cargada'
        : '${lot.quantity} unidades';
    final garments = stats.garmentUnits == 1
        ? '1 prenda'
        : '${stats.garmentUnits} prendas';
    return '$quantity · $garments';
  }
}

class _LotStats extends StatelessWidget {
  const _LotStats({required this.lot, required this.stats, required this.wide});

  final Lot lot;
  final LotStats stats;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final recoveredPercent = (100 - stats.recoveryRemainingPercent)
        .clamp(0, 100)
        .toDouble();
    final recovery = _RecoveryCard(percent: recoveredPercent);
    final garments = _Section(
      title: 'Prendas',
      icon: Icons.checkroom_outlined,
      children: [
        _GarmentBar(
          sold: stats.soldUnits,
          reserved: stats.reservedUnits,
          available: stats.availableUnits,
        ),
        const SizedBox(height: 8),
        _StatLine(
          icon: Icons.sell_outlined,
          iconColor: AppColors.stockOk,
          label: 'Vendidas',
          value: '${stats.soldUnits}',
        ),
        _StatLine(
          icon: Icons.inventory_2_outlined,
          iconColor: AppColors.terracotta,
          label: 'Sin vender',
          value: '${stats.availableUnits}',
        ),
        _StatLine(
          icon: Icons.bookmark_outline,
          iconColor: AppColors.warning,
          label: 'Reservadas',
          value: '${stats.reservedUnits}',
        ),
        _StatLine(
          icon: Icons.payments_outlined,
          label: 'Cantidad en prendas',
          value: MoneyFormat.compact(stats.garmentValue),
        ),
      ],
    );
    final money = _Section(
      title: 'Cifras',
      icon: Icons.account_balance_wallet_outlined,
      children: [
        _StatLine(
          icon: Icons.local_offer_outlined,
          label: 'Precio del lote',
          value: MoneyFormat.compact(lot.cost),
        ),
        if (stats.unitPrice != null)
          _StatLine(
            icon: Icons.sell_outlined,
            label: 'Precio unitario',
            value: MoneyFormat.compact(stats.unitPrice!),
          ),
        if (lot.soldElsewhere > 0)
          _StatLine(
            icon: Icons.storefront_outlined,
            label: 'Vendido en otro medio',
            value: MoneyFormat.compact(lot.soldElsewhere),
          ),
        _StatLine(
          icon: Icons.shopping_bag_outlined,
          iconColor: AppColors.stockOk,
          label: 'Total vendido',
          value: MoneyFormat.compact(stats.soldValue),
        ),
        _StatLine(
          icon: Icons.bookmark_added_outlined,
          iconColor: AppColors.warning,
          label: 'Total reservado',
          value: MoneyFormat.compact(stats.reservedValue),
        ),
        _StatLine(
          icon: Icons.functions,
          label: 'Total esperado',
          value: MoneyFormat.compact(stats.expectedValue),
        ),
        _StatLine(
          icon: Icons.trending_up,
          iconColor: AppColors.stockOk,
          label: 'Ganancia actual',
          value: MoneyFormat.compact(stats.currentProfit),
          valueColor: stats.currentProfit > 0 ? AppColors.stockOk : null,
        ),
        _StatLine(
          icon: Icons.savings_outlined,
          iconColor: AppColors.stockOk,
          label: 'Ganancia esperada',
          value: MoneyFormat.compact(stats.expectedProfit),
          valueColor: stats.expectedProfit > 0 ? AppColors.stockOk : null,
        ),
      ],
    );

    if (!wide) {
      return Column(
        children: [
          recovery,
          const SizedBox(height: 12),
          garments,
          const SizedBox(height: 12),
          money,
        ],
      );
    }
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: recovery),
            const SizedBox(width: 12),
            Expanded(child: garments),
          ],
        ),
        const SizedBox(height: 12),
        money,
      ],
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _RecoveryRing(percent: percent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recuperado',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Porcentaje del precio del lote ya cubierto con lo vendido en la app y por otro medio.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryRing extends StatelessWidget {
  const _RecoveryRing({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 92,
      height: 92,
      child: CustomPaint(
        painter: _RecoveryRingPainter(
          recovered: percent / 100,
          color: AppColors.stockOk,
          track: isDark ? AppColors.darkMuted : AppColors.lightMuted,
        ),
        child: Center(
          child: Text(
            '${PercentFormat.of(percent)}%',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _RecoveryRingPainter extends CustomPainter {
  const _RecoveryRingPainter({
    required this.recovered,
    required this.color,
    required this.track,
  });

  final double recovered;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = track);
    if (recovered <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * recovered.clamp(0, 1),
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RecoveryRingPainter oldDelegate) {
    return oldDelegate.recovered != recovered ||
        oldDelegate.color != color ||
        oldDelegate.track != track;
  }
}

class _GarmentBar extends StatelessWidget {
  const _GarmentBar({
    required this.sold,
    required this.reserved,
    required this.available,
  });

  final int sold;
  final int reserved;
  final int available;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = sold + reserved + available;
    final track = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: SizedBox(
        height: 12,
        child: total == 0
            ? ColoredBox(color: track)
            : Row(
                children: [
                  if (sold > 0)
                    Expanded(
                      flex: sold,
                      child: const ColoredBox(color: AppColors.stockOk),
                    ),
                  if (reserved > 0)
                    Expanded(
                      flex: reserved,
                      child: const ColoredBox(color: AppColors.warning),
                    ),
                  if (available > 0)
                    Expanded(
                      flex: available,
                      child: const ColoredBox(color: AppColors.terracotta),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.terracotta),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = iconColor ?? AppColors.terracotta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
