import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/catalog_guest_store.dart';
import '../../data/formatters.dart';
import '../../data/order_share.dart';
import '../../data/session_exception.dart';
import '../../models/order.dart';
import '../../theme/tokens.dart';
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

  @override
  void initState() {
    super.initState();
    _name = TextEditingController()..addListener(_onNameChanged);
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
      _name.clear();
      if (result.missingPhone) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El pedido se envió al negocio. Este catálogo no tiene WhatsApp configurado.',
            ),
          ),
        );
        return;
      }
      final ok = await OrderShare.openUri(result.whatsappUri);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
        );
      }
    } on SessionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el pedido.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CatalogGuestStore>();
    final lines = store.cartLines;
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
                    child: Text(
                      'Tu pedido',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: lines.isEmpty
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
                        for (final line in lines)
                          _LineTile(
                            line: line,
                            onQty: (qty) => store.setLineQty(line.lineKey, qty),
                            onRemove: () => store.removeLine(line.lineKey),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Total',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Text(
                              MoneyFormat.detailed(store.cartTotal),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.terracotta,
                                  ),
                            ),
                          ],
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
                    enabled: lines.isNotEmpty && !store.isBusy,
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
                      onPressed: lines.isEmpty || store.isBusy || !_hasName
                          ? null
                          : _send,
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
                      label: const Text('Enviar por WhatsApp'),
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

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.onQty,
    required this.onRemove,
  });

  final OrderLine line;
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
                max: line.variant.stock,
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
