import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../theme/tokens.dart';
import 'order_actions.dart';

class InvoicePage extends StatelessWidget {
  const InvoicePage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final order = store.orderById(orderId);
    if (order == null) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Este pedido ya no está abierto.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/pedido'),
                child: const Text('Volver a pedidos'),
              ),
            ],
          ),
        ),
      );
    }
    final customer = order.customer;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/pedido/$orderId'),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    'Resumen del pedido',
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
                    child: const Icon(Icons.assignment_outlined),
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
                        'RESUMEN DE PEDIDO',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.mutedText,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _kv(context, 'Pedido #', order.orderNumber),
                      _kv(context, 'Cliente', customer.name),
                      _kv(
                        context,
                        'WhatsApp',
                        (customer.phone == null || customer.phone!.isEmpty)
                            ? '—'
                            : customer.phone!,
                      ),
                      _kv(
                        context,
                        'Fecha',
                        DateFormatters.invoice.format(DateTime.now()),
                      ),
                      _kv(
                        context,
                        'CUIT',
                        (customer.cuit == null || customer.cuit!.isEmpty)
                            ? '—'
                            : customer.cuit!,
                      ),
                      _kv(
                        context,
                        'Condición',
                        customer.taxCondition?.label ?? '—',
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
                      for (final line in order.lines) ...[
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
                                    '${line.product.category.label} · Talle ${line.variant.size} · ${line.variant.color}',
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
                        MoneyFormat.detailed(order.subtotal),
                      ),
                      _kv(
                        context,
                        'IVA (21%)',
                        MoneyFormat.detailed(order.iva),
                      ),
                      _kv(
                        context,
                        'Total',
                        MoneyFormat.detailed(order.total),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: WhatsAppButton(order: order),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FilledButton.icon(
              onPressed: order.lines.isEmpty || order.isClosed
                  ? null
                  : () => closeOrderFlow(context, order),
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('Cerrar pedido'),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/pedido/$orderId'),
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
}
