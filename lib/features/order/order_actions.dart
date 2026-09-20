import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/order_share.dart';
import '../../models/order.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_confirm_dialog.dart';
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
    message:
        '¿Cancelar ${order.orderNumber}? El pedido se elimina y el cliente queda libre para uno nuevo.',
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
        const SnackBar(content: Text('No se pudo cancelar el pedido.')),
      );
      return;
    }
  } catch (error, stack) {
    debugPrint('Order cancel failed: $error');
    debugPrint('$stack');
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo cancelar el pedido.')),
    );
    return;
  }
  messenger.showSnackBar(const SnackBar(content: Text('Pedido cancelado')));
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
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Cerrar pedido'),
        content: const Text(
          'El pedido deja de estar activo. El stock se actualiza y queda en el historial del cliente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Aceptar'),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) return;
  final orderId = order.id;
  final ok = context.read<AppStore>().closeOrder(orderId);
  if (!ok || !context.mounted) return;
  context.go(invoiceRoute(orderId));
}

Future<void> sendOrderWhatsApp(BuildContext context, DraftOrder order) async {
  if (order.lines.isEmpty) return;
  final ok = await OrderShare.openWhatsApp(order);
  if (!context.mounted) return;
  if (!ok) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp.')));
  }
}

class WhatsAppButton extends StatelessWidget {
  const WhatsAppButton({
    super.key,
    required this.order,
    this.outlined = false,
    this.compact = false,
  });

  final DraftOrder order;
  final bool outlined;
  final bool compact;

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
    final minSize = compact ? const Size(0, 48) : const Size.fromHeight(48);
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 10)
        : null;
    final textStyle = compact
        ? Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          )
        : null;
    if (outlined) {
      return OutlinedButton(
        onPressed: enabled ? () => sendOrderWhatsApp(context, order) : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.whatsapp,
          minimumSize: minSize,
          padding: padding,
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
        textStyle: textStyle,
      ),
      child: child,
    );
  }
}
