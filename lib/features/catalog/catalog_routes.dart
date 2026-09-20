import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/catalog_bindings.dart';
import '../../data/catalog_guest_store.dart';

String catalogPath(String companyId) => '/catalogo/$companyId';

String catalogProductPath(String companyId, String productId) {
  return '/catalogo/$companyId/producto/$productId';
}

String catalogCartPath(String companyId) => '/catalogo/$companyId/pedido';

String catalogCompanyIdOf(BuildContext context) {
  return GoRouterState.of(context).pathParameters['companyId'] ?? '';
}

CatalogGuestStore catalogStoreOf(BuildContext context) {
  return context.read<CatalogBindings>().storeFor(catalogCompanyIdOf(context));
}
