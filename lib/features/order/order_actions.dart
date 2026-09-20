import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/order_share.dart';
import '../../models/order.dart';
import '../../theme/tokens.dart';
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
    final occupied = {
      for (final order in store.orders) order.customer.id,
    };
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
  var current = order;
  if (current.customer.whatsappDigits.isEmpty) {
    final phone = await _askWhatsAppPhone(context, current.customer.name);
    if (phone == null || !context.mounted) return;
    final store = context.read<AppStore>();
    await store.setCustomerPhone(current.customer.id, phone);
    current = store.orderById(current.id) ?? current;
    if (current.customer.whatsappDigits.isEmpty) return;
  }
  final ok = await OrderShare.openWhatsApp(current);
  if (!context.mounted) return;
  if (!ok) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se pudo abrir WhatsApp.')));
  }
}

Future<String?> _askWhatsAppPhone(BuildContext context, String customerName) {
  return showDialog<String>(
    context: context,
    builder: (context) => _WhatsAppPhoneDialog(customerName: customerName),
  );
}

class _WhatsAppPhoneDialog extends StatefulWidget {
  const _WhatsAppPhoneDialog({required this.customerName});

  final String customerName;

  @override
  State<_WhatsAppPhoneDialog> createState() => _WhatsAppPhoneDialogState();
}

class _WhatsAppPhoneDialogState extends State<_WhatsAppPhoneDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('WhatsApp'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cargá el teléfono de ${widget.customerName} para enviar el pedido.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: '+54 9 11 0000-0000'),
            onSubmitted: (value) => Navigator.pop(context, value.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

class WhatsAppButton extends StatelessWidget {
  const WhatsAppButton({super.key, required this.order, this.outlined = false});

  final DraftOrder order;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final enabled = order.lines.isNotEmpty;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.chat, size: 18),
        SizedBox(width: 8),
        Text('Enviar por WhatsApp'),
      ],
    );
    if (outlined) {
      return OutlinedButton(
        onPressed: enabled ? () => sendOrderWhatsApp(context, order) : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.whatsapp,
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
      ),
      child: child,
    );
  }
}
