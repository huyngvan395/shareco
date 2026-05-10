// di/injector.dart

import 'package:get_it/get_it.dart';
import 'package:shareco/core/services/cloudinary/cloudinary_service.dart';
import 'package:shareco/core/services/media/audio_recorder_service.dart';
import 'package:shareco/core/services/media/image_picker_service.dart';
import 'package:shareco/core/services/supabase/presence_service.dart';
import 'package:shareco/features/chat/data/datasources/chat_remote_datasource.dart';
import 'package:shareco/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:shareco/features/chat/domain/repositories/chat_repository.dart';
import 'package:shareco/features/chat/domain/usecases/chat_usecases.dart';
import 'package:shareco/features/chat/domain/usecases/upload_media_usecase.dart';
import 'package:shareco/features/chat/presentation/bloc/conversation_bloc.dart';
import 'package:shareco/features/chat/presentation/bloc/message_bloc.dart';
import 'package:shareco/features/comment/data/datasources/comment_remote_datasource.dart';
import 'package:shareco/features/comment/data/repositories/comment_repository_impl.dart';
import 'package:shareco/features/comment/domain/repositories/comment_repository.dart';
import 'package:shareco/features/comment/presentation/bloc/comment_bloc.dart';
import 'package:shareco/features/notification/data/datasources/notification_remote_datasource.dart';
import 'package:shareco/features/notification/data/repositories/notification_repository_impl.dart';
import 'package:shareco/features/notification/domain/repositories/notification_repository.dart';
import 'package:shareco/features/video/presentation/bloc/camera_bloc.dart';
import 'package:shareco/features/video/presentation/bloc/create_video_bloc.dart';

import '../core/notifier/auth_notifier.dart';
import '../core/theme/theme_provider.dart';
import '../features/auth/data/datasources/auth_remote_datasources.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/login_usecase.dart';
import '../features/auth/domain/usecases/register_usecase.dart';
import '../features/ecommerce/address/data/datasources/address_remote_datasource.dart';
import '../features/ecommerce/address/data/repositories/address_repository_impl.dart';
import '../features/ecommerce/address/domain/repositories/address_repository.dart';
import '../features/ecommerce/address/domain/usecases/delete_address_usecase.dart';
import '../features/ecommerce/address/domain/usecases/get_addresses_usecase.dart';
import '../features/ecommerce/address/domain/usecases/save_address_usecase.dart';
import '../features/ecommerce/address/domain/usecases/set_default_address_usecase.dart';
import '../features/ecommerce/address/presentation/bloc/address_bloc.dart';
import '../features/ecommerce/cart/data/datasources/cart_remote_datasource.dart';
import '../features/ecommerce/cart/data/repositories/cart_repository_impl.dart';
import '../features/ecommerce/cart/domain/repositories/cart_repository.dart';
import '../features/ecommerce/cart/domain/usecases/add_to_cart_usecase.dart';
import '../features/ecommerce/cart/domain/usecases/get_cart_usecase.dart';
import '../features/ecommerce/cart/domain/usecases/remove_cart_item_usecase.dart';
import '../features/ecommerce/cart/domain/usecases/update_cart_item_qty_usecase.dart';
import '../features/ecommerce/cart/presentation/bloc/cart_bloc.dart';
import '../features/ecommerce/checkout/data/datasources/checkout_remote_datasource.dart';
import '../features/ecommerce/checkout/data/repositories/checkout_repository_impl.dart';
import '../features/ecommerce/checkout/domain/repositories/checkout_repository.dart';
import '../features/ecommerce/checkout/domain/usecases/place_order_usecase.dart';
import '../features/ecommerce/checkout/domain/usecases/place_direct_order_usecase.dart';
import '../features/ecommerce/checkout/presentation/bloc/checkout_bloc.dart';
import '../features/ecommerce/order/data/datasources/order_remote_datasource.dart';
import '../features/ecommerce/order/data/repositories/order_repository_impl.dart';
import '../features/ecommerce/order/domain/repositories/order_repository.dart';
import '../features/ecommerce/order/domain/usecases/cancel_order_usecase.dart';
import '../features/ecommerce/order/domain/usecases/get_order_detail_usecase.dart';
import '../features/ecommerce/order/domain/usecases/get_orders_usecase.dart';
import '../features/ecommerce/order/presentation/bloc/order_detail/order_detail_bloc.dart';
import '../features/ecommerce/order/presentation/bloc/order_list/order_list_bloc.dart';
import '../features/ecommerce/product/data/datasources/product_remote_datasource.dart';
import '../features/ecommerce/product/data/repositories/product_repository_impl.dart';
import '../features/ecommerce/product/domain/repositories/product_repository.dart';
import '../features/ecommerce/product/domain/usecases/get_product_detail_usecase.dart';
import '../features/ecommerce/product/domain/usecases/get_products_usecase.dart';
import '../features/ecommerce/product/domain/usecases/get_flash_sale_products_usecase.dart';
import '../features/ecommerce/product/presentation/bloc/product_detail/product_detail_bloc.dart';
import '../features/ecommerce/product/presentation/bloc/product_list/product_list_bloc.dart';
import '../features/ecommerce/review/data/datasources/review_remote_datasource.dart';
import '../features/ecommerce/review/data/repositories/review_repository_impl.dart';
import '../features/ecommerce/review/domain/repositories/review_repository.dart';
import '../features/ecommerce/review/domain/usecases/get_product_reviews_usecase.dart';
import '../features/ecommerce/review/domain/usecases/submit_review_usecase.dart';
import '../features/ecommerce/review/presentation/bloc/review_bloc.dart';
import '../features/ecommerce/shop/data/datasources/shop_remote_datasource.dart';
import '../features/ecommerce/shop/data/repositories/shop_repository_impl.dart';
import '../features/ecommerce/shop/domain/repositories/shop_repository.dart';
import '../features/ecommerce/shop/domain/usecases/get_shop_detail_usecase.dart';
import '../features/ecommerce/shop/domain/usecases/get_shop_products_usecase.dart';
import '../features/ecommerce/shop/presentation/bloc/shop_profile_bloc.dart';
import '../features/feed/presentation/bloc/feed_bloc.dart';
import '../features/profile/data/datasources/profile_remote_datasource.dart';
import '../features/profile/data/repositories/profile_repository_impl.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/video/data/datasources/video_remote_datasource.dart';
import '../features/video/data/repositories/video_repository_impl.dart';
import '../features/video/domain/repositories/video_repository.dart';
import '../features/video/domain/usecases/video_usecases.dart';

final sl = GetIt.instance;

Future<void> setupInjector() async {
  sl.registerLazySingleton(() => ThemeProvider());
  sl.registerLazySingleton(() => AuthNotifier());
  sl.registerLazySingleton(() => CloudinaryService());
  sl.registerLazySingleton(() => PresenceService());
  sl.registerLazySingleton(() => AudioRecorderService());
  sl.registerLazySingleton(() => ImagePickerService());

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));

  // Ecommerce: Product
  sl.registerLazySingleton<ProductRemoteDataSource>(
    () => ProductRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetProductsUseCase(sl()));
  sl.registerLazySingleton(() => GetProductDetailUseCase(sl()));
  sl.registerLazySingleton(() => GetFlashSaleProductsUseCase(repository: sl()));
  sl.registerFactory(() => ProductListBloc(getProductsUseCase: sl()));
  sl.registerFactory(() => ProductDetailBloc(getProductDetailUseCase: sl()));

  // Ecommerce: Address
  sl.registerLazySingleton<AddressRemoteDataSource>(
    () => AddressRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<AddressRepository>(
    () => AddressRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetAddressesUseCase(sl()));
  sl.registerLazySingleton(() => SaveAddressUseCase(sl()));
  sl.registerLazySingleton(() => DeleteAddressUseCase(sl()));
  sl.registerLazySingleton(() => SetDefaultAddressUseCase(sl()));
  sl.registerFactory(
    () => AddressBloc(
      getAddressesUseCase: sl(),
      saveAddressUseCase: sl(),
      deleteAddressUseCase: sl(),
      setDefaultAddressUseCase: sl(),
    ),
  );

  // Ecommerce: Cart
  sl.registerLazySingleton<CartRemoteDataSource>(
    () => CartRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<CartRepository>(
    () => CartRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetCartUseCase(sl()));
  sl.registerLazySingleton(() => AddToCartUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCartItemQtyUseCase(sl()));
  sl.registerLazySingleton(() => RemoveCartItemUseCase(sl()));
  sl.registerFactory(
    () => CartBloc(
      getCartUseCase: sl(),
      updateCartItemQtyUseCase: sl(),
      removeCartItemUseCase: sl(),
    ),
  );

  // Ecommerce: Checkout
  sl.registerLazySingleton<CheckoutRemoteDataSource>(
    () => CheckoutRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<CheckoutRepository>(
    () => CheckoutRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => PlaceOrderUseCase(sl()));
  sl.registerLazySingleton(() => PlaceDirectOrderUseCase(sl()));
  sl.registerFactory(
    () => CheckoutBloc(placeOrderUseCase: sl(), placeDirectOrderUseCase: sl()),
  );

  // Ecommerce: Orders
  sl.registerLazySingleton<OrderRemoteDataSource>(
    () => OrderRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetOrdersUseCase(sl()));
  sl.registerLazySingleton(() => GetOrderDetailUseCase(sl()));
  sl.registerLazySingleton(() => CancelOrderUseCase(sl()));
  sl.registerFactory(() => OrderListBloc(getOrdersUseCase: sl()));
  sl.registerFactory(
    () =>
        OrderDetailBloc(getOrderDetailUseCase: sl(), cancelOrderUseCase: sl()),
  );

  // Ecommerce: Shop
  sl.registerLazySingleton<ShopRemoteDataSource>(
    () => ShopRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<ShopRepository>(
    () => ShopRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetShopDetailUseCase(sl()));
  sl.registerLazySingleton(() => GetShopProductsUseCase(sl()));
  sl.registerFactory(
    () => ShopProfileBloc(
      getShopDetailUseCase: sl(),
      getShopProductsUseCase: sl(),
    ),
  );

  // Ecommerce: Review
  sl.registerLazySingleton<ReviewRemoteDataSource>(
    () => ReviewRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<ReviewRepository>(
    () => ReviewRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => SubmitReviewUseCase(sl()));
  sl.registerLazySingleton(() => GetProductReviewsUseCase(repository: sl()));
  sl.registerFactory(() => ReviewBloc(submitReviewUseCase: sl()));
  sl.registerLazySingleton<VideoRemoteDataSource>(
    () => VideoRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<VideoRepository>(
    () => VideoRepositoryImpl(remote: sl()),
  );
  sl.registerLazySingleton(() => GetForYouFeedUseCase(sl()));
  sl.registerLazySingleton(() => GetFollowingFeedUseCase(sl()));
  sl.registerLazySingleton(() => GetUserVideosUseCase(sl()));
  sl.registerLazySingleton(() => GetVideoByIdUseCase(sl()));
  sl.registerLazySingleton(() => ToggleVideoLikeUseCase(sl()));
  sl.registerLazySingleton(() => IncrementVideoViewUseCase(sl()));
  sl.registerLazySingleton(() => CreateVideoUseCase(sl()));
  sl.registerLazySingleton(() => DeleteVideoUseCase(sl()));

  sl.registerFactory(
    () => FeedBloc(
      getForYouFeed: sl(),
      getFollowingFeed: sl(),
      toggleVideoLike: sl(),
      incrementView: sl(),
    ),
  );

  // CameraBloc: factory so each CameraScreen gets a fresh instance
  sl.registerFactory(() => CameraBloc());
  // CreateVideoBloc: factory per edit session
  sl.registerFactory(() => CreateVideoBloc(createVideo: sl()));

  // Comment
  sl.registerLazySingleton<CommentRemoteDataSource>(
    () => CommentRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<CommentRepository>(
    () => CommentRepositoryImpl(remote: sl()),
  );
  sl.registerFactory(() => CommentBloc(repo: sl()));

  // Profile
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(remote: sl()),
  );

  // Notification
  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(remote: sl()),
  );

  // Chat
  sl.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSourceImpl(presenceService: sl()),
  );
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(remote: sl(),cloudinaryService: sl(),),
  );
  sl.registerLazySingleton(() => GetConversationsUseCase(sl()));
  sl.registerLazySingleton(() => GetOrCreateConversationUseCase(sl()));
  sl.registerLazySingleton(() => GetMessagesUseCase(sl()));
  sl.registerLazySingleton(() => SendMessageUseCase(sl()));
  sl.registerLazySingleton(() => DeleteMessageUseCase(sl()));
  sl.registerLazySingleton(() => MarkAsReadUseCase(sl()));
  sl.registerLazySingleton(() => WatchMessagesUseCase(sl()));
  sl.registerLazySingleton(() => SearchUsersUseCase(sl()));
  sl.registerLazySingleton(() => WatchUserPresenceUseCase(sl()));
  sl.registerLazySingleton(() => UploadMediaUseCase(sl()));

  sl.registerFactory(
    () => ConversationBloc(
      getConversations: sl(),
      getOrCreateConversation: sl(),
      searchUsers: sl(),
    ),
  );
  sl.registerFactory(
    () => MessageBloc(
      getMessages: sl(),
      sendMessage: sl(),
      deleteMessage: sl(),
      markAsRead: sl(),
      watchMessages: sl(),
      watchUserPresence: sl(),
      uploadMedia: sl(),
    ),
  );
}
