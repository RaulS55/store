import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/lot.dart';
import '../../theme/tokens.dart';
import '../../widgets/search_field.dart';
import 'lot_actions.dart';
import 'lot_sheets.dart';

class LotsPage extends StatefulWidget {
  const LotsPage({super.key});

  @override
  State<LotsPage> createState() => _LotsPageState();
}

class _LotsPageState extends State<LotsPage> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final query = _search.text.trim().toLowerCase();
    final lots = [
      for (final lot in store.lots)
        if (_matchesLotQuery(lot, query)) lot,
    ];
    final wide = AppBreakpoints.isWide(context);
    final showStats = canViewLotStats(context);
    final hPad = wide ? 24.0 : 20.0;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, wide ? 20 : 16, hPad, 8),
            child: wide
                ? Row(
                    children: [
                      Expanded(child: _title(context, showStats)),
                      SizedBox(width: 360, child: _searchField()),
                      const SizedBox(width: 8),
                      _newLotButton(context),
                    ],
                  )
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _title(context, showStats)),
                          _newLotButton(context),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _searchField(),
                    ],
                  ),
          ),
          Expanded(
            child: lots.isEmpty
                ? _EmptyLots(searching: query.isNotEmpty)
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
                    itemCount: lots.length,
                    itemBuilder: (context, index) {
                      final lot = lots[index];
                      return Card(
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _title(BuildContext context, bool showStats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lotes',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
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
    );
  }

  Widget _searchField() {
    return SearchField(
      key: const ValueKey('lots-search'),
      controller: _search,
      hint: 'Buscar lote o fecha...',
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _newLotButton(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey('new-lot'),
      onPressed: () => showLotForm(context),
      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Nuevo lote'),
    );
  }
}

bool _matchesLotQuery(Lot lot, String query) {
  if (query.isEmpty) return true;
  if (lot.displayName.toLowerCase().contains(query)) return true;
  if (lot.dateLabel.contains(query)) return true;
  return false;
}

class _EmptyLots extends StatelessWidget {
  const _EmptyLots({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.inventory_2_outlined,
              size: 40,
              color: AppColors.mutedText,
            ),
            const SizedBox(height: 12),
            Text(
              searching ? 'No encontramos lotes' : 'Todavía no hay lotes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              searching
                  ? 'Probá con otro nombre o fecha.'
                  : 'Cargá el primer lote de costo para asignarlo a las prendas.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}
