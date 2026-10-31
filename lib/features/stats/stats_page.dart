import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../models/company_stats.dart';
import '../../models/expense.dart';
import '../../theme/tokens.dart';
import 'expense_sheets.dart';

enum _StatsPeriod { all, thisMonth, custom }

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  _StatsPeriod _period = _StatsPeriod.all;
  DateTimeRange? _customRange;

  ({DateTime from, DateTime to})? get _range {
    switch (_period) {
      case _StatsPeriod.all:
        return null;
      case _StatsPeriod.thisMonth:
        return currentMonthLocalRange();
      case _StatsPeriod.custom:
        final range = _customRange;
        if (range == null) return null;
        return inclusiveLocalDayRange(range.start, range.end);
    }
  }

  String get _soldSubtitle {
    final range = _range;
    if (range == null) {
      return 'Pedidos cerrados en la app.';
    }
    return 'Ventas del ${DateFormatters.short.format(range.from)} al ${DateFormatters.short.format(range.to)}.';
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final current = _customRange;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange:
          current ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      helpText: 'Rango de fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      saveText: 'Aplicar',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _period = _StatsPeriod.custom;
      _customRange = DateTimeRange(
        start: startOfLocalDay(picked.start),
        end: startOfLocalDay(picked.end),
      );
    });
  }

  void _selectPeriod(_StatsPeriod period) {
    if (period == _StatsPeriod.custom) {
      _pickCustomRange();
      return;
    }
    setState(() => _period = period);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final range = _range;
    final stats = store.statsForCompany(from: range?.from, to: range?.to);
    final wide = AppBreakpoints.isWide(context);
    final unsold = _StatCard(
      title: 'Sin vender',
      icon: Icons.inventory_2_outlined,
      subtitle: 'Stock disponible en la app.',
      units: stats.availableUnits,
      value: stats.availableValue,
      accent: AppColors.terracotta,
    );
    final reserved = _StatCard(
      title: 'Reservadas',
      icon: Icons.bookmark_outline,
      subtitle: 'Stock en pedidos abiertos.',
      units: stats.reservedUnits,
      value: stats.reservedValue,
      accent: AppColors.warning,
      paid: stats.reservedPaid,
      remaining: stats.reservedRemaining,
    );
    final sold = _StatCard(
      title: 'Vendidas',
      icon: Icons.sell_outlined,
      subtitle: _soldSubtitle,
      units: stats.soldUnits,
      value: stats.soldValue,
      accent: AppColors.stockOk,
    );
    final lots = _LotStatsCard(stats: stats);

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 24 : 20, wide ? 20 : 16, 20, 24),
        children: [
          Text(
            'Estadísticas',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Totales de prendas, lotes, otros gastos y ganancia esperada.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
          ),
          const SizedBox(height: 16),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: unsold),
                const SizedBox(width: 12),
                Expanded(child: reserved),
              ],
            )
          else ...[
            unsold,
            const SizedBox(height: 12),
            reserved,
          ],
          const SizedBox(height: 12),
          lots,
          const SizedBox(height: 12),
          _ExpensesCard(expenses: store.expenses),
          const SizedBox(height: 16),
          Text(
            'Ventas por fecha',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: const ValueKey('stats-period-all'),
                label: const Text('Todo'),
                selected: _period == _StatsPeriod.all,
                showCheckmark: false,
                onSelected: (_) => _selectPeriod(_StatsPeriod.all),
              ),
              ChoiceChip(
                key: const ValueKey('stats-period-month'),
                label: const Text('Este mes'),
                selected: _period == _StatsPeriod.thisMonth,
                showCheckmark: false,
                onSelected: (_) => _selectPeriod(_StatsPeriod.thisMonth),
              ),
              ChoiceChip(
                key: const ValueKey('stats-period-custom'),
                label: Text(_customLabel),
                selected: _period == _StatsPeriod.custom,
                showCheckmark: false,
                onSelected: (_) => _selectPeriod(_StatsPeriod.custom),
              ),
            ],
          ),
          const SizedBox(height: 12),
          sold,
        ],
      ),
    );
  }

  String get _customLabel {
    if (_period != _StatsPeriod.custom || _customRange == null) {
      return 'Elegir fechas';
    }
    final range = _customRange!;
    return '${DateFormatters.short.format(range.start)} – ${DateFormatters.short.format(range.end)}';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.units,
    required this.value,
    required this.accent,
    this.paid,
    this.remaining,
  });

  final String title;
  final IconData icon;
  final String subtitle;
  final int units;
  final double value;
  final Color accent;
  final double? paid;
  final double? remaining;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
            const SizedBox(height: 10),
            _StatLine(
              icon: Icons.numbers,
              iconColor: accent,
              label: 'Cantidad',
              value: units == 1 ? '1 unidad' : '$units unidades',
              isDark: isDark,
            ),
            _StatLine(
              icon: Icons.payments_outlined,
              iconColor: accent,
              label: 'Total',
              value: MoneyFormat.compact(value),
              isDark: isDark,
            ),
            if (paid != null && remaining != null) ...[
              _StatLine(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: accent,
                label: 'Pagado',
                value: MoneyFormat.compact(paid!),
                isDark: isDark,
              ),
              _StatLine(
                icon: Icons.savings_outlined,
                iconColor: accent,
                label: 'Restante',
                value: MoneyFormat.compact(remaining!),
                isDark: isDark,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LotStatsCard extends StatelessWidget {
  const _LotStatsCard({required this.stats});

  final CompanyStats stats;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.inventory_outlined,
                  size: 18,
                  color: AppColors.terracotta,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lotes',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Suma del precio de los lotes y ganancia esperada, con y sin otros gastos.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
            const SizedBox(height: 10),
            _StatLine(
              icon: Icons.local_offer_outlined,
              iconColor: AppColors.terracotta,
              label: 'Gasto en lotes',
              value: MoneyFormat.compact(stats.lotCost),
              isDark: isDark,
            ),
            _StatLine(
              icon: Icons.receipt_long_outlined,
              iconColor: AppColors.terracotta,
              label: 'Otros gastos',
              value: MoneyFormat.compact(stats.otherExpenses),
              isDark: isDark,
            ),
            _StatLine(
              icon: Icons.functions,
              iconColor: AppColors.terracotta,
              label: 'Ganancia esperada bruta',
              value: MoneyFormat.compact(stats.expectedGross),
              isDark: isDark,
              valueColor: _profitColor(stats.expectedGross),
            ),
            _StatLine(
              icon: Icons.savings_outlined,
              iconColor: AppColors.stockOk,
              label: 'Ganancia esperada real',
              value: MoneyFormat.compact(stats.expectedNet),
              isDark: isDark,
              valueColor: _profitColor(stats.expectedNet),
            ),
            _StatLine(
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.stockOk,
              label: 'Ganancia con otros gastos',
              value: MoneyFormat.compact(stats.expectedNetAfterExpenses),
              isDark: isDark,
              valueColor: _profitColor(stats.expectedNetAfterExpenses),
            ),
          ],
        ),
      ),
    );
  }

  Color? _profitColor(double value) {
    if (value > 0) return AppColors.stockOk;
    if (value < 0) return AppColors.stockLow;
    return null;
  }
}

class _ExpensesCard extends StatelessWidget {
  const _ExpensesCard({required this.expenses});

  final List<Expense> expenses;

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
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                  color: AppColors.terracotta,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Otros gastos',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('new-expense'),
                  onPressed: () => showExpenseForm(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Viajes, sueldos y similares. Sin tipos. Entran en la ganancia con otros gastos.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.slate),
            ),
            const SizedBox(height: 10),
            if (expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Todavía no hay otros gastos.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
                ),
              )
            else
              for (final expense in expenses) _ExpenseRow(expense: expense),
          ],
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => showExpenseForm(context, expense: expense),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      MoneyFormat.compact(expense.amount),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('delete-expense-${expense.id}'),
            tooltip: 'Eliminar',
            onPressed: () =>
                deleteExpenseWithConfirm(context: context, expense: expense),
            style: IconButton.styleFrom(foregroundColor: AppColors.stockLow),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
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
