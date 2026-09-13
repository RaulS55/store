import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/session_store.dart';
import '../../models/product.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_confirm_dialog.dart';

bool canDeleteProduct(BuildContext context) {
  return context.watch<SessionStore?>()?.canDeleteProduct ?? false;
}

Future<void> deleteProductWithConfirm({
  required BuildContext context,
  required Product product,
}) async {
  final confirmed = await showAppConfirmDialog(
    context: context,
    title: 'Eliminar prenda',
    message:
        '¿Eliminar ${product.name}? También se borran las fotos de esta prenda.',
    confirmLabel: 'Eliminar',
  );
  if (!confirmed || !context.mounted) return;
  try {
    await context.read<AppStore>().deleteProduct(product.id);
  } catch (error, stack) {
    debugPrint('Product delete failed: $error');
    debugPrint('$stack');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo eliminar la prenda.')),
    );
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Prenda eliminada')));
  context.go('/');
}

class DeleteProductButton extends StatelessWidget {
  const DeleteProductButton({
    super.key,
    required this.product,
    this.enabled = true,
  });

  final Product product;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const ValueKey('delete-product'),
      onPressed: enabled
          ? () => deleteProductWithConfirm(context: context, product: product)
          : null,
      style: TextButton.styleFrom(foregroundColor: AppColors.stockLow),
      icon: const Icon(Icons.delete_outline, size: 18),
      label: const Text('Eliminar prenda'),
    );
  }
}
