import 'package:dartz/dartz.dart';

import '../../../../../core/errors/exception.dart';
import '../../../../../core/errors/failure.dart';
import '../../domain/entities/checkout_address.dart';
import '../../domain/entities/checkout_result.dart';
import '../../domain/repositories/checkout_repository.dart';
import '../datasources/checkout_remote_datasource.dart';

class CheckoutRepositoryImpl implements CheckoutRepository {
  final CheckoutRemoteDataSource remoteDataSource;

  const CheckoutRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, CheckoutResult>> placeOrder({
    required CheckoutAddress address,
    String? note,
    double discountAmount = 0.0,
  }) async {
    try {
      final result = await remoteDataSource.placeOrder(
        address: address,
        note: note,
        discountAmount: discountAmount,
      );
      return Right(result);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CheckoutResult>> placeDirectOrder({
    required CheckoutAddress address,
    required String productId,
    String? variantId,
    required int qty,
    String? note,
    double discountAmount = 0.0,
  }) async {
    try {
      final result = await remoteDataSource.placeDirectOrder(
        address: address,
        productId: productId,
        variantId: variantId,
        qty: qty,
        note: note,
        discountAmount: discountAmount,
      );
      return Right(result);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
