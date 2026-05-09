import 'package:dartz/dartz.dart';

import '../../../../../core/errors/exception.dart';
import '../../../../../core/errors/failure.dart';
import '../../domain/entities/cart.dart';
import '../../domain/repositories/cart_repository.dart';
import '../datasources/cart_remote_datasource.dart';

class CartRepositoryImpl implements CartRepository {
  final CartRemoteDataSource remoteDataSource;

  const CartRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Cart>> getCart() async {
    try {
      final cart = await remoteDataSource.getCart();
      return Right(cart.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Cart>> addToCart({
    required String productId,
    String? variantId,
    int qty = 1,
  }) async {
    try {
      final cart = await remoteDataSource.addToCart(
        productId: productId,
        variantId: variantId,
        qty: qty,
      );
      return Right(cart.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Cart>> updateCartItemQty({
    required String itemId,
    required int qty,
  }) async {
    try {
      final cart = await remoteDataSource.updateCartItemQty(
        itemId: itemId,
        qty: qty,
      );
      return Right(cart.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Cart>> removeCartItem(String itemId) async {
    try {
      final cart = await remoteDataSource.removeCartItem(itemId);
      return Right(cart.toEntity());
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
