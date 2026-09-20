import 'package:go_router/go_router.dart';

import '../data/session_store.dart';
import '../features/auth/accept_invite_page.dart';
import '../features/auth/join_company_page.dart';
import '../features/auth/loading_page.dart';
import '../features/auth/sign_in_page.dart';
import '../features/auth/sign_up_page.dart';
import '../features/customers/customer_detail_page.dart';
import '../features/customers/customers_page.dart';
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

GoRouter createRouter(SessionStore session) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) {
      final path = state.uri.path;
      final isLoading = path == '/cargando';
      final isAuth =
          path == '/ingresar' ||
          path == '/registro' ||
          path.startsWith('/invitar') ||
          path == '/unirse';

      if (!session.isReady) {
        return isLoading ? null : '/cargando';
      }
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
        return null;
      }
      if (needsCompany) {
        if (isJoin || isInvite) return null;
        return '/unirse';
      }
      if (isJoin) return '/ingresar';
      if (!isAuth) return '/ingresar';
      return null;
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
