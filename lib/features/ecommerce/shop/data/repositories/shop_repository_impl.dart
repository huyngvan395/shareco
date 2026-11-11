import 'package:dartz/dartz.dart';

import '../../../../../core/errors/exception.dart';
import '../../../../../core/errors/failure.dart';
import '../../../order/domain/entities/ecommerce_order.dart';
import '../../../product/domain/entities/product.dart';
import '../../domain/entities/shop.dart';
import '../../domain/repositories/shop_repository.dart';
import '../datasources/shop_remote_datasource.dart';

class ShopRepositoryImpl implements ShopRepository {
  final ShopRemoteDataSource remoteDataSource;

  const ShopRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Shop>> getShopDetail(String shopId) async {
    try {
      final shop = await remoteDataSource.getShopDetail(shopId);
      return Right(shop.toEntity());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getShopProducts({
    required String shopId,
    int limit = 20,
    String? search,
  }) async {
    try {
      final products = await remoteDataSource.getShopProducts(
        shopId: shopId,
        limit: limit,
        search: search,
      );
      return Right(products.map((item) => item.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Shop>>> getMyShops() async {
    try {
      final shops = await remoteDataSource.getMyShops();
      return Right(shops.map((s) => s.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Shop>> registerShop({
    required String shopName,
    required String shopSlug,
    required String description,
    String? logoUrl,
    String? coverUrl,
    String? contactPhone,
    String? contactEmail,
    String businessType = 'individual',
    String? pickupProvince,
    String? pickupDistrict,
    String? pickupWard,
    String? pickupAddress,
    String defaultCarrier = 'SPX Express',
  }) async {
    try {
      final shop = await remoteDataSource.registerShop(
        shopName: shopName,
        shopSlug: shopSlug,
        description: description,
        logoUrl: logoUrl,
        coverUrl: coverUrl,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
        businessType: businessType,
        pickupProvince: pickupProvince,
        pickupDistrict: pickupDistrict,
        pickupWard: pickupWard,
        pickupAddress: pickupAddress,
        defaultCarrier: defaultCarrier,
      );
      return Right(shop.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Shop>> updateShopSettings({
    required String shopId,
    required String shopName,
    required String description,
    String? logoUrl,
    String? coverUrl,
    String? contactPhone,
    String? contactEmail,
    String? businessType,
    String? pickupProvince,
    String? pickupDistrict,
    String? pickupWard,
    String? pickupAddress,
    String? defaultCarrier,
    String? status,
  }) async {
    try {
      final shop = await remoteDataSource.updateShopSettings(
        shopId: shopId,
        shopName: shopName,
        description: description,
        logoUrl: logoUrl,
        coverUrl: coverUrl,
        contactPhone: contactPhone,
        contactEmail: contactEmail,
        businessType: businessType,
        pickupProvince: pickupProvince,
        pickupDistrict: pickupDistrict,
        pickupWard: pickupWard,
        pickupAddress: pickupAddress,
        defaultCarrier: defaultCarrier,
        status: status,
      );
      return Right(shop.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<EcommerceOrder>>> getShopOrders({
    required String shopId,
    String? status,
  }) async {
    try {
      final orders = await remoteDataSource.getShopOrders(
        shopId: shopId,
        status: status,
      );
      return Right(orders.map((o) => o.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> confirmAndPackOrder({
    required String orderId,
    String? note,
  }) async {
    try {
      await remoteDataSource.confirmAndPackOrder(orderId: orderId, note: note);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> handoverToCarrier({
    required String orderId,
    required String carrier,
    String? trackingCode,
    String? pickupHub,
  }) async {
    try {
      final code = await remoteDataSource.handoverToCarrier(
        orderId: orderId,
        carrier: carrier,
        trackingCode: trackingCode,
        pickupHub: pickupHub,
      );
      return Right(code);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> advanceOrderLocation({
    required String orderId,
    required String stepStatus,
    required String title,
    required String location,
    String? description,
  }) async {
    try {
      await remoteDataSource.advanceOrderLocation(
        orderId: orderId,
        stepStatus: stepStatus,
        title: title,
        location: location,
        description: description,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> sellerCancelOrder({
    required String orderId,
    required String reason,
  }) async {
    try {
      await remoteDataSource.sellerCancelOrder(
        orderId: orderId,
        reason: reason,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getSellerCatalog(String shopId) async {
    try {
      final products = await remoteDataSource.getSellerCatalog(shopId);
      return Right(products.map((p) => p.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getProductCategories() async {
    try {
      final list = await remoteDataSource.getProductCategories();
      return Right(list);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createProductCategory(
    String name,
  ) async {
    try {
      final res = await remoteDataSource.createProductCategory(name);
      return Right(res);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Product>> upsertSellerProduct({
    String? productId,
    required String shopId,
    required String categoryId,
    required String title,
    String? description,
    String? brand,
    required double price,
    double? originalPrice,
    required int stock,
    String status = 'active',
    String? coverPath,
    List<Map<String, dynamic>> variants = const [],
  }) async {
    try {
      final product = await remoteDataSource.upsertSellerProduct(
        productId: productId,
        shopId: shopId,
        categoryId: categoryId,
        title: title,
        description: description,
        brand: brand,
        price: price,
        originalPrice: originalPrice,
        stock: stock,
        status: status,
        coverPath: coverPath,
        variants: variants,
      );
      return Right(product.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleSellerProductStatus({
    required String productId,
    required String status,
  }) async {
    try {
      await remoteDataSource.toggleSellerProductStatus(
        productId: productId,
        status: status,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
