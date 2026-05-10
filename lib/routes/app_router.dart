import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/core/layout/main_scaffold.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import 'package:shareco/di/injector.dart';
import 'package:shareco/features/auth/presentation/screen/auth_callback_screen.dart';
import 'package:shareco/features/chat/presentation/screen/chat_screen.dart';
import 'package:shareco/features/ecommerce/address/domain/entities/shipping_address.dart';
import 'package:shareco/features/ecommerce/address/presentation/screen/address_form_screen.dart';
import 'package:shareco/features/ecommerce/address/presentation/screen/address_list_screen.dart';
import 'package:shareco/features/ecommerce/cart/presentation/screen/cart_screen.dart';
import 'package:shareco/features/ecommerce/checkout/presentation/screen/checkout_screen.dart';
import 'package:shareco/features/ecommerce/checkout/domain/entities/direct_order_args.dart';
import 'package:shareco/features/ecommerce/order/presentation/screen/order_detail_screen.dart';
import 'package:shareco/features/ecommerce/order/presentation/screen/order_list_screen.dart';
import 'package:shareco/features/ecommerce/product/presentation/screen/product_detail_screen.dart';
import 'package:shareco/features/ecommerce/product/presentation/screen/product_list_screen.dart';
import 'package:shareco/features/ecommerce/review/presentation/screen/review_form_screen.dart';
import 'package:shareco/features/ecommerce/shop/presentation/screen/shop_profile_screen.dart';
import 'package:shareco/features/ecommerce/shop/presentation/screen/seller_registration_screen.dart';
import 'package:shareco/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:shareco/features/feed/presentation/screen/feed_screen.dart';
import 'package:shareco/features/profile/presentation/screen/profile_screen.dart';
import 'package:shareco/features/video/presentation/screen/create_video_screen.dart';

class Routes {
  static const login = "/login";
  static const register = "/register";
  static const feed = "/feed";
  static const profile = "/profile";
  static const profileDetail = "/profile/:id";

  static String profileOf(String id) => "$profile/$id";
  static const video = "/video";
  static const post = "/post";
  static const chat = "/chat";
  static const create = "/create";
  static const discover = "/discover";
  static const ecommerce = "/ecommerce";
  static const productDetail = "/products/:id";
  static const cart = "/cart";
  static const checkout = "/checkout";
  static const orders = "/orders";
  static const orderDetail = "/orders/:id";
  static const addresses = "/addresses";
  static const addressCreate = "/addresses/new";
  static const addressEdit = "/addresses/:id/edit";
  static const shopProfile = "/shop/:id";
  static const reviewForm = "/review/new";
  static const registerSeller = "/register-seller";
}

class AppRouter {
  static GoRouter router(AuthNotifier authNotifier) => GoRouter(
    refreshListenable: authNotifier,
    initialLocation: Routes.feed,
    routes: [
      GoRoute(
        path: '/login-callback',
        builder: (_, state) => AuthCallbackScreen(uri: state.uri),
      ),
      GoRoute(
        path: Routes.create,
        builder: (_, _) => const CreateVideoScreen(),
      ),
      GoRoute(
        path: Routes.productDetail,
        builder: (_, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.cart, builder: (_, _) => const CartScreen()),
      GoRoute(
        path: Routes.checkout,
        builder: (_, state) => CheckoutScreen(
          directOrderArgs: state.extra is DirectOrderArgs
              ? state.extra as DirectOrderArgs
              : null,
        ),
      ),
      GoRoute(path: Routes.orders, builder: (_, _) => const OrderListScreen()),
      GoRoute(
        path: Routes.orderDetail,
        builder: (_, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.addresses,
        builder: (_, _) => const AddressListScreen(),
      ),
      GoRoute(
        path: Routes.addressCreate,
        builder: (_, _) => const AddressFormScreen(),
      ),
      GoRoute(
        path: Routes.addressEdit,
        builder: (_, state) => AddressFormScreen(
          address: state.extra is ShippingAddress
              ? state.extra as ShippingAddress
              : null,
        ),
      ),
      GoRoute(
        path: Routes.shopProfile,
        builder: (_, state) =>
            ShopProfileScreen(shopId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.registerSeller,
        builder: (_, _) => const SellerRegistrationScreen(),
      ),
      GoRoute(
        path: Routes.reviewForm,
        builder: (_, state) {
          final item = state.extra;
          if (item == null) return const SizedBox.shrink();
          return ReviewFormScreen(
            orderItem: item as dynamic,
          ); // Using dynamic to avoid importing OrderItem here, or I can import it.
        },
      ),

      GoRoute(
        path: Routes.create,
        builder: (_, _) => const CreateVideoScreen(),
      ),
      GoRoute(
        path: Routes.profileDetail,
        builder: (_, state) {
          final uid = state.pathParameters['id'] ?? '';
          return ProfileScreen(userId: uid);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.feed,
                builder: (_, _) => BlocProvider(
                  create: (_) => sl<FeedBloc>(),
                  child: const FeedScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ecommerce,
                builder: (_, state) => ProductListScreen(
                  brand: state.uri.queryParameters['brand'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.chat, builder: (_, _) => const ChatScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) {
                  final uid = authNotifier.userId ?? '';
                  return ProfileScreen(userId: uid);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
