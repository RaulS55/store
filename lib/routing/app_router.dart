import 'package:go_router/go_router.dart';

import '../data/session_store.dart';
import '../features/auth/accept_invite_page.dart';
import '../features/auth/join_company_page.dart';
import '../features/auth/loading_page.dart';
import '../features/auth/sign_in_page.dart';
import '../features/auth/sign_up_page.dart';
import '../features/catalog/catalog_cart_page.dart';
import '../features/catalog/catalog_page.dart';
import '../features/catalog/catalog_product_page.dart';
import '../features/customers/customer_detail_page.dart';
import '../features/customers/customers_page.dart';
import '../features/lots/lots_page.dart';
import '../features/more/more_page.dart';
import '../features/order/invoice_page.dart';
import '../features/order/order_page.dart';
import '../features/order/orders_page.dart';
import '../features/product/product_detail_page.dart';
import '../features/product/product_form_page.dart';
import '../features/settings/settings_page.dart';
import '../features/stock/stock_page.dart';
import '../features/team/team_page.dart';
import '../widgets/app_shell.dart';

GoRouter createRouter(
  SessionStore session, {
  String initialLocation = '/',
  bool overridePlatformDefaultLocation = false,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: overridePlatformDefaultLocation,
    refreshListenable: session,
    redirect: (context, state) => sessionRedirect(session, state.uri.path),
    routes: [
      GoRoute(
        path: '/cargando',
        builder: (context, state) => const LoadingPage(),
      ),
      GoRoute(
        path: '/ingresar',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/registro',
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: '/invitar/:companyId/:invitationId',
        builder: (context, state) => AcceptInvitePage(
          companyId: state.pathParameters['companyId']!,
          invitationId: state.pathParameters['invitationId']!,
        ),
      ),
      GoRoute(
        path: '/unirse',
        builder: (context, state) => const JoinCompanyPage(),
      ),
      GoRoute(
        path: '/catalogo/:companyId',
        builder: (context, state) => const CatalogPage(),
        routes: [
          GoRoute(
            path: 'producto/:id',
            builder: (context, state) =>
                CatalogProductPage(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'pedido',
            builder: (context, state) => const CatalogCartPage(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: StockPage()),
          ),
          GoRoute(
            path: '/pedido',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: OrdersPage()),
            routes: [
              GoRoute(
                path: ':orderId',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: OrderPage(orderId: state.pathParameters['orderId']!),
                ),
                routes: [
                  GoRoute(
                    path: 'facturar',
                    pageBuilder: (context, state) => NoTransitionPage(
                      child: InvoicePage(
                        orderId: state.pathParameters['orderId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/producto/nuevo',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProductFormPage()),
          ),
          GoRoute(
            path: '/producto/:id',
            pageBuilder: (context, state) => NoTransitionPage(
              child: ProductDetailPage(id: state.pathParameters['id']!),
            ),
            routes: [
              GoRoute(
                path: 'editar',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: ProductFormPage(id: state.pathParameters['id']),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/clientes',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CustomersPage()),
            routes: [
              GoRoute(
                path: ':customerId',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: CustomerDetailPage(
                    customerId: state.pathParameters['customerId']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/montones',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: LotsPage()),
          ),
          GoRoute(
            path: '/equipo',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: TeamPage()),
          ),
          GoRoute(
            path: '/config',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsPage()),
          ),
          GoRoute(
            path: '/mas',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MorePage()),
          ),
        ],
      ),
    ],
  );
}

String? sessionRedirect(SessionStore session, String path) {
  final isLoading = path == '/cargando';
  final isCatalog = path.startsWith('/catalogo');
  final isAuth =
      path == '/ingresar' ||
      path == '/registro' ||
      path.startsWith('/invitar') ||
      path == '/unirse';

  if (!session.isReady) {
    if (isCatalog) return null;
    return isLoading ? null : '/cargando';
  }
  if (isCatalog) return null;
  final needsCompany = session.needsCompany;
  final isInvite = path.startsWith('/invitar');
  final isJoin = path == '/unirse';
  if (isLoading) {
    if (session.isSignedIn) return '/';
    if (needsCompany) return '/unirse';
    return '/ingresar';
  }
  if (session.isSignedIn) {
    if (path == '/ingresar' || path == '/registro' || isJoin || isInvite) {
      return '/';
    }
    if (path == '/equipo' && !session.canViewTeam) return '/';
    if (path == '/montones' && !session.canManageLots) return '/';
    return null;
  }
  if (needsCompany) {
    if (isJoin || isInvite) return null;
    return '/unirse';
  }
  if (isJoin) return '/ingresar';
  if (!isAuth) return '/ingresar';
  return null;
}
