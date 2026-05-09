import 'package:go_router/go_router.dart';
import 'package:shareco/features/ecommerce/admin/presentation/screen/admin_shops_screen.dart';
import 'package:shareco/features/ecommerce/admin/presentation/screen/admin_products_screen.dart';
import 'package:shareco/features/ecommerce/admin/presentation/screen/admin_product_form_screen.dart';
import 'package:shareco/features/ecommerce/admin/presentation/screen/admin_orders_screen.dart';

class AdminRouter {
  static const String shops = '/shops';
  static const String products = '/products';
  static const String productCreate = '/products/new';
  static const String productEdit = '/products/:id/edit';
  static const String orders = '/orders';

  static final GoRouter router = GoRouter(
    initialLocation: shops,
    routes: [
      GoRoute(
        path: shops,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AdminShopsScreen(),
        ),
      ),
      GoRoute(
        path: products,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AdminProductsScreen(),
        ),
      ),
      GoRoute(
        path: productCreate,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AdminProductFormScreen(),
        ),
      ),
      GoRoute(
        path: productEdit,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return NoTransitionPage(
            child: AdminProductFormScreen(productId: id),
          );
        },
      ),
      GoRoute(
        path: orders,
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AdminOrdersScreen(),
        ),
      ),
    ],
  );
}
