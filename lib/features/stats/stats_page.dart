import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../models/company_stats.dart';
import '../../theme/tokens.dart';

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
    final garments = _StatCard(
      title: 'En prendas',
      icon: Icons.checkroom_outlined,
      subtitle: stats.reservedUnits == 0
          ? 'Stock actual en la app.'
          : 'Stock actual, incluye ${stats.reservedUnits} reservada${stats.reservedUnits == 1 ? '' : 's'}.',
      units: stats.garmentUnits,
      value: stats.garmentValue,
      accent: AppColors.terracotta,
    );
    final sold = _StatCard(
      title: 'Vendido',
      icon: Icons.sell_outlined,
      subtitle: _soldSubtitle,
      units: stats.soldUnits,
      value: stats.soldValue,
      accent: AppColors.stockOk,
    );

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
            'Total en prendas y ventas registradas en la app.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.slate),
          ),
          const SizedBox(height: 16),
          garments,
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
  });

  final String title;
  final IconData icon;
  final String subtitle;
  final int units;
  final double value;
  final Color accent;

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
          ],
        ),
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
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;

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
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
