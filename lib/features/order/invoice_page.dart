import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../models/order.dart';
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
              const Text('No encontramos este pedido.'),
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
    final wide = AppBreakpoints.isWide(context);
    final issuedAt = order.closedAt ?? order.createdAt;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _leave(context, order),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    order.isClosed ? 'Factura' : 'Facturar pedido',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!order.isClosed)
                  IconButton(
                    onPressed: () => context.go('/pedido'),
                    icon: Badge(
                      isLabelVisible: store.cartCount > 0,
                      label: Text('${store.cartCount}'),
                      child: const Icon(Icons.assignment_outlined),
                    ),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                wide ? 24 : 20,
                8,
                wide ? 24 : 20,
                20,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            color: AppColors.terracotta,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'MODA STOCK',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            'RESUMEN DE FACTURA',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
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
                            DateFormatters.invoice.format(issuedAt),
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
                              Expanded(
                                flex: 2,
                                child: _th(context, 'P. UNIT.'),
                              ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line.product.name.toUpperCase(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        [
                                          if (line
                                              .product
                                              .categoryLabel
                                              .isNotEmpty)
                                            line.product.categoryLabel,
                                          'Talle ${line.variant.size}',
                                          line.variant.color,
                                        ].join(' · '),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppColors.mutedText,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${line.quantity}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    MoneyFormat.detailed(line.unitPrice),
                                    textAlign: TextAlign.right,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    MoneyFormat.detailed(line.lineTotal),
                                    textAlign: TextAlign.right,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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
                          if (order.ivaEnabled)
                            _kv(
                              context,
                              order.ivaLabel,
                              MoneyFormat.detailed(order.iva),
                            ),
                          _kv(
                            context,
                            'Total a facturar',
                            MoneyFormat.detailed(order.total),
                            emphasize: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: WhatsAppButton(order: order),
          ),
          if (!order.isClosed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: FilledButton.icon(
                onPressed: order.lines.isEmpty
                    ? null
                    : () => closeOrderFlow(context, order),
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Cerrar pedido'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: ReopenOrderButton(order: order, filled: true),
            ),
          TextButton(
            onPressed: () => _leave(context, order),
            child: Text(
              order.isClosed ? 'Volver al cliente' : 'Volver al pedido',
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _leave(BuildContext context, DraftOrder order) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    if (order.isClosed) {
      context.go('/clientes/${order.customer.id}');
      return;
    }
    context.go('/pedido/${order.id}');
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
