import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/product_share.dart';
import '../../data/session_store.dart';
import '../../data/share_link_access.dart';
import '../../models/product.dart';
import '../../widgets/app_snack_bar.dart';

class ShareProductButton extends StatefulWidget {
  const ShareProductButton({
    super.key,
    required this.product,
    this.share = shareProductLink,
    this.random,
  });

  final Product product;
  final ProductLinkSharer share;
  final Random? random;

  @override
  State<ShareProductButton> createState() => _ShareProductButtonState();
}

class _ShareProductButtonState extends State<ShareProductButton> {
  var _busy = false;

  Rect? _origin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    var outcome = ProductShareOutcome.failed;
    try {
      final companyId = context.read<SessionStore?>()?.companyId?.trim() ?? '';
      ShareLinkAccess? links;
      try {
        links = context.read<ShareLinkAccess>();
      } on ProviderNotFoundException {
        links = null;
      }
      if (companyId.isEmpty || links == null) {
        outcome = ProductShareOutcome.failed;
      } else {
        final code = await ensureProductShareCode(
          companyId: companyId,
          product: widget.product,
          links: links,
          saveProduct: context.read<AppStore>().upsertProduct,
          random: widget.random,
        );
        if (code != null && mounted) {
          final url = productShareUrl(code);
          outcome = await widget.share(
            text: productShareText(name: widget.product.name, url: url),
            url: url,
            title: widget.product.name.trim(),
            sharePositionOrigin: _origin(),
          );
        }
      }
    } catch (error, stack) {
      debugPrint('Product share failed: $error');
      debugPrint('$stack');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final message = switch (outcome) {
      ProductShareOutcome.shared => null,
      ProductShareOutcome.copied => 'Copiamos el enlace.',
      ProductShareOutcome.failed => 'No se pudo compartir la prenda.',
    };
    if (message == null) return;
    AppSnackBar.show(context, content: Text(message));
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('share-product'),
      tooltip: 'Compartir prenda',
      onPressed: _busy ? null : _share,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.share_outlined),
    );
  }
}
