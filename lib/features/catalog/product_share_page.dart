import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/catalog_bindings.dart';
import '../../data/catalog_guest_store.dart';
import '../../data/share_link_access.dart';
import '../../models/share_code.dart';
import 'catalog_product_page.dart';

class ProductSharePage extends StatefulWidget {
  const ProductSharePage({super.key, required this.code});

  final String code;

  @override
  State<ProductSharePage> createState() => _ProductSharePageState();
}

class _ProductSharePageState extends State<ProductSharePage> {
  ProductShareLink? _link;
  var _resolved = false;
  var _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductSharePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) _load();
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    final code = widget.code.trim();
    if (_resolved) {
      setState(() {
        _link = null;
        _resolved = false;
      });
    }
    ShareLinkAccess? access;
    try {
      access = context.read<ShareLinkAccess>();
    } on ProviderNotFoundException {
      access = null;
    }
    final link = access == null || !isShareCode(code)
        ? null
        : await access.find(code);
    if (!mounted || gen != _loadGen) return;
    setState(() {
      _link = link;
      _resolved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    if (!_resolved || link == null) {
      return _SharePlaceholder(
        message: _resolved ? 'No encontramos esta prenda.' : null,
      );
    }
    CatalogBindings? bindings;
    try {
      bindings = context.read<CatalogBindings>();
    } on ProviderNotFoundException {
      bindings = null;
    }
    if (bindings == null) {
      return const _SharePlaceholder(message: 'No encontramos esta prenda.');
    }
    final store = bindings.storeFor(link.companyId);
    return ChangeNotifierProvider.value(
      value: store,
      child: _ResolvedShare(link: link),
    );
  }
}

class _ResolvedShare extends StatelessWidget {
  const _ResolvedShare({required this.link});

  final ProductShareLink link;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CatalogGuestStore>();
    if (store.isLoading) return const _SharePlaceholder();
    return CatalogProductPage(id: link.productId, companyId: link.companyId);
  }
}

class _SharePlaceholder extends StatelessWidget {
  const _SharePlaceholder({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: message == null
              ? const CircularProgressIndicator()
              : Text(message!),
        ),
      ),
    );
  }
}
