import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/session_store.dart';
import '../../models/lot.dart';
import '../../widgets/app_confirm_dialog.dart';

bool canManageLots(BuildContext context) {
  return context.watch<SessionStore?>()?.canManageLots ?? false;
}

bool canViewLotStats(BuildContext context) {
  return context.watch<SessionStore?>()?.canViewLotStats ?? false;
}

Future<void> deleteLotWithConfirm({
  required BuildContext context,
  required Lot lot,
}) async {
  final confirmed = await showAppConfirmDialog(
    context: context,
    title: 'Eliminar lote',
    message:
        '¿Eliminar ${lot.displayName}? Las prendas asignadas quedan sin lote.',
    confirmLabel: 'Eliminar',
  );
  if (!confirmed || !context.mounted) return;
  try {
    await context.read<AppStore>().deleteLot(lot.id);
  } catch (error, stack) {
    debugPrint('Lot delete failed: $error');
    debugPrint('$stack');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo eliminar el lote.')),
    );
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Lote eliminado')));
}
