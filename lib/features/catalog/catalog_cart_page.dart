import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/catalog_guest_store.dart';
import '../../data/formatters.dart';
import '../../data/order_share.dart';
import '../../data/session_exception.dart';
import '../../models/order.dart';
import '../../theme/tokens.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/product_image.dart';
import '../../widgets/qty_stepper.dart';
import 'catalog_routes.dart';

class CatalogCartPage extends StatelessWidget {
  const CatalogCartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = catalogStoreOf(context);
    return ChangeNotifierProvider.value(
      value: store,
      child: const _CatalogCartView(),
    );
  }
}

class _CatalogCartView extends StatefulWidget {
  const _CatalogCartView();

  @override
  State<_CatalogCartView> createState() => _CatalogCartViewState();
}

class _CatalogCartViewState extends State<_CatalogCartView> {
  late final TextEditingController _name;
  var _nameSeeded = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController()..addListener(_onNameChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nameSeeded) return;
    final stored = context.read<CatalogGuestStore>().openOrder?.customerName;
    if (stored == null || stored.length < 2) return;
    _nameSeeded = true;
    _name.text = stored;
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    super.dispose();
  }

  void _onNameChanged() => setState(() {});

  bool get _hasName => _name.text.trim().length >= 2;

  Future<void> _send() async {
    final store = context.read<CatalogGuestStore>();
    try {
      final result = await store.submit(name: _name.text);
      if (!mounted) return;
      if (result.missingPhone) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBar(
            content: Text(
              result.updated
                  ? 'Actualizamos ${result.order.orderNumber}. Este catálogo no tiene WhatsApp configurado.'
                  : 'El pedido ${result.order.orderNumber} se envió al negocio. Este catálogo no tiene WhatsApp configurado.',
            ),
          ),
        );
        return;
      }
      final ok = await OrderShare.openUri(result.whatsappUri);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const AppSnackBar(content: Text('No se pudo abrir WhatsApp.')),
        );
      }
    } on SessionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(AppSnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const AppSnackBar(content: Text('No se pudo enviar el pedido.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CatalogGuestStore>();
    final pending = store.pendingCartLines;
    final requested = store.requestedCartLines;
    final isEmpty = pending.isEmpty && requested.isEmpty;
    final canSend = store.hasPending && !store.isBusy && _hasName;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(catalogPath(store.companyId));
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tu pedido',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (store.openOrder != null)
                          Text(
                            '${store.openOrder!.orderNumber} · podés agregar más prendas',
                            key: const ValueKey('catalog-open-order'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.slate),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Todavía no hay prendas en el pedido.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        for (final line in pending)
                          _LineTile(
                            line: line,
                            max: store.pendingMaxFor(
                              line.lineKey,
                              line.variant.stock,
                            ),
                            onQty: (qty) => store.setLineQty(line.lineKey, qty),
                            onRemove: () => store.removeLine(line.lineKey),
                          ),
                        if (requested.isNotEmpty) ...[
                          if (pending.isNotEmpty) const SizedBox(height: 8),
                          const _RequestedDivider(),
                          const SizedBox(height: 12),
                          for (final line in requested)
                            _RequestedTile(line: line),
                        ],
                        const SizedBox(height: 12),
                        _CartTotals(
                          pendingTotal: store.pendingTotal,
                          cartTotal: store.cartTotal,
                          showNew: pending.isNotEmpty && requested.isNotEmpty,
                        ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('catalog-client-name'),
                    controller: _name,
                    enabled:
                        !store.isBusy &&
                        (store.hasPending || store.openOrder != null),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Tu nombre',
                      hintText: 'Para que el negocio sepa quién pide',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('catalog-send'),
                      onPressed: canSend ? _send : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.whatsapp,
                        disabledBackgroundColor: AppColors.whatsapp.withValues(
                          alpha: 0.35,
                        ),
                        foregroundColor: Colors.white,
                      ),
                      icon: store.isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chat, size: 18),
                      label: Text(
                        store.openOrder == null
                            ? 'Realizar pedido'
                            : 'Actualizar pedido',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartTotals extends StatelessWidget {
  const _CartTotals({
    required this.pendingTotal,
    required this.cartTotal,
    required this.showNew,
  });

  final double pendingTotal;
  final double cartTotal;
  final bool showNew;

  @override
  Widget build(BuildContext context) {
    final title = Theme.of(context).textTheme.titleMedium;
    return Column(
      children: [
        if (showNew)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(
                  'Nuevo',
                  style: title?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate,
                  ),
                ),
                const Spacer(),
                Text(
                  MoneyFormat.detailed(pendingTotal),
                  key: const ValueKey('catalog-new-total'),
                  style: title?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate,
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Text(
              showNew ? 'Total del pedido' : 'Total',
              style: title?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              MoneyFormat.detailed(cartTotal),
              key: const ValueKey('catalog-cart-total'),
              style: title?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.terracotta,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RequestedDivider extends StatelessWidget {
  const _RequestedDivider();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: AppColors.slate);
    return Row(
      key: const ValueKey('catalog-requested-separator'),
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Ya solicitado', style: style),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.max,
    required this.onQty,
    required this.onRemove,
  });

  final OrderLine line;
  final int max;
  final ValueChanged<int> onQty;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: ProductImage(
              path: line.product.image,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${line.variant.size} · ${line.variant.color}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  MoneyFormat.detailed(line.lineTotal),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              QtyStepper(
                value: line.quantity,
                min: 1,
                max: max < 1 ? 1 : max,
                onChanged: onQty,
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestedTile extends StatelessWidget {
  const _RequestedTile({required this.line});

  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: 0.55,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: ProductImage(
                path: line.product.image,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.product.name,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate,
                    ),
                  ),
                  Text(
                    '${line.quantity}× ${line.variant.size} · ${line.variant.color}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              MoneyFormat.detailed(line.lineTotal),
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
