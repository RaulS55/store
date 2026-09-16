import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/session_store.dart';
import '../../models/customer.dart';
import '../../widgets/app_confirm_dialog.dart';

bool canDeleteCustomer(BuildContext context) {
  return context.watch<SessionStore?>()?.canDeleteCustomer ?? false;
}

Future<void> deleteCustomerWithConfirm({
  required BuildContext context,
  required Customer customer,
}) async {
  final confirmed = await showAppConfirmDialog(
    context: context,
    title: 'Eliminar cliente',
    message: '¿Eliminar ${customer.name}? Los pedidos del cliente se mantienen en el historial.',
    confirmLabel: 'Eliminar',
  );
  if (!confirmed || !context.mounted) return;
  try {
    await context.read<AppStore>().deleteCustomer(customer.id);
  } catch (error, stack) {
    debugPrint('Customer delete failed: $error');
    debugPrint('$stack');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo eliminar el cliente.')),
    );
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Cliente eliminado')));
  context.go('/clientes');
}
