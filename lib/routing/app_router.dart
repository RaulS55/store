import 'package:go_router/go_router.dart';

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
import '../widgets/app_shell.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
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
                  child: OrderPage(
                    orderId: state.pathParameters['orderId']!,
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'facturar',
                    builder: (context, state) => InvoicePage(
                      orderId: state.pathParameters['orderId']!,
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
            builder: (context, state) =>
                ProductDetailPage(id: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (context, state) =>
                    ProductFormPage(id: state.pathParameters['id']),
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
                builder: (context, state) => CustomerDetailPage(
                  customerId: state.pathParameters['customerId']!,
                ),
              ),
            ],
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
