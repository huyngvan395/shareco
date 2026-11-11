import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failure.dart';
import '../../../order/domain/entities/ecommerce_order.dart';
import '../../../product/domain/entities/product.dart';
import '../entities/shop.dart';

abstract class ShopRepository {
  Future<Either<Failure, Shop>> getShopDetail(String shopId);

  Future<Either<Failure, List<Product>>> getShopProducts({
    required String shopId,
    int limit = 20,
    String? search,
  });

  Future<Either<Failure, List<Shop>>> getMyShops();

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
  });

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
  });

  Future<Either<Failure, List<EcommerceOrder>>> getShopOrders({
    required String shopId,
    String? status,
  });

  Future<Either<Failure, void>> confirmAndPackOrder({
    required String orderId,
    String? note,
  });

  Future<Either<Failure, String>> handoverToCarrier({
    required String orderId,
    required String carrier,
    String? trackingCode,
    String? pickupHub,
  });

  Future<Either<Failure, void>> advanceOrderLocation({
    required String orderId,
    required String stepStatus,
    required String title,
    required String location,
    String? description,
  });

  Future<Either<Failure, void>> sellerCancelOrder({
    required String orderId,
    required String reason,
  });

  Future<Either<Failure, List<Product>>> getSellerCatalog(String shopId);

  Future<Either<Failure, List<Map<String, dynamic>>>> getProductCategories();

  Future<Either<Failure, Map<String, dynamic>>> createProductCategory(
    String name,
  );

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
  });

  Future<Either<Failure, void>> toggleSellerProductStatus({
    required String productId,
    required String status,
  });
}
