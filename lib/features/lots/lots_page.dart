import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
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
                      'Lotes',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      showStats
                          ? 'Precio, ventas y ganancia de cada lote.'
                          : 'Cargá el costo de la ropa por lotes y asignalo a las prendas.',
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
                label: const Text('Nuevo lote'),
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
                    'Todavía no hay lotes',
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
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(
                    lot.name.trim().isEmpty ? 'Lote' : lot.name.trim(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(lot.dateLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/lotes/${lot.id}'),
                ),
              ),
        ],
      ),
    );
  }
}
