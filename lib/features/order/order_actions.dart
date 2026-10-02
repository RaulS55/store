import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../data/order_share.dart';
import '../../models/order.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_snack_bar.dart';
import '../customers/customer_sheets.dart';

export '../customers/customer_sheets.dart' show showCustomerPicker;

Future<DraftOrder?> showOrderTargetSheet(BuildContext context) async {
  final store = context.read<AppStore>();
  final targets = store.addTargetOrders;
  final selected = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return ListView(
        children: [
          const ListTile(title: Text('¿A qué pedido lo agregamos?')),
          for (var i = 0; i < targets.length; i++)
            _OrderTargetTile(
              order: targets[i],
              preferred: i == 0 && store.lastAddedOrderId == targets[i].id,
            ),
          ListTile(
            key: const ValueKey('order-target-new'),
            leading: const Icon(Icons.add, color: AppColors.terracotta),
            title: const Text('Nuevo pedido'),
            subtitle: const Text('Elegí un cliente y creá el pedido'),
            onTap: () => Navigator.pop(context, 'new'),
          ),
        ],
      );
    },
  );
  if (!context.mounted) return null;
  if (selected is DraftOrder) {
    store.setActiveOrder(selected.id);
    return selected;
  }
  if (selected == 'new') {
    final occupied = {for (final order in store.orders) order.customer.id};
    final customer = await showCustomerPicker(
      context,
      blockedCustomerIds: occupied,
    );
    if (customer == null || !context.mounted) return null;
    return context.read<AppStore>().createOrder(customer);
  }
  return null;
}

class _OrderTargetTile extends StatelessWidget {
  const _OrderTargetTile({required this.order, required this.preferred});

  final DraftOrder order;
  final bool preferred;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('order-target-${order.id}'),
      leading: Icon(
        preferred ? Icons.history : Icons.assignment_outlined,
        color: preferred ? AppColors.terracotta : null,
      ),
      title: Text(order.customer.name),
      subtitle: Text(
        [
          order.orderNumber,
          '${order.itemCount} prendas',
          if (preferred) 'último usado',
        ].join(' · '),
      ),
      onTap: () => Navigator.pop(context, order),
    );
  }
}

String invoiceRoute(String orderId) => '/pedido/$orderId/facturar';

void openInvoice(BuildContext context, String orderId) {
  context.push(invoiceRoute(orderId));
}

Future<void> cancelOrderWithConfirm({
  required BuildContext context,
  required DraftOrder order,
}) async {
  if (!order.isActive) return;
  final confirmed = await showAppConfirmDialog(
    context: context,
    title: 'Cancelar pedido',
    message: order.stockReservations.isEmpty
        ? '¿Cancelar ${order.orderNumber}? El pedido se elimina y el cliente queda libre para uno nuevo.'
        : '¿Cancelar ${order.orderNumber}? Se libera el stock reservado y el cliente queda libre para uno nuevo.',
    confirmLabel: 'Cancelar pedido',
  );
  if (!confirmed || !context.mounted) return;
  final store = context.read<AppStore>();
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return;
  router.go('/pedido');
  try {
    final ok = await store.deleteOrder(order.id);
    if (!ok) {
      messenger.showSnackBar(
        const AppSnackBar(content: Text('No se pudo cancelar el pedido.')),
      );
      return;
    }
  } catch (error, stack) {
    debugPrint('Order cancel failed: $error');
    debugPrint('$stack');
    messenger.showSnackBar(
      const AppSnackBar(content: Text('No se pudo cancelar el pedido.')),
    );
    return;
  }
  messenger.showSnackBar(const AppSnackBar(content: Text('Pedido cancelado')));
}

class CancelOrderButton extends StatelessWidget {
  const CancelOrderButton({super.key, required this.order});

  final DraftOrder order;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const ValueKey('cancel-order'),
      onPressed: () => cancelOrderWithConfirm(context: context, order: order),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.stockLow,
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.delete_outline, size: 18),
      label: const Text('Cancelar pedido'),
    );
  }
}

Future<void> closeOrderFlow(BuildContext context, DraftOrder order) async {
  if (order.lines.isEmpty || order.isClosed) return;
  final store = context.read<AppStore>();
  final initialSena = order.sena ?? store.senaAmount;
  final sena = await showDialog<double>(
    context: context,
    builder: (context) =>
        _CloseOrderDialog(order: order, initialSena: initialSena),
  );
  if (sena == null || !context.mounted) return;
  final orderId = order.id;
  final ok = context.read<AppStore>().closeOrder(orderId, sena: sena);
  if (!context.mounted) return;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const AppSnackBar(
        content: Text('No hay stock suficiente para cerrar el pedido.'),
      ),
    );
    return;
  }
  context.go(invoiceRoute(orderId));
}

class _CloseOrderDialog extends StatefulWidget {
  const _CloseOrderDialog({required this.order, required this.initialSena});

  final DraftOrder order;
  final double initialSena;

  @override
  State<_CloseOrderDialog> createState() => _CloseOrderDialogState();
}

class _CloseOrderDialogState extends State<_CloseOrderDialog> {
  late final TextEditingController _sena;

  @override
  void initState() {
    super.initState();
    _sena = TextEditingController(
      text: MoneyFormat.grouped(widget.initialSena),
    );
  }

  @override
  void dispose() {
    _sena.dispose();
    super.dispose();
  }

  void _accept() {
    Navigator.pop(context, MoneyFormat.parse(_sena.text) ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cerrar pedido'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.order.stockNeedsSave
                ? 'El pedido deja de estar activo. El stock se actualiza y queda en el historial del cliente.'
                : 'El pedido deja de estar activo. El stock ya está reservado y queda en el historial del cliente.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('order-sena-field'),
            controller: _sena,
            keyboardType: TextInputType.number,
            inputFormatters: [MoneyFormat.inputFormatter],
            decoration: const InputDecoration(
              labelText: 'Seña',
              prefixText: '\$ ',
            ),
            onSubmitted: (_) => _accept(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _accept,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

Future<void> reopenOrderFlow(BuildContext context, DraftOrder order) async {
  if (!order.isClosed) return;
  final confirmed = await showAppConfirmDialog(
    context: context,
    title: 'Reabrir pedido',
    message:
        'El pedido vuelve a estar activo. El stock reservado se mantiene y podés modificar las prendas.',
    confirmLabel: 'Reabrir pedido',
    icon: Icons.lock_open_outlined,
    destructive: false,
  );
  if (!confirmed || !context.mounted) return;
  final orderId = order.id;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.maybeOf(context);
  final result = context.read<AppStore>().reopenOrder(orderId);
  if (!context.mounted) return;
  switch (result) {
    case ReopenOrderResult.reopened:
      messenger.showSnackBar(
        const AppSnackBar(
          content: Text('Pedido reabierto. El stock sigue reservado.'),
        ),
      );
      router?.go('/pedido/$orderId');
    case ReopenOrderResult.customerBusy:
      messenger.showSnackBar(
        const AppSnackBar(
          content: Text(
            'Este cliente ya tiene un pedido abierto. Cerralo o cancelalo para reabrir este.',
          ),
        ),
      );
    case ReopenOrderResult.unchanged:
      return;
  }
}

class ReopenOrderButton extends StatelessWidget {
  const ReopenOrderButton({
    super.key,
    required this.order,
    this.filled = false,
    this.dense = false,
  });

  final DraftOrder order;
  final bool filled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    void onPressed() => reopenOrderFlow(context, order);
    const child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text('Reabrir pedido'),
    );
    final minSize = dense ? const Size(0, 40) : const Size.fromHeight(48);
    final tapTarget = dense
        ? MaterialTapTargetSize.shrinkWrap
        : MaterialTapTargetSize.padded;
    if (filled) {
      return FilledButton.icon(
        key: const ValueKey('reopen-order'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          tapTargetSize: tapTarget,
          visualDensity: dense ? VisualDensity.compact : null,
        ),
        icon: const Icon(Icons.lock_open_outlined, size: 18),
        label: child,
      );
    }
    return OutlinedButton.icon(
      key: const ValueKey('reopen-order'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: minSize,
        tapTargetSize: tapTarget,
        visualDensity: dense ? VisualDensity.compact : null,
      ),
      icon: const Icon(Icons.lock_open_outlined, size: 18),
      label: child,
    );
  }
}

Future<void> saveOrderStockFlow(BuildContext context, DraftOrder order) async {
  if (!order.stockNeedsSave) return;
  final result = context.read<AppStore>().saveOrderStock(order.id);
  if (!context.mounted) return;
  final message = switch (result) {
    SaveStockResult.saved => 'Stock reservado. El disponible ya se actualizó.',
    SaveStockResult.unchanged => 'El stock ya estaba actualizado.',
    SaveStockResult.insufficient =>
      'No hay stock suficiente para reservar estas cantidades.',
  };
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(AppSnackBar(content: Text(message)));
}

Future<void> resetOrderStockFlow(BuildContext context, DraftOrder order) async {
  if (order.stockNeedsSave || order.stockReservations.isEmpty) return;
  final confirmed = await showAppConfirmDialog(
    context: context,
    title: 'Restablecer stock',
    message:
        'La reserva de stock de este pedido se va a quitar y volverá a estar disponible.',
    confirmLabel: 'Aceptar',
    icon: Icons.inventory_2_outlined,
  );
  if (!confirmed || !context.mounted) return;
  final ok = context.read<AppStore>().resetOrderStock(order.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    AppSnackBar(
      content: Text(
        ok
            ? 'La reserva se quitó. El stock volvió a estar disponible.'
            : 'No se pudo restablecer el stock.',
      ),
    ),
  );
}

Future<void> sendOrderWhatsApp(BuildContext context, DraftOrder order) async {
  if (order.lines.isEmpty) return;
  final includeProductCode = context
      .read<AppStore>()
      .includeProductCodeInInvoice;
  final ok = await OrderShare.openWhatsApp(
    order,
    includeProductCode: includeProductCode,
  );
  if (!context.mounted) return;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const AppSnackBar(content: Text('No se pudo abrir WhatsApp.')),
    );
  }
}

class WhatsAppButton extends StatelessWidget {
  const WhatsAppButton({
    super.key,
    required this.order,
    this.outlined = false,
    this.compact = false,
    this.dense = false,
  });

  final DraftOrder order;
  final bool outlined;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = order.lines.isNotEmpty;
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat, size: 18),
          const SizedBox(width: 6),
          Text(compact ? 'WhatsApp' : 'Enviar por WhatsApp'),
        ],
      ),
    );
    final minSize = dense
        ? const Size(0, 40)
        : compact
        ? const Size(0, 48)
        : const Size.fromHeight(48);
    final padding = compact || dense
        ? const EdgeInsets.symmetric(horizontal: 8)
        : null;
    final textStyle = compact || dense
        ? Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)
        : null;
    if (outlined) {
      return OutlinedButton(
        onPressed: enabled ? () => sendOrderWhatsApp(context, order) : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.whatsapp,
          minimumSize: minSize,
          padding: padding,
          tapTargetSize: dense ? MaterialTapTargetSize.shrinkWrap : null,
          visualDensity: dense ? VisualDensity.compact : null,
          textStyle: textStyle,
          side: BorderSide(
            color: enabled ? AppColors.whatsapp : AppColors.lightBorder,
          ),
        ),
        child: child,
      );
    }
    return FilledButton(
      onPressed: enabled ? () => sendOrderWhatsApp(context, order) : null,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.whatsapp,
        disabledBackgroundColor: AppColors.whatsapp.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
        minimumSize: minSize,
        padding: padding,
        tapTargetSize: dense ? MaterialTapTargetSize.shrinkWrap : null,
        visualDensity: dense ? VisualDensity.compact : null,
        textStyle: textStyle,
      ),
      child: child,
    );
  }
}
