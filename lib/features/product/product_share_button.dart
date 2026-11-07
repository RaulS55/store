import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/product_share.dart';
import '../../data/session_store.dart';
import '../../models/product.dart';
import '../catalog/catalog_routes.dart';
import '../../widgets/app_snack_bar.dart';

class ShareProductButton extends StatefulWidget {
  const ShareProductButton({
    super.key,
    required this.product,
    this.companyId,
    this.share = shareProductLink,
  });

  final Product product;
  final String? companyId;
  final ProductLinkSharer share;

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
    _busy = true;
    var outcome = ProductShareOutcome.failed;
    try {
      final companyId =
          widget.companyId?.trim() ??
          context.read<SessionStore?>()?.companyId?.trim() ??
          '';
      if (companyId.isEmpty) {
        outcome = ProductShareOutcome.failed;
      } else {
        final url = catalogProductShareUrl(companyId, widget.product.id);
        outcome = await widget.share(
          text: productShareText(name: widget.product.name, url: url),
          url: url,
          title: widget.product.name.trim(),
          sharePositionOrigin: _origin(),
        );
      }
    } catch (error, stack) {
      debugPrint('Product share failed: $error');
      debugPrint('$stack');
    }
    _busy = false;
    if (!mounted) return;
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
      onPressed: _share,
      icon: const Icon(Icons.share_outlined),
    );
  }
}
