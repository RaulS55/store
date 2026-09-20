import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../models/lot.dart';
import '../../models/lot_stats.dart';
import '../../theme/tokens.dart';
import 'lot_actions.dart';
import 'lot_sheets.dart';

class LotsPage extends StatelessWidget {
  const LotsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final lots = store.lots;
    final wide = AppBreakpoints.isWide(context);
    final showStats = canViewLotStats(context);
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 24 : 20, wide ? 20 : 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Montones',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      showStats
                          ? 'Costo, suma de prendas, recuperación y ganancia de cada lote.'
                          : 'Cargá el costo de la ropa por montones y asignalo a las prendas.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('new-lot'),
                onPressed: () => showLotForm(context),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo montón'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (lots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 40,
                    color: AppColors.mutedText,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Todavía no hay montones',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cargá el primer lote de costo para asignarlo a las prendas.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
                  ),
                ],
              ),
            )
          else
            for (final lot in lots)
              _LotCard(
                lot: lot,
                stats: store.statsForLot(lot),
                showStats: showStats,
              ),
        ],
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  const _LotCard({
    required this.lot,
    required this.stats,
    required this.showStats,
  });

  final Lot lot;
  final LotStats stats;
  final bool showStats;

  @override
  Widget build(BuildContext context) {
    final assigned = stats.productCount == 1
        ? '1 prenda'
        : '${stats.productCount} prendas';
    final stock = stats.stockUnits == 1
        ? '1 en stock'
        : '${stats.stockUnits} en stock';
    final quantityLabel = lot.quantity == null
        ? 'Cantidad no cargada'
        : '${lot.quantity} unidades';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lot.displayName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$quantityLabel · $assigned · $stock',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
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
                  onPressed: () =>
                      deleteLotWithConfirm(context: context, lot: lot),
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.stockLow,
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (showStats) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _StatChip('Costo', MoneyFormat.compact(lot.cost)),
                  _StatChip(
                    'Suma prendas',
                    MoneyFormat.compact(stats.retailStockValue),
                  ),
                  _StatChip('Recuperado', MoneyFormat.compact(stats.recovered)),
                  if (stats.profit >= 0)
                    _StatChip(
                      'Ganancia',
                      MoneyFormat.compact(stats.profit),
                      valueColor: AppColors.stockOk,
                    )
                  else
                    _StatChip(
                      'Falta recuperar',
                      MoneyFormat.compact(stats.remainingToRecover),
                      valueColor: AppColors.stockLow,
                    ),
                  if (lot.soldElsewhere > 0)
                    _StatChip(
                      'Otro medio',
                      MoneyFormat.compact(lot.soldElsewhere),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.mutedText),
          ),
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
