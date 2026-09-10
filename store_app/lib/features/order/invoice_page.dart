import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../models/order.dart';
import '../../theme/tokens.dart';

class InvoicePage extends StatelessWidget {
  const InvoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final customer = store.selectedCustomer;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/pedido'),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    'Facturar pedido',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => context.go('/pedido'),
                  icon: Badge(
                    isLabelVisible: store.cartCount > 0,
                    label: Text('${store.cartCount}'),
                    child: const Icon(Icons.shopping_bag_outlined),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.checkroom_outlined,
                          color: AppColors.terracotta, size: 28),
                      const SizedBox(height: 6),
                      Text(
                        'MODA STOCK',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'RESUMEN DE FACTURA',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.mutedText,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _kv(context, 'Pedido #', store.orderNumber),
                      _kv(context, 'Cliente', customer?.name ?? '—'),
                      _kv(
                        context,
                        'Fecha',
                        DateFormatters.invoice.format(DateTime.now()),
                      ),
                      _kv(context, 'CUIT', customer?.cuit ?? '—'),
                      _kv(
                        context,
                        'Condición',
                        customer?.taxCondition.label ?? '—',
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(flex: 4, child: _th(context, 'ÍTEM')),
                          Expanded(child: _th(context, 'CANT.')),
                          Expanded(flex: 2, child: _th(context, 'P. UNIT.')),
                          Expanded(flex: 2, child: _th(context, 'TOTAL')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final line in store.lines) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.product.name.toUpperCase(),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Talle ${line.variant.size} · ${line.variant.color} / ${line.variantSku}',
                                    style: Theme.of(context).textTheme.labelSmall
                                        ?.copyWith(color: AppColors.mutedText),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${line.quantity}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                MoneyFormat.detailed(line.unitPrice),
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                MoneyFormat.detailed(line.lineTotal),
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      const Divider(),
                      _kv(
                        context,
                        'Subtotal',
                        MoneyFormat.detailed(store.subtotal),
                      ),
                      _kv(
                        context,
                        'IVA (21%)',
                        MoneyFormat.detailed(store.iva),
                      ),
                      _kv(
                        context,
                        'Total a facturar',
                        MoneyFormat.detailed(store.total),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'MÉTODO DE PAGO',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.mutedText,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final method in PaymentMethod.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _PayChip(
                            method: method,
                            selected: store.paymentMethod == method,
                            onTap: () => store.setPaymentMethod(method),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FilledButton.icon(
              onPressed: store.lines.isEmpty || customer == null
                  ? null
                  : () => _confirm(context),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Confirmar y facturar'),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/pedido'),
            child: const Text('Volver al pedido'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _th(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.mutedText,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _kv(
    BuildContext context,
    String k,
    String v, {
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(k, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(
            v,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: emphasize ? AppColors.terracotta : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final store = context.read<AppStore>();
    final ok = store.confirmInvoice();
    if (!ok) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Factura emitida'),
          content: const Text(
            'El pedido se facturó con IVA 21% y el stock se actualizó.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    );
    if (context.mounted) context.go('/');
  }
}

class _PayChip extends StatelessWidget {
  const _PayChip({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (method) {
      case PaymentMethod.efectivo:
        return Icons.payments_outlined;
      case PaymentMethod.transferencia:
        return Icons.account_balance_outlined;
      case PaymentMethod.tarjeta:
        return Icons.credit_card;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: selected
                ? AppColors.terracotta
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          color: selected
              ? AppColors.terracotta.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            Icon(
              _icon,
              size: 18,
              color: selected ? AppColors.terracotta : AppColors.slate,
            ),
            const SizedBox(height: 6),
            Text(
              method.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? AppColors.terracotta : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
