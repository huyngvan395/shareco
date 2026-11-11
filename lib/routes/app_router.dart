import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shareco/core/constants/app_colors.dart';
import 'package:shareco/core/helpers/require_auth.dart';
import 'package:shareco/core/layout/main_scaffold.dart';
import 'package:shareco/core/navigation/app_route_observer.dart';
import 'package:shareco/core/notifier/auth_notifier.dart';
import 'package:shareco/di/injector.dart';
import 'package:shareco/features/auth/presentation/screen/auth_callback_screen.dart';
import 'package:shareco/features/chat/domain/entities/chat_entities.dart';
import 'package:shareco/features/chat/presentation/screen/chat_screen.dart';
import 'package:shareco/features/chat/presentation/screen/message_screen.dart';
import 'package:shareco/features/ecommerce/address/domain/entities/shipping_address.dart';
import 'package:shareco/features/ecommerce/address/presentation/screen/address_form_screen.dart';
import 'package:shareco/features/ecommerce/address/presentation/screen/address_list_screen.dart';
import 'package:shareco/features/ecommerce/cart/presentation/screen/cart_screen.dart';
import 'package:shareco/features/ecommerce/checkout/domain/entities/direct_order_args.dart';
import 'package:shareco/features/ecommerce/checkout/presentation/screen/checkout_screen.dart';
import 'package:shareco/features/ecommerce/order/presentation/screen/order_detail_screen.dart';
import 'package:shareco/features/ecommerce/order/presentation/screen/order_list_screen.dart';
import 'package:shareco/features/ecommerce/product/domain/entities/product.dart';
import 'package:shareco/features/ecommerce/product/presentation/screen/product_detail_screen.dart';
import 'package:shareco/features/ecommerce/product/presentation/screen/product_list_screen.dart';
import 'package:shareco/features/ecommerce/review/presentation/screen/review_form_screen.dart';
import 'package:shareco/features/ecommerce/shop/presentation/screen/seller_center_screen.dart';
import 'package:shareco/features/ecommerce/shop/presentation/screen/seller_product_form_screen.dart';
import 'package:shareco/features/ecommerce/shop/presentation/screen/seller_registration_screen.dart';
import 'package:shareco/features/ecommerce/shop/presentation/screen/shop_profile_screen.dart';
import 'package:shareco/features/feed/presentation/bloc/feed_bloc.dart';
import 'package:shareco/features/feed/presentation/bloc/search_bloc.dart';
import 'package:shareco/features/feed/presentation/screen/feed_screen.dart';
import 'package:shareco/features/feed/presentation/screen/search_feed_screen.dart';
import 'package:shareco/features/feed/presentation/screen/search_screen.dart';
import 'package:shareco/features/notification/presentation/screen/notification_screen.dart';
import 'package:shareco/features/profile/presentation/screen/profile_screen.dart';
import 'package:shareco/features/profile/presentation/screen/saved_videos_screen.dart';
import 'package:shareco/features/profile/presentation/screen/settings_privacy_screen.dart';
import 'package:shareco/features/video/domain/entities/video_entity.dart';
import 'package:shareco/features/video/domain/repositories/video_repository.dart';
import 'package:shareco/features/video/presentation/screen/create_video_screen.dart';
import 'package:shareco/features/video/presentation/screen/livestream_screen.dart';
import 'package:shareco/features/wallet/presentation/screen/wallet_screen.dart';

class Routes {
  static const login = "/login";
  static const register = "/register";
  static const feed = "/feed";
  static const searchFeed = "/search-feed";
  static const searchFeedViewer = "/search-feed-viewer";
  static const profile = "/profile";
  static const profileDetail = "/profile/:id";

  static String profileOf(String id) => "$profile/$id";
  static const video = "/video";
  static const post = "/post";
  static const chat = "/chat";
  static const create = "/create";
  static const discover = "/discover";
  static const messages = "/messages";
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
  static const sellerCenter = "/seller-center";
  static const sellerProductForm = "/seller/product-form";
  static const wallet = "/wallet";
  static const livestream = "/livestream";
  static const notifications = "/notifications";
  static const savedVideos = "/saved-videos";
  static const settings = "/settings";
}

class AppRouter {
  static bool _isProtectedLocation(String loc) {
    if (loc == Routes.profile ||
        loc == Routes.chat ||
        loc == Routes.messages ||
        loc == Routes.create ||
        loc == Routes.cart ||
        loc == Routes.checkout ||
        loc == Routes.registerSeller ||
        loc == Routes.sellerCenter ||
        loc.startsWith(Routes.sellerCenter) ||
        loc == Routes.sellerProductForm ||
        loc == Routes.wallet ||
        loc == Routes.livestream ||
        loc == Routes.notifications ||
        loc == Routes.savedVideos ||
        loc == Routes.reviewForm) {
      return true;
    }
    if (loc.startsWith(Routes.orders) || loc.startsWith(Routes.addresses)) {
      return true;
    }
    return false;
  }

  static GoRouter router(AuthNotifier authNotifier) => GoRouter(
    observers: [routeObserver],
    refreshListenable: authNotifier,
    initialLocation: Routes.feed,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!authNotifier.isAuthenticated && _isProtectedLocation(loc)) {
        return Routes.feed;
      }
      return null;
    },
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
        path: Routes.sellerCenter,
        builder: (_, state) {
          final extra = state.extra;
          String? shopId;
          int initialTab = 0;
          if (extra is Map<String, dynamic>) {
            shopId = extra['shopId'] as String?;
            initialTab = (extra['initialTab'] as int?) ?? 0;
          } else if (extra is String) {
            shopId = extra;
          }
          return SellerCenterScreen(
            initialShopId: shopId,
            initialTabIndex: initialTab,
          );
        },
      ),
      GoRoute(
        path: Routes.sellerProductForm,
        builder: (_, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return SellerProductFormScreen(
              shopId: extra['shopId'] as String,
              shopName: extra['shopName'] as String?,
              product: extra['product'] as Product?,
            );
          }
          return const SizedBox.shrink();
        },
      ),
      GoRoute(
        path: Routes.wallet,
        builder: (_, _) => const WalletScreen(),
      ),
      GoRoute(
        path: Routes.livestream,
        builder: (_, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return LivestreamScreen(
              channelName: (extra['channelName'] as String?) ?? '',
              isHost: (extra['isHost'] as bool?) ?? false,
              livestreamId: extra['livestreamId'] as String?,
            );
          }
          return LivestreamScreen(
            channelName: 'live_${DateTime.now().millisecondsSinceEpoch}',
            isHost: true,
          );
        },
      ),
      GoRoute(
        path: Routes.notifications,
        builder: (_, state) => NotificationScreen(
          initialCategory: state.uri.queryParameters['category'] ?? 'all',
        ),
      ),
      GoRoute(
        path: Routes.savedVideos,
        builder: (_, _) => const SavedVideosScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const SettingsPrivacyScreen(),
      ),
      GoRoute(
        path: Routes.reviewForm,
        builder: (_, state) {
          final item = state.extra;
          if (item == null) return const SizedBox.shrink();
          return ReviewFormScreen(
            orderItem: item as dynamic,
          );
        },
      ),
      GoRoute(
        path: Routes.profileDetail,
        builder: (_, state) {
          final uid = state.pathParameters['id'] ?? '';
          return ProfileScreen(
            key: ValueKey('profile_detail_$uid'),
            userId: uid,
          );
        },
      ),
      GoRoute(
        path: Routes.messages,
        builder: (_, state) {
          final conversation = state.extra;
          return MessageScreen(
            conversation: conversation as ConversationEntity,
          );
        },
      ),
      GoRoute(
        path: Routes.searchFeed,
        builder: (context, _) {
          return BlocProvider(
            create: (_) => SearchBloc(
              videoRepository: sl<VideoRepository>(),
            ),
            child: const SearchScreen(),
          );
        },
      ),
      GoRoute(
        path: Routes.searchFeedViewer,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return SearchFeedScreen(
            videos: extra['videos'] as List<VideoEntity>,
            initialIndex: extra['initialIndex'] as int,
          );
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
              GoRoute(
                path: Routes.chat,
                builder: (_, _) => ListenableBuilder(
                  listenable: authNotifier,
                  builder: (context, _) {
                    final uid = authNotifier.userId;
                    if (uid == null || uid.isEmpty) {
                      return const _GuestTabPlaceholder(
                        icon: Icons.mail_outline_rounded,
                        title: 'Hộp thư tin nhắn',
                        subtitle:
                            'Đăng nhập để xem và trò chuyện cùng bạn bè, người bán hàng.',
                      );
                    }
                    return ChatScreen(key: ValueKey('chat_$uid'));
                  },
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => ListenableBuilder(
                  listenable: authNotifier,
                  builder: (context, _) {
                    final uid = authNotifier.userId;
                    if (uid == null || uid.isEmpty) {
                      return const _GuestTabPlaceholder(
                        icon: Icons.person_outline_rounded,
                        title: 'Hồ sơ cá nhân',
                        subtitle:
                            'Đăng nhập để quản lý hồ sơ, video, đơn hàng và ví xu của bạn.',
                      );
                    }
                    return ProfileScreen(
                      key: ValueKey('profile_$uid'),
                      userId: uid,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _GuestTabPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _GuestTabPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () =>
                    context.requireAuth(() {}, runAfterLogin: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Đăng nhập ngay',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
