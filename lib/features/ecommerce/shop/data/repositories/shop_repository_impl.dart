import 'package:dartz/dartz.dart';

import '../../../../../core/errors/exception.dart';
import '../../../../../core/errors/failure.dart';
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
}
