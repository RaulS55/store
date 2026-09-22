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
import '../features/lots/lot_detail_page.dart';
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
  var savedLocation = _resumeLocation(initialLocation);
  return GoRouter(
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: overridePlatformDefaultLocation,
    refreshListenable: session,
    redirect: (context, state) {
      final path = state.uri.path.isEmpty ? '/' : state.uri.path;
      if (!session.isReady) {
        if (!path.startsWith('/catalogo') && path != '/cargando') {
          savedLocation = _locationFromUri(state.uri);
        }
        return sessionRedirect(session, path);
      }
      if (path == '/cargando') {
        return sessionRedirect(session, path, resume: savedLocation);
      }
      savedLocation = null;
      return sessionRedirect(session, path);
    },
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
            path: '/lotes',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: LotsPage()),
            routes: [
              GoRoute(
                path: ':lotId',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: LotDetailPage(lotId: state.pathParameters['lotId']!),
                ),
              ),
            ],
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

String? sessionRedirect(SessionStore session, String path, {String? resume}) {
  final isLoading = path == '/cargando';
  final isCatalog = path.startsWith('/catalogo');
  final isAuth = _isAuthPath(path);

  if (!session.isReady) {
    if (isCatalog) return null;
    return isLoading ? null : '/cargando';
  }
  if (isCatalog) return null;
  final needsCompany = session.needsCompany;
  final isInvite = path.startsWith('/invitar');
  final isJoin = path == '/unirse';
  if (isLoading) {
    if (session.isSignedIn) return _resumeLocation(resume) ?? '/';
    if (needsCompany) return '/unirse';
    return '/ingresar';
  }
  if (session.isSignedIn) {
    if (path == '/ingresar' || path == '/registro' || isJoin || isInvite) {
      return '/';
    }
    if (path == '/equipo' && !session.canViewTeam) return '/';
    if ((path == '/montones' || path.startsWith('/lotes')) &&
        !session.canManageLots) {
      return '/';
    }
    if (path == '/montones') return '/lotes';
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

bool _isAuthPath(String path) {
  return path == '/ingresar' ||
      path == '/registro' ||
      path == '/unirse' ||
      path.startsWith('/invitar');
}

String _locationFromUri(Uri uri) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  if (!uri.hasQuery) return path;
  return '$path?${uri.query}';
}

String? _resumeLocation(String? resume) {
  if (resume == null) return null;
  final value = resume.trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  final path = uri.path;
  if (!path.startsWith('/') || path == '/' || path == '/cargando') return null;
  if (_isAuthPath(path)) return null;
  return value;
}
